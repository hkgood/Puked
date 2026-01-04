import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/foundation.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

class SensorEngine {
  // 采样周期：iOS 强制 60Hz (约16ms)，Android 维持 30Hz (33ms)
  static final Duration samplingPeriod = Platform.isIOS
      ? const Duration(milliseconds: 16)
      : const Duration(milliseconds: 33);

  // 15秒缓冲区长度 (15s * 60Hz = 900 points for iOS)
  static final int bufferLimit = Platform.isIOS ? 900 : 450;

  final ListQueue<SensorData> _buffer = ListQueue<SensorData>(bufferLimit);

  // 校准矩阵 (Identity matrix by default)
  Matrix3 _rotationMatrix = Matrix3.identity();
  bool _isCalibrated = false;
  double _gravityMagnitude = 9.80665; // 标准重力加速度

  // 滤波器系数
  static const double _lpfCoeff = 0.1;
  static const double _rampFilterCoeff = 0.02;
  Vector3 _filteredAccel = Vector3.zero();
  Vector3 _gravityEstimate = Vector3.zero();

  // --- 顶级滤波矩阵成员 ---
  final ListQueue<Vector3> _medianBuffer = ListQueue<Vector3>();
  static const int _medianWindowSize = 3;

  // 卡尔曼滤波器状态 (简单版用于重力追踪)
  Vector3 _kalmanGravity = Vector3.zero();
  Vector3 _kalmanP = Vector3.all(0.1); // 误差协方差
  static const double _kalmanQ = 0.001; // 过程噪声
  static const double _kalmanR = 0.1; // 测量噪声

  // 动态航向修正相关
  double _dynamicYawOffset = 0.0;
  final ListQueue<Vector3> _headingLearningBuffer = ListQueue<Vector3>();
  bool _isHeadingAligned = false;

  // 临时存储最新的传感器原始值
  final Vector3 _latestAccel = Vector3.zero();
  final Vector3 _latestGyro = Vector3.zero();
  final Vector3 _latestMag = Vector3.zero();
  DateTime _lastSensorEventTime = DateTime.now();
  int _sensorEventCount = 0;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;
  Timer? _samplingTimer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  DateTime get lastSensorEventTime => _lastSensorEventTime;
  int get sensorEventCount => _sensorEventCount;

  // 广播流，供 UI 订阅
  final _dataController = StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _dataController.stream;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 根据平台选择采样间隔
    final sensorInterval = Platform.isIOS
        ? SensorInterval.uiInterval
        : SensorInterval.gameInterval;

    // 监听原始传感器流
    _accelSub =
        accelerometerEventStream(samplingPeriod: sensorInterval).listen((e) {
      _latestAccel.setValues(e.x, e.y, e.z);
      _lastSensorEventTime = DateTime.now();
      _sensorEventCount++;
      // iOS 采用“同步驱动”：传感器一更新，立刻触发 tick，消除真空期
      if (Platform.isIOS) _processTick();
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestGyro.setValues(e.x, e.y, e.z));
    _magSub = magnetometerEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestMag.setValues(e.x, e.y, e.z));

