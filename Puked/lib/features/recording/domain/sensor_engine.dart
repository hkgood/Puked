import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

final sensorEngineProvider = Provider<SensorEngine>((ref) {
  final engine = SensorEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

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

  // ✅ 静止检测与自动校准相关
  DateTime? _stationaryStartTime;
  double _lastKnownSpeed = 0.0;
  bool _autoCalibrationInProgress = false;
  DateTime? _lastAutoCalibrationTime;

  /// 仅在「已开始行程」时为 true，由 RecordingProvider 在 start/stopRecording 时设置
  bool _isRecording = false;

  /// 连续自动校准失败次数，用于失败后退避
  int _consecutiveAutoCalibrationFailures = 0;

  /// 基础冷却时间（秒）
  static const int _autoCalibrationCooldownSeconds = 15;

  /// 连续失败 2 次后的退避冷却时间（秒），彻底避免持续重试
  static const int _autoCalibrationBackoffSeconds = 60;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  StreamSubscription? _magSub;
  Timer? _samplingTimer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  DateTime get lastSensorEventTime => _lastSensorEventTime;
  int get sensorEventCount => _sensorEventCount;

  /// 由 RecordingProvider 在开始/停止行程时调用，仅行程中才允许自动校准
  void setRecording(bool recording) {
    _isRecording = recording;
    if (!recording) {
      _consecutiveAutoCalibrationFailures = 0;
    }
  }

  /// 由 RecordingProvider 传入「仅用于静止判断」的速度 (m/s)。
  /// 必须为 GPS 速度：INS 在手机角度变化时会误报 1～5，若用 INS 会形成「不静止→不校准→继续漂移」的死循环。
  void updateSpeed(double speedMs) {
    _lastKnownSpeed = speedMs;
  }

  /// 上次自动校准完成时间（用于调试或 UI 显示「上次校准：xx 秒前」）
  DateTime? get lastAutoCalibrationTime => _lastAutoCalibrationTime;

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

  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    _magSub?.cancel();
    _magSub = null;
    _samplingTimer?.cancel();
    _samplingTimer = null;
    debugPrint('SensorEngine stopped');
  }

  void _processTick(DateTime timestamp) {
    final now = timestamp;

    // Stage 1: 中值滤波 (Median Filter) - 消除硬件毛刺
    _medianBuffer.addLast(_latestAccel.clone());
    if (_medianBuffer.length > _medianWindowSize) _medianBuffer.removeFirst();
    Vector3 smoothedAccel = _calculateMedian(_medianBuffer.toList());

    // 🔍 DEBUG: 异常值检测和日志（针对原地晃动测试）
    if (_medianBuffer.length >= 3) {
      final prev = _medianBuffer.elementAt(_medianBuffer.length - 2);
      final jumpMagnitude = (smoothedAccel - prev).length;

      // 降低阈值到 10 m/s² 以便在原地晃动时也能检测到
      if (jumpMagnitude > 10.0) {
        debugPrint(
            '🔴 OVERFLOW! Jump: ${jumpMagnitude.toStringAsFixed(2)} m/s²');
        debugPrint(
            '   ax: ${prev.x.toStringAsFixed(3)} → ${smoothedAccel.x.toStringAsFixed(3)} (Δ${(smoothedAccel.x - prev.x).toStringAsFixed(3)})');
        debugPrint(
            '   ay: ${prev.y.toStringAsFixed(3)} → ${smoothedAccel.y.toStringAsFixed(3)} (Δ${(smoothedAccel.y - prev.y).toStringAsFixed(3)})');
        debugPrint(
            '   az: ${prev.z.toStringAsFixed(3)} → ${smoothedAccel.z.toStringAsFixed(3)} (Δ${(smoothedAccel.z - prev.z).toStringAsFixed(3)})');
        debugPrint('   ✅ FILTERED: Using previous value');
        smoothedAccel = prev.clone(); // 用前一个值替代异常值
      }
    }

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

    // Stage 4: 俯仰保护 (Pitch Guard) — 上坡 + 下坡误触发抑制
    // 上坡：急刹误触 — Y 偏负且存在俯仰时，补偿使 |Y| 减小
    if (processedAccel.y < -2.0 && rotatedGyro.x.abs() > 0.05) {
      processedAccel.y += (rotatedGyro.x * 0.3).clamp(-0.8, 0.8);
    }
    // 下坡/进地库：急加速误触 — Y 偏正且存在俯仰时，补偿使 Y 减小
    if (processedAccel.y > 2.0 && rotatedGyro.x.abs() > 0.05) {
      processedAccel.y += (rotatedGyro.x * 0.3).clamp(-0.8, 0.8);
    }

    // 低通滤波用于平滑显示
    _filteredAccel =
        _filteredAccel * (1.0 - _lpfCoeff) + processedAccel * _lpfCoeff;

    // 🔍 DEBUG: 持续监控 processedAccel 的值，检测并过滤溢出
    final accelMagnitude = processedAccel.length;
    if (accelMagnitude > 50.0) {
      // 5G 以上绝对是异常
      debugPrint('🚨 CRITICAL OVERFLOW in processedAccel!');
      debugPrint(
          '   Magnitude: ${accelMagnitude.toStringAsFixed(2)} m/s² (${(accelMagnitude / 9.80665).toStringAsFixed(2)} G)');
      debugPrint(
          '   Values: (${processedAccel.x.toStringAsFixed(3)}, ${processedAccel.y.toStringAsFixed(3)}, ${processedAccel.z.toStringAsFixed(3)})');
      debugPrint('   ✅ CLAMPING to zero (treating as sensor failure)');

      // 过滤策略：超过 5G 的数据认为是传感器故障，直接归零
      processedAccel = Vector3.zero();
    }

    final data = SensorData(
      timestamp: now,
      accelerometer: _latestAccel.clone(),
      gyroscope: _latestGyro.clone(),
      magnetometer: _latestMag.clone(),
      processedAccel: processedAccel,
      processedGyro: rotatedGyro,
      filteredAccel: _filteredAccel,
    );

    // 动态航向学习逻辑：
    // - 只在未对齐且有足够数据时尝试学习
    // - 移除时间限制，让学习过程更灵活（只要检测到加速就触发）
    if (!_isHeadingAligned && _buffer.length > 60) {
      _learnHeading(processedAccel);
    }

    // 🔍 DEBUG: 每隔一段时间输出当前状态
    if (_sensorEventCount % 300 == 0) {
      // 约每5秒输出一次（60Hz * 5s = 300）
      debugPrint(
          '📊 [Sensor Status] Aligned: $_isHeadingAligned, YawOffset: ${(_dynamicYawOffset * 180 / math.pi).toStringAsFixed(1)}°');
      debugPrint(
          '   Current processedAccel: (${processedAccel.x.toStringAsFixed(3)}, ${processedAccel.y.toStringAsFixed(3)}, ${processedAccel.z.toStringAsFixed(3)})');
    }

    // 更新缓冲区
    if (_buffer.length >= bufferLimit) {
      _buffer.removeFirst();
    }
    _buffer.addLast(data);

    // 推送到 UI 层
    _dataController.add(data);

    // 静止检测并可能触发自动校准（依赖 RecordingProvider 通过 updateSpeed 传入的速度）
    _checkStationaryAndTriggerAutoCalibration(_lastKnownSpeed, now);
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

  /// ✅ 静止状态检测
  bool _isVehicleStationary(double speedMs, DateTime now) {
    if (speedMs > 0.5) {
      _stationaryStartTime = null;
      return false;
    }

    _stationaryStartTime ??= now;
    final stationaryDuration = now.difference(_stationaryStartTime!);

    return stationaryDuration.inSeconds >= 1; // 连续静止1秒
  }

  /// ✅ 检查静止状态并触发自动校准
  void _checkStationaryAndTriggerAutoCalibration(double speedMs, DateTime now) {
    _lastKnownSpeed = speedMs;

    // 仅允许在「已开始行程」后触发，未点开始行程时不校准
    if (!_isRecording) return;

    // 如果不是静止状态，重置计时器
    if (!_isVehicleStationary(speedMs, now)) {
      _autoCalibrationInProgress = false;
      return;
    }

    // 检查是否已经在进行自动校准
    if (_autoCalibrationInProgress) return;

    // 检查静止时长是否达到3秒
    final stationaryDuration = now.difference(_stationaryStartTime!);
    if (stationaryDuration.inSeconds < 3) return;

    // 冷却：只要发生过失败就用长冷却（60s），成功后才用基础冷却（15s），彻底避免失败后持续重试
    final cooldownSec = _consecutiveAutoCalibrationFailures >= 1
        ? _autoCalibrationBackoffSeconds
        : _autoCalibrationCooldownSeconds;
    if (_lastAutoCalibrationTime != null) {
      final timeSinceLastCalib = now.difference(_lastAutoCalibrationTime!);
      if (timeSinceLastCalib.inSeconds < cooldownSec) {
        return;
      }
    }

    // 触发自动校准（静默模式）
    _autoCalibrationInProgress = true;
    debugPrint('🔄 [Auto-Calibration] Triggering silent recalibration...');

    // 异步执行，不阻塞主流程
    _performAutoCalibration(speedMs).then((_) {
      _autoCalibrationInProgress = false;
    }).catchError((e) {
      debugPrint('⚠️ [Auto-Calibration] Failed: $e');
      _autoCalibrationInProgress = false;
    });
  }

  /// ✅ 执行自动校准（静默模式，复用主校准逻辑）
  Future<void> _performAutoCalibration(double currentSpeedMs) async {
    try {
      await calibrate(currentSpeedMs: currentSpeedMs);
      _lastAutoCalibrationTime = DateTime.now();
      _consecutiveAutoCalibrationFailures = 0;
      debugPrint('✅ [Auto-Calibration] Successfully recalibrated!');
    } catch (e) {
      debugPrint('⚠️ [Auto-Calibration] Rejected: $e');
      _lastAutoCalibrationTime = DateTime.now();
      _consecutiveAutoCalibrationFailures++;
      // 连续失败时由调用方用长冷却（60s）限制，此处不再额外逻辑
    }
  }

  void _learnHeading(Vector3 accel) {
    // ✅ 第一性原理修复：自动学习车辆真实前进方向
    // 核心思想：
    // 1. 车辆加速时，加速度矢量指向车头方向
    // 2. 车头可能朝任意方向（东南西北），不能假设朝北
    // 3. 通过累积加速度样本，统计主导方向，自动对齐Y轴

    // 1. 计算水平面加速度的模长
    final double horizontalMag =
        math.sqrt(accel.x * accel.x + accel.y * accel.y);

    // 2. 只要水平加速度足够大（>1.5 m/s²），就记录样本
    // ⚠️ 关键修复：移除 accel.y > 0 的限制！
    if (horizontalMag > 1.5) {
      _headingLearningBuffer.addLast(accel.clone());

      if (_headingLearningBuffer.length >= 20) {
        debugPrint(
            '🧭 [Heading Learning] Analyzing ${_headingLearningBuffer.length} acceleration samples...');

        // 3. 计算所有样本的平均加速度向量
        double sumX = 0;
        double sumY = 0;
        for (var a in _headingLearningBuffer) {
          sumX += a.x;
          sumY += a.y;
        }
        final avgX = sumX / _headingLearningBuffer.length;
        final avgY = sumY / _headingLearningBuffer.length;

        debugPrint(
            '   Average acceleration vector: (${avgX.toStringAsFixed(3)}, ${avgY.toStringAsFixed(3)})');

        // 4. 计算平均方向相对于地理北方（+Y轴）的角度
        final avgAngle = math.atan2(avgX, avgY);
        final angleDeg = avgAngle * 180 / math.pi;

        debugPrint(
            '   Angle from geographic North: ${angleDeg.toStringAsFixed(1)}°');

        // 5. 关键决策：根据平均Y分量判断车辆主要前进方向
        if (avgY.abs() < 0.5 && avgX.abs() > 1.0) {
          // 情况A：车头主要朝东或朝西（Y分量很小）
          _dynamicYawOffset = -avgAngle;
          debugPrint('   🚗 Vehicle heading EAST/WEST (X-dominant)');
          debugPrint(
              '   Applied Yaw correction: ${(_dynamicYawOffset * 180 / math.pi).toStringAsFixed(1)}°');
        } else if (avgY < -0.5) {
          // 情况B：车头朝南方向（Y分量显著为负）
          // 需要180度翻转 + 角度修正
          if (avgAngle >= 0) {
            _dynamicYawOffset = -(avgAngle - math.pi);
          } else {
            _dynamicYawOffset = -(avgAngle + math.pi);
          }
          debugPrint('   🔄 Vehicle heading SOUTH (Y-negative)');
          debugPrint(
              '   Applied 180° flip + correction: ${(_dynamicYawOffset * 180 / math.pi).toStringAsFixed(1)}°');
        } else {
          // 情况C：车头朝北方向（Y分量为正）
          _dynamicYawOffset = -avgAngle;
          debugPrint('   ✅ Vehicle heading NORTH (Y-positive)');
          debugPrint(
              '   Applied normal correction: ${(_dynamicYawOffset * 180 / math.pi).toStringAsFixed(1)}°');
        }

        _isHeadingAligned = true;
        _headingLearningBuffer.clear();

        debugPrint('🎯 ========== Heading Alignment COMPLETE ==========');
        debugPrint(
            '   Final transform: Geographic → Vehicle coordinate system');
        debugPrint('   Y-axis now points to vehicle FORWARD direction');
      }
    }
  }

  /// 顶级校准逻辑：增加状态重置、方差校验和陀螺仪守卫，确保校准是绝对干净的
  Future<void> calibrate({double currentSpeedMs = 0.0}) async {
    // 0. 车辆静止守卫：通过 GPS 速度判定 (放宽到 0.5m/s = 1.8km/h)
    if (currentSpeedMs > 0.5) {
      throw Exception("calibration_failed_stationary");
    }

    // 1. 先采样与校验，不先清空状态；任一校验失败则 throw，保持上一次校准值不变
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
    if (maxGyro > 0.3) {
      // 进一步放宽到 0.3，适配 Android 硬件基底噪声
      throw Exception("calibration_failed_motion");
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

    if (variance > 0.15) {
      // 从 0.05 放宽到 0.15
      throw Exception("calibration_failed_motion");
    }

    final gravityMag = gMean.length;
    if (gravityMag < 8.0 || gravityMag > 12.0) {
      throw Exception("sensor_error");
    }

    // 4. 全部校验通过后再覆盖：先重置航向学习状态，再写入新旋转与重力，失败时上面已 throw，旧值保持不变
    final unitZ = gMean.normalized();
    Vector3 unitX = mMean.cross(unitZ).normalized();
    if (unitX.length < 0.1) {
      Vector3 reference =
          unitZ.y.abs() > 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
      unitX = reference.cross(unitZ).normalized();
    }
    final unitY = unitZ.cross(unitX).normalized();
    final rot = Matrix3.columns(unitX, unitY, unitZ);

    _dynamicYawOffset = 0.0;
    _isHeadingAligned = false;
    _headingLearningBuffer.clear();
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
  List<SensorData> getLookbackBuffer(int seconds,
      {int targetHz = 20, DateTime? endTime}) {
    // 计算原始采样率 (iOS 60Hz, Android 30Hz)
    final sourceHz = Platform.isIOS ? 60 : 30;
    final step = (sourceHz / targetHz).round().clamp(1, 10);

    final end = endTime ?? DateTime.now();
    final start = end.subtract(Duration(seconds: seconds));

    // 根据时间戳从缓冲区筛选数据
    final rawList = _buffer
        .where((d) => d.timestamp.isAfter(start) && d.timestamp.isBefore(end))
        .toList();

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
