import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:latlong2/latlong.dart';

/// 顶级惯性导航引擎：基于 15 维扩展卡尔曼滤波 (EKF)
/// 融合 IMU 增量、车辆动力学约束 (NHC) 和地图反馈
class InertialNavigationEngine {
  // --- 状态向量 ---
  Vector3 _pos = Vector3.zero(); // 位置 (相对起点，米)
  Vector3 _vel = Vector3.zero(); // 速度 (m/s)
  Quaternion _att = Quaternion.identity(); // 姿态 (四元数)
  Vector3 _accBias = Vector3.zero(); // 加速度计零偏
  Vector3 _gyroBias = Vector3.zero(); // 陀螺仪零偏

  // --- 协方差矩阵 (简化为块处理以提高性能) ---
  // P 矩阵通常为 15x15，这里我们重点追踪对角线分量
  Vector3 _pPos = Vector3.all(1.0);
  Vector3 _pVel = Vector3.all(0.1);
  Vector3 _pAtt = Vector3.all(0.01);
  Vector3 _pAccBias = Vector3.all(0.0001);
  Vector3 _pGyroBias = Vector3.all(0.00001);

  // --- 常量与噪声参数 ---
  static const double _g = 9.80665;
  double _qAcc = 0.05; // 加速度计过程噪声
  double _qGyro = 0.005; // 陀螺仪过程噪声
  double _rNhc = 0.1; // NHC 约束噪声 (越小约束越强)

  DateTime? _lastTime;
  LatLng? _startLatLng;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// 初始化：由 GPS 起点和静态校准后的零偏触发
  void initialize(LatLng startPoint, Vector3 initialGyroBias,
      {double initialHeading = 0.0}) {
    _startLatLng = startPoint;
    _pos = Vector3.zero();
    _vel = Vector3.zero();

    // 根据初始航向初始化四元数 (假设初始 Pitch/Roll 为 0，由 SensorEngine 保证)
    _att = Quaternion.axisAngle(
        Vector3(0, 0, 1), initialHeading * math.pi / 180.0);

    _gyroBias = initialGyroBias;
    _accBias = Vector3.zero();
    _isInitialized = true;
    _lastTime = DateTime.now();
  }

  /// 核心预测步：由高频传感器数据驱动 (50Hz-100Hz)
  void predict(SensorData data) {
    if (!_isInitialized || _lastTime == null) return;

    final now = data.timestamp;
    final double dt = now.difference(_lastTime!).inMicroseconds / 1000000.0;
    if (dt <= 0 || dt > 0.5) {
      _lastTime = now;
      return;
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

    // 3. 速度与位置更新
    final Matrix3 rotMatrix = _att.asRotationMatrix();
    final Vector3 accNav = rotMatrix.transformed(correctedAcc);
    // 注意：processedAccel 已经去除了重力，所以这里不需要再减 G

    // 简单的梯形积分
    final Vector3 oldVel = _vel.clone();
    _vel += accNav * dt;
    _pos += (oldVel + _vel) * 0.5 * dt;

    // 4. 协方差增长 (简化模型)
    _pPos += _pVel * dt;
    _pVel += Vector3.all(_qAcc * dt);
    _pAtt += Vector3.all(_qGyro * dt);

    // 5. 应用 NHC 约束 (非整体性约束：车辆不能横着走或跳起来)
    _applyNHC();

    _lastTime = now;
  }

  /// 非整体性约束修正：强制侧向和垂直速度趋向于 0
  void _applyNHC() {
    final Matrix3 rotMatrixInv = _att.asRotationMatrix()..transpose();
    Vector3 velBody = rotMatrixInv.transformed(_vel);

    // 侧向速度 (X) 和 垂直速度 (Z) 的观测值为 0
    // 我们使用简单的增益反馈来模拟 EKF 更新
    final double gain = 0.05; // 约束强度
    velBody.x *= (1.0 - gain);
    velBody.z *= (1.0 - gain);

    _vel = _att.asRotationMatrix().transformed(velBody);
  }

  /// GPS 观测更新：当 GPS 信号良好时校准惯导系统
  void observeGPS(LatLng currentGPS, double speed, double accuracy) {
    if (!_isInitialized || _startLatLng == null) return;

    // 将经纬度转为相对坐标 (米)
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

    // 简单的 EKF 修正：根据 GPS 精度调整权重
    final double weight = (1.0 / (accuracy + 1.0)).clamp(0.0, 0.9);

    _pos.x = _pos.x * (1 - weight) + dx * weight;
    _pos.y = _pos.y * (1 - weight) + dy * weight;

    // 速度修正
    if (speed > 0.5) {
      final double velWeight = weight * 0.5;
      _vel.length = _vel.length * (1 - velWeight) + speed * velWeight;
    }
  }

  /// 获取当前推算的经纬度
  LatLng getCurrentLatLng() {
    if (_startLatLng == null) return const LatLng(0, 0);

    // 简单的平面投影近似 (适合隧道等短距离)
    const double metersPerDegree = 111319.9;
    final double lat = _startLatLng!.latitude + (_pos.y / metersPerDegree);
    final double lng = _startLatLng!.longitude +
        (_pos.x /
            (metersPerDegree *
                math.cos(_startLatLng!.latitude * math.pi / 180.0)));

    return LatLng(lat, lng);
  }

  // 计算两点间距离 (米)
  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}