    // Android 依然使用定时器，因为 Android 定位服务需要稳定的心跳
    if (!Platform.isIOS) {
      _samplingTimer = Timer.periodic(samplingPeriod, (timer) {
        _processTick();
      });
    }
  }

  void _processTick() {
    final now = DateTime.now();

    // Stage 1: 中值滤波 (Median Filter) - 消除硬件毛刺
    _medianBuffer.addLast(_latestAccel.clone());
    if (_medianBuffer.length > _medianWindowSize) _medianBuffer.removeFirst();

    final Vector3 smoothedAccel = _calculateMedian(_medianBuffer.toList());

    // Stage 2: 卡尔曼滤波 (Kalman Filter) - 动态追踪重力姿态
    if (!_isCalibrated) {
      _kalmanGravity = smoothedAccel.clone();
      _isCalibrated = true; // 初始状态下直接采信
    } else {
      // 简单卡尔曼更新：预测
      // Gravity doesn't change much, so prediction is same as last state
      // 修正：计算卡尔曼增益
      for (int i = 0; i < 3; i++) {
        _kalmanP[i] = _kalmanP[i] + _kalmanQ;
        double kGain = _kalmanP[i] / (_kalmanP[i] + _kalmanR);
        _kalmanGravity[i] =
            _kalmanGravity[i] + kGain * (smoothedAccel[i] - _kalmanGravity[i]);
        _kalmanP[i] = (1 - kGain) * _kalmanP[i];
      }
    }

    // Stage 3: 应用旋转矩阵 (包含动态航向修正)
    // 基础旋转（由静态校准确定）
    Vector3 rotatedAccel = _rotationMatrix.transformed(smoothedAccel);
    Vector3 rotatedGyro = _rotationMatrix.transformed(_latestGyro);

    // 应用动态航向修正 (Yaw)
    if (_dynamicYawOffset != 0) {
      final yawMatrix = Matrix3.rotationZ(_dynamicYawOffset);
      rotatedAccel = yawMatrix.transformed(rotatedAccel);
      rotatedGyro = yawMatrix.transformed(rotatedGyro);
    }

    // Stage 4: 扣除动态重力
    final Vector3 currentGravityInRef =
        _rotationMatrix.transformed(_kalmanGravity);
    final processedAccel = rotatedAccel - currentGravityInRef;

    // 低通滤波用于平滑显示
    _filteredAccel =
        _filteredAccel * (1.0 - _lpfCoeff) + processedAccel * _lpfCoeff;

    final data = SensorData(
      timestamp: now,
      accelerometer: _latestAccel.clone(),
      gyroscope: _latestGyro.clone(),
      magnetometer: _latestMag.clone(),
      processedAccel: processedAccel,
      processedGyro: rotatedGyro,
      filteredAccel: _filteredAccel,
    );

    // 动态航向学习逻辑：在启动的前 30 秒，如果检测到明显的纵向加速，自动对齐
    if (!_isHeadingAligned && _buffer.length > 30) {
      _learnHeading(processedAccel);
    }

    // 更新缓冲区
    if (_buffer.length >= bufferLimit) {
      _buffer.removeFirst();
    }
    _buffer.addLast(data);

    // 推送到 UI 层
    _dataController.add(data);
  }

  Vector3 _calculateMedian(List<Vector3> samples) {
    if (samples.isEmpty) return Vector3.zero();
    if (samples.length == 1) return samples[0];

    final xValues = samples.map((s) => s.x).toList()..sort();
    final yValues = samples.map((s) => s.y).toList()..sort();
    final zValues = samples.map((s) => s.z).toList()..sort();

    final mid = samples.length ~/ 2;
    return Vector3(xValues[mid], yValues[mid], zValues[mid]);
  }

  void _learnHeading(Vector3 accel) {
    // 逻辑：寻找车辆起步瞬间的加速度矢量方向
    // 如果纵向加速度较大（> 1.0 m/s²），记录其在水平面 (X-Y) 的偏移角
    final double horizontalMag = Math.sqrt(accel.x * accel.x + accel.y * accel.y);
    if (horizontalMag > 1.5 && accel.y > 0) {
      _headingLearningBuffer.addLast(accel.clone());
      if (_headingLearningBuffer.length > 20) {
        // 计算平均偏角
        double avgAngle = 0;
        for (var a in _headingLearningBuffer) {
          avgAngle += Math.atan2(a.x, a.y);
        }
        avgAngle /= _headingLearningBuffer.length;

        // 如果偏角超过 3 度，触发修正
        if (avgAngle.abs() > 0.05) {
          _dynamicYawOffset -= avgAngle; // 减去偏角以归零
          debugPrint("Heading Aligned: Adjusted by ${(avgAngle * 180 / Math.pi).toStringAsFixed(1)}°");
        }
        _isHeadingAligned = true;
        _headingLearningBuffer.clear();
      }
    }
  }

  /// 顶级校准逻辑：增加方差校验，确保校准时手机是静止的
  Future<void> calibrate() async {
    List<Vector3> samples = [];
    const int sampleCount = 20;

    for (int i = 0; i < sampleCount; i++) {
      samples.add(_latestAccel.clone());
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 计算均值
    Vector3 gMean = Vector3.zero();
    for (var s in samples) {
      gMean += s;
    }
    gMean /= samples.length.toDouble();

    // 顶级校验：计算方差 (Variance)
    double variance = 0;
    for (var s in samples) {
      variance += (s - gMean).length2;
    }
    variance /= samples.length;

    // 如果方差 > 0.05 (约 0.22m/s² 的波动)，说明手机在动，拒绝校准
    if (variance > 0.05) {
      throw Exception("校准失败：请确保手机完全静止（检测到波动: ${variance.toStringAsFixed(3)}）");
    }

    _gravityMagnitude = gMean.length;
    // 强制校验：如果重力模长不在合理范围内 (8.0 ~ 12.0)，说明传感器还在假死或读数异常
    if (_gravityMagnitude < 8.0 || _gravityMagnitude > 12.0) {
      throw Exception("校准失败：传感器读数异常 (G: ${_gravityMagnitude.toStringAsFixed(2)})，请检查权限或重启 App");
    }

    final unitZ = gMean.normalized();
    Vector3 reference = Vector3(0, 1, 0);
    if (unitZ.dot(reference).abs() > 0.9) {
      reference = Vector3(1, 0, 0);
    }

    final unitX = reference.cross(unitZ).normalized();
    final unitY = unitZ.cross(unitX).normalized();

    final rot = Matrix3.columns(unitX, unitY, unitZ);
    _rotationMatrix = rot.isIdentity() ? rot : Matrix3.copy(rot)
      ..invert();
    _gravityEstimate = _rotationMatrix.transformed(gMean);
    _isCalibrated = true;
    _isHeadingAligned = false; // 重置航向对齐标志
    _dynamicYawOffset = 0.0; // 重置航向偏角

    _processTick();
  }

  /// 获取回溯数据片段 (过去 N 秒)，并进行下采样 (Downsampling to ~20Hz)
  List<SensorData> getLookbackBuffer(int seconds, {int targetHz = 20}) {
    // 计算原始采样率 (iOS 60Hz, Android 30Hz)
    final sourceHz = Platform.isIOS ? 60 : 30;
    final step = (sourceHz / targetHz).round().clamp(1, 10);

    int pointsToTake = (seconds * sourceHz).clamp(0, _buffer.length);
    final rawList = _buffer.toList().sublist(_buffer.length - pointsToTake);

    // 执行跳格采样
    List<SensorData> downsampled = [];
    for (int i = 0; i < rawList.length; i += step) {
      downsampled.add(rawList[i]);
    }
    return downsampled;
  }

  void dispose() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _magSub?.cancel();
    _samplingTimer?.cancel();
    _dataController.close();
  }
}
