import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

class SensorEngine {
  // 采样周期：iOS 强制 60Hz (约16ms)，Android 维持 30Hz (33ms)
  static final Duration samplingPeriod = Platform.isIOS
      ? const Duration(milliseconds: 16)
      : const Duration(milliseconds: 33);

  // 15秒缓冲区长度 (15s * 60Hz = 900 points for iOS, 增加余量至 1000)
  static final int bufferLimit = Platform.isIOS ? 1000 : 450;

  final ListQueue<SensorData> _buffer = ListQueue<SensorData>(bufferLimit);

  // 校准矩阵 (Identity matrix by default)
  Matrix3 _rotationMatrix = Matrix3.identity();
  bool _isCalibrated = false;

  // 核心：原始坐标系下的静态重力向量 (用于消除 0.3G 偏移)
  Vector3 _staticGravityRaw = Vector3.zero();

  // 滤波器系数
  static const double _lpfCoeff = 0.1;
  Vector3 _filteredAccel = Vector3.zero();

  // --- 顶级滤波矩阵成员 ---
  final ListQueue<Vector3> _medianBuffer = ListQueue<Vector3>();
  static const int _medianWindowSize = 3;

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
      final now = DateTime.now();
      _latestAccel.setValues(e.x, e.y, e.z);
      _lastSensorEventTime = now;
      _sensorEventCount++;
      // iOS 采用“同步驱动”：传感器一更新，立刻触发 tick，消除真空期
      if (Platform.isIOS) _processTick(now);
    });

    _gyroSub = gyroscopeEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestGyro.setValues(e.x, e.y, e.z));
    _magSub = magnetometerEventStream(samplingPeriod: sensorInterval)
        .listen((e) => _latestMag.setValues(e.x, e.y, e.z));

    // Android 依然使用定时器，因为 Android 定位服务需要稳定的心跳
    if (!Platform.isIOS) {
      _samplingTimer = Timer.periodic(samplingPeriod, (timer) {
        _processTick(DateTime.now());
      });
    }
  }

  void _processTick(DateTime timestamp) {
    final now = timestamp;

    // Stage 1: 中值滤波 (Median Filter) - 消除硬件毛刺
    _medianBuffer.addLast(_latestAccel.clone());
    if (_medianBuffer.length > _medianWindowSize) _medianBuffer.removeFirst();
    final Vector3 smoothedAccel = _calculateMedian(_medianBuffer.toList());

    // Stage 2: 扣除静态重力 (原始坐标系)
    // 第一性原理：先减去重力向量，再进行坐标旋转。这能彻底消除因旋转矩阵不准导致的重力泄露 (0.3G 偏移)
    final Vector3 pureMotionRaw =
        _isCalibrated ? smoothedAccel - _staticGravityRaw : Vector3.zero();

    // Stage 3: 姿态应用 (将纯净的运动向量转到车辆坐标系)
    Vector3 processedAccel = _rotationMatrix.transformed(pureMotionRaw);
    Vector3 rotatedGyro = _rotationMatrix.transformed(_latestGyro);

    // 应用动态航向修正 (Yaw) - 如果已对齐
    if (_isHeadingAligned && _dynamicYawOffset != 0) {
      final yawMatrix = Matrix3.rotationZ(_dynamicYawOffset);
      processedAccel = yawMatrix.transformed(processedAccel);
      rotatedGyro = yawMatrix.transformed(rotatedGyro);
    }

    // Stage 4: “点头”保护 (Pitch Guard)
    // 物理补偿：如果正在急刹车 (Y < -2.0) 且陀螺仪检测到明显的俯仰 (Gyro.x)
    if (processedAccel.y < -2.0 && rotatedGyro.x.abs() > 0.05) {
      processedAccel.y += (rotatedGyro.x * 0.3).clamp(-0.8, 0.8);
    }

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
    final double horizontalMag =
        math.sqrt(accel.x * accel.x + accel.y * accel.y);
    if (horizontalMag > 1.5 && accel.y > 0) {
      _headingLearningBuffer.addLast(accel.clone());
      if (_headingLearningBuffer.length > 20) {
        // 计算平均偏角
        double avgAngle = 0;
        for (var a in _headingLearningBuffer) {
          avgAngle += math.atan2(a.x, a.y);
        }
        avgAngle /= _headingLearningBuffer.length;

        // 如果偏角超过 3 度，触发修正
        if (avgAngle.abs() > 0.05) {
          _dynamicYawOffset -= avgAngle; // 减去偏角以归零
          debugPrint(
              "Heading Aligned: Adjusted by ${(avgAngle * 180 / math.pi).toStringAsFixed(1)}°");
        }
        _isHeadingAligned = true;
        _headingLearningBuffer.clear();
      }
    }
  }

  /// 顶级校准逻辑：增加状态重置、方差校验和陀螺仪守卫，确保校准是绝对干净的
  Future<void> calibrate({double currentSpeedMs = 0.0}) async {
    // 0. 车辆静止守卫：通过 GPS 速度判定
    if (currentSpeedMs > 0.1) {
      throw Exception(
          "校准失败：请在车辆完全停稳后进行 (当前车速: ${(currentSpeedMs * 3.6).toStringAsFixed(1)} km/h)");
    }

    // 1. 彻底清空旧的校准状态，确保二次校准不受干扰
    _isCalibrated = false;
    _rotationMatrix = Matrix3.identity();
    _staticGravityRaw = Vector3.zero();
    _dynamicYawOffset = 0.0;
    _isHeadingAligned = false;
    _headingLearningBuffer.clear();

    List<Vector3> accelSamples = [];
    List<Vector3> magSamples = [];
    List<double> gyroMagnitudes = [];
    const int sampleCount = 60; // 约 3.0 秒，修复校准时间过短问题
    const int skipSamples = 10; // 前 0.5 秒数据丢弃，避开点击按钮导致的晃动

    for (int i = 0; i < sampleCount + skipSamples; i++) {
      if (i >= skipSamples) {
        accelSamples.add(_latestAccel.clone());
        magSamples.add(_latestMag.clone());
        gyroMagnitudes.add(_latestGyro.length);
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 2. 陀螺仪守卫：检测校准期间是否有任何晃动
    final maxGyro = gyroMagnitudes.reduce(math.max);
    if (maxGyro > 0.1) {
      // 稍微放宽到 0.1，适配 Android 硬件基底噪声
      throw Exception("校准失败：请确保手机完全静止（检测到晃动: ${maxGyro.toStringAsFixed(3)}）");
    }

    // 3. 计算均值和方差
    Vector3 gMean = Vector3.zero();
    Vector3 mMean = Vector3.zero();
    for (int i = 0; i < sampleCount; i++) {
      gMean += accelSamples[i];
      mMean += magSamples[i];
    }
    gMean /= sampleCount.toDouble();
    mMean /= sampleCount.toDouble();

    double variance = 0;
    for (var s in accelSamples) {
      variance += (s - gMean).length2;
    }
    variance /= accelSamples.length;

    if (variance > 0.05) {
      throw Exception("校准失败：请确保手机完全静止（检测到震动: ${variance.toStringAsFixed(3)}）");
    }

    final gravityMag = gMean.length;
    if (gravityMag < 8.0 || gravityMag > 12.0) {
      throw Exception("校准失败：传感器读数异常 (G: ${gravityMag.toStringAsFixed(2)})");
    }

    // 4. 构建 3D 姿态矩阵 (支持水平倾斜/Yaw 对齐)
    // 第一性原理：利用重力确定垂直面，利用磁力计锁定水平参考
    final unitZ = gMean.normalized();

    // 计算 X 轴：磁场与重力的叉乘得到“水平东向”
    Vector3 unitX = mMean.cross(unitZ).normalized();
    // 鲁棒性：如果磁力计失效或与重力共线，退回到默认参考
    if (unitX.length < 0.1) {
      Vector3 reference =
          unitZ.y.abs() > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
      unitX = reference.cross(unitZ).normalized();
    }

    // 计算 Y 轴：Z 和 X 叉乘得到“水平北向”
    final unitY = unitZ.cross(unitX).normalized();

    final rot = Matrix3.columns(unitX, unitY, unitZ);
    _rotationMatrix = rot.isIdentity() ? rot : Matrix3.copy(rot)
      ..invert();
    _staticGravityRaw = gMean.clone();

    // 5. 计算物理角度用于输出验证
    // Pitch (俯仰角): 手机头部抬起/低下的角度
    final pitch = math.asin(-unitZ.y.clamp(-1.0, 1.0)) * 180 / math.pi;
    // Roll (横滚角): 手机向左/右倾斜的角度
    final roll = math.atan2(unitZ.x, unitZ.z) * 180 / math.pi;

    debugPrint("=== Calibration Confirmed ===");
    debugPrint(
        "Orientation: Pitch ${pitch.toStringAsFixed(1)}°, Roll ${roll.toStringAsFixed(1)}°");
    debugPrint(
        "Static Gravity Vector: ${gMean.x.toStringAsFixed(3)}, ${gMean.y.toStringAsFixed(3)}, ${gMean.z.toStringAsFixed(3)}");

    _isCalibrated = true;
    _processTick(DateTime.now());

    final firstPoint = _rotationMatrix.transformed(gMean - _staticGravityRaw);
    debugPrint(
        "Initial Processed (Should be 0): ${firstPoint.x.toStringAsFixed(3)}, ${firstPoint.y.toStringAsFixed(3)}, ${firstPoint.z.toStringAsFixed(3)}");
    debugPrint("==============================");
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
