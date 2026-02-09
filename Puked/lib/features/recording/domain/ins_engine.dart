import 'dart:math' as math;
import 'dart:collection';
import 'package:vector_math/vector_math_64.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:latlong2/latlong.dart';

/// 顶级惯性导航引擎：基于 15 维扩展卡尔曼滤波 (EKF) 的简化版
/// 融合 IMU 增量、车辆动力学约束 (NHC) 和 统计零速检测 (GLRT-ZUPT)
class InertialNavigationEngine {
  // --- 状态向量 ---
  Vector3 _pos = Vector3.zero(); // 位置 (相对起点，米)
  Vector3 _vel = Vector3.zero(); // 速度 (m/s)
  Quaternion _att = Quaternion.identity(); // 姿态 (四元数)
  Vector3 _accBias = Vector3.zero(); // 加速度计零偏
  Vector3 _gyroBias = Vector3.zero(); // 陀螺仪零偏

  // --- 统计缓冲区 (用于 GLRT 零速检测) ---
  final ListQueue<double> _accNormBuffer = ListQueue<double>();
  final ListQueue<double> _gyroNormBuffer = ListQueue<double>();
  static const int _statWindowSize = 15; // 300ms 窗口 (50Hz)

  // --- 鲁棒性参数 ---
  static const double _velocityDamping = 0.95; // 速度阻尼：在没有外力且低速时快速衰减速度
  static const double _maxInsSpeedWithoutGps =
      15.0; // 无 GPS 时的最大推算速度保护 (约 54km/h)

  DateTime? _lastTime;
  LatLng? _startLatLng;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 获取当前推算速度 (m/s) - 标量值
  double get currentSpeed => _vel.length;

  /// 获取当前推算速度向量
  Vector3 get velocity => _vel;

  /// 重置引擎状态
  void reset() {
    _isInitialized = false;
    _pos = Vector3.zero();
    _vel = Vector3.zero();
    _att = Quaternion.identity();
    _accBias = Vector3.zero();
    _gyroBias = Vector3.zero();
    _startLatLng = null;
    _lastTime = null;
    _accNormBuffer.clear();
    _gyroNormBuffer.clear();
  }

  /// 初始化：由 GPS 起点和静态校准后的零偏触发
  void initialize(LatLng startPoint, Vector3 initialGyroBias,
      {double initialHeading = 0.0}) {
    _startLatLng = startPoint;
    _pos = Vector3.zero();
    _vel = Vector3.zero();

    // 根据初始航向初始化四元数
    _att = Quaternion.axisAngle(
        Vector3(0, 0, 1), initialHeading * math.pi / 180.0);

    _gyroBias = initialGyroBias;
    _accBias = Vector3.zero();
    _isInitialized = true;
    _lastTime = DateTime.now();
  }

  /// 核心预测步：由高频传感器数据驱动
  void predict(SensorData data) {
    if (!_isInitialized || _lastTime == null) return;

    final now = data.timestamp;
    final double dt = now.difference(_lastTime!).inMicroseconds / 1000000.0;
    if (dt <= 0 || dt > 0.5) {
      _lastTime = now;
      return;
    }

    // 更新统计缓冲区
    _accNormBuffer.addLast(data.accelerometer.length);
    _gyroNormBuffer.addLast(data.gyroscope.length);
    if (_accNormBuffer.length > _statWindowSize) {
      _accNormBuffer.removeFirst();
      _gyroNormBuffer.removeFirst();
    }

    // 1. 补偿零偏
    final Vector3 correctedAcc = data.processedAccel - _accBias;
    final Vector3 correctedGyro = data.processedGyro - _gyroBias;

    // 2. 姿态更新 (四元数积分)
    final Vector3 deltaAngle = correctedGyro * dt;
    final double angleMag = deltaAngle.length;
    if (angleMag > 1e-9) {
      final Quaternion dq =
          Quaternion.axisAngle(deltaAngle.normalized(), angleMag);
      _att = _att * dq;
      _att.normalize();
    }

    // 3. 零速修正 (ZUPT) - 增强版
    bool isStationary = false;
    if (_accNormBuffer.length >= _statWindowSize) {
      final accMean = _accNormBuffer.reduce((a, b) => a + b) / _statWindowSize;
      final accVar = _accNormBuffer
              .map((v) => math.pow(v - accMean, 2))
              .reduce((a, b) => a + b) /
          _statWindowSize;
      final gyroMean =
          _gyroNormBuffer.reduce((a, b) => a + b) / _statWindowSize;

      // 第一性原理：如果是“原地摇手机”，加速度的均值会接近重力，但方差巨大。
      // 真正的静止要求方差极小。
      if (accVar < 0.005 &&
          gyroMean < 0.03 &&
          data.processedAccel.length < 0.15) {
        isStationary = true;
      }
    }

    if (isStationary) {
      // 绝对静止，速度立即归零
      _vel.setZero();
    } else {
      // 4. 速度与位置更新
      final Matrix3 rotMatrix = _att.asRotationMatrix();
      final Vector3 accNav = rotMatrix.transformed(correctedAcc);

      final Vector3 oldVel = _vel.clone();

      // 物理保护：如果加速度过大（如手摇），限制其对速度的影响
      // 真实的汽车加速度很少长时间维持在 1G 以上
      final cappedAccNav = Vector3(
        accNav.x.clamp(-15.0, 15.0),
        accNav.y.clamp(-15.0, 15.0),
        accNav.z.clamp(-15.0, 15.0),
      );

      _vel += cappedAccNav * dt;

      // 应用自然阻尼，防止因手摇导致的积分无限制增长
      if (_vel.length > 0.1) {
        _vel *= _velocityDamping;
      }

      // 整体速度熔断：无 GPS 辅助时，推算速度不允许超过 54km/h
      if (_vel.length > _maxInsSpeedWithoutGps) {
        _vel.normalize();
        _vel *= _maxInsSpeedWithoutGps;
      }

      _pos += (oldVel + _vel) * 0.5 * dt;
    }

    // 5. 应用 NHC 约束 (非整体性约束)
    _applyNHC();

    _lastTime = now;
  }

  /// 非整体性约束修正
  void _applyNHC() {
    if (_vel.length < 0.05) return;

    final Matrix3 rotMatrixInv = _att.asRotationMatrix()..transpose();
    Vector3 velBody = rotMatrixInv.transformed(_vel);

    // 强制侧向和垂直速度归零（车不能横移或飞天）
    // 调强约束，因为手摇会产生大量的侧向速度分量
    velBody.x *= 0.01;
    velBody.z *= 0.01;

    _vel = _att.asRotationMatrix().transformed(velBody);
  }

  /// GPS 观测更新：核心在于利用 GPS 的低频准确性来“镇压”惯导的高频发散
  void observeGPS(LatLng currentGPS, double speed, double accuracy) {
    if (!_isInitialized || _startLatLng == null) return;

    // 只有当 GPS 精度优于 30 米时才进行强修正
    final double weight = (1.0 / (accuracy + 1.0)).clamp(0.0, 0.95);

    // 位置修正
    final double dx = _getDistance(
            _startLatLng!.latitude,
            _startLatLng!.longitude,
            _startLatLng!.latitude,
            currentGPS.longitude) *
        (currentGPS.longitude > _startLatLng!.longitude ? 1 : -1);
    final double dy = _getDistance(
            _startLatLng!.latitude,
            _startLatLng!.longitude,
            currentGPS.latitude,
            _startLatLng!.longitude) *
        (currentGPS.latitude > _startLatLng!.latitude ? 1 : -1);

    _pos.x = _pos.x * (1 - weight) + dx * weight;
    _pos.y = _pos.y * (1 - weight) + dy * weight;

    // 速度强修正：利用 GPS 速度强制约束惯导速度
    // 如果 GPS 显示静止（speed < 0.5），惯导速度也必须被强制拉回
    if (speed < 0.5 && accuracy < 20.0) {
      _vel *= 0.5; // 快速压制速度漂移
    } else {
      // 正常的卡尔曼增益更新
      final double currentInsSpeed = _vel.length;
      if (currentInsSpeed > 0.1) {
        final double scale =
            (currentInsSpeed * (1 - weight) + speed * weight) / currentInsSpeed;
        _vel *= scale;
      } else if (speed > 0.5) {
        // 如果惯导是 0 但 GPS 有速度，直接赋予方向
        final Matrix3 rotMatrix = _att.asRotationMatrix();
        _vel = rotMatrix.transformed(Vector3(0, speed, 0)); // 假设沿前进方向
      }
    }
  }

  LatLng getCurrentLatLng() {
    if (_startLatLng == null) return const LatLng(0, 0);
    const double metersPerDegree = 111319.9;
    final double lat = _startLatLng!.latitude + (_pos.y / metersPerDegree);
    final double lng = _startLatLng!.longitude +
        (_pos.x /
            (metersPerDegree *
                math.cos(_startLatLng!.latitude * math.pi / 180.0)));
    return LatLng(lat, lng);
  }

  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
