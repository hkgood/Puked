import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:puked/models/sensor_data.dart';
import 'package:puked/features/recording/domain/algorithm_config.dart';
import 'package:puked/common/config/constants.dart';
import 'package:puked/common/config/enums.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart';

/// 原始待定事件
class RawMotionEvent {
  final EventType type;
  final DateTime timestamp;
  final double speed;
  final Position? position;

  RawMotionEvent({
    required this.type,
    required this.timestamp,
    required this.speed,
    this.position,
  });
}

/// 运动事件处理器：负责从原始传感器流中检测物理事件，并进行初步的聚合与防抖
class MotionProcessor {
  AlgorithmConfig config;
  final bool isIos;

  // 传感器历史记录
  final ListQueue<MapEntry<DateTime, double>> _xHistory = ListQueue();
  final ListQueue<MapEntry<DateTime, double>> _yHistory = ListQueue();
  final ListQueue<MapEntry<DateTime, double>> _yawRateHistory = ListQueue();

  // 防抖计时器
  final Map<String, DateTime> _lastTriggered = {};
  static const Duration _debounceDuration = AppConstants.eventDebounceDuration;

  // 聚合缓冲区
  final List<RawMotionEvent> _pendingEvents = [];
  Timer? _fusionTimer;

  // G 值平滑缓冲区
  final ListQueue<double> _gHistory = ListQueue();

  // 事件回调
  final Function(
          EventType type, DateTime timestamp, Position? position, double speed)
      onEventDetected;
  final Function(double gForce) onGForceUpdated;

  MotionProcessor({
    required this.config,
    required this.onEventDetected,
    required this.onGForceUpdated,
    this.isIos = false,
  });

  /// 处理新的传感器数据点
  void process(SensorData data, double currentSpeedMs,
      Position? currentPosition, bool isInsActive) {
    final now = DateTime.now();

    // 1. 实时 G 值处理 (不分车速)
    final rawG = data.processedAccel.length / AppConstants.gravity;
    _gHistory.addLast(rawG);
    if (_gHistory.length > (isIos ? 6 : 3)) {
      _gHistory.removeFirst();
    }
    final smoothedG = _gHistory.reduce((a, b) => a + b) / _gHistory.length;
    onGForceUpdated(smoothedG);

    final currentSpeedKmh = currentSpeedMs * AppConstants.msToKmh;

    // 1. 物理隔离：极低速不检测
    if (currentSpeedKmh < 3.0) {
      _xHistory.addLast(MapEntry(now, data.processedAccel.x));
      _yHistory.addLast(MapEntry(now, data.processedAccel.y));
      return;
    }

    // 更新历史记录
    _xHistory.addLast(MapEntry(now, data.processedAccel.x));
    _yHistory.addLast(MapEntry(now, data.processedAccel.y));
    _yawRateHistory.addLast(MapEntry(now, data.processedGyro.z));

    // 清理过期数据
    _cleanupHistory(now);

    // 计算自适应倍率
    final factor = _getPlatformAdaptabilityFactor(currentSpeedKmh);

    // 抑制与补偿计算
    final suppression = _calculateSuppression(data.processedAccel);
    final turnComp = _calculateTurnCompensation(data.processedGyro.z);

    // 执行各项检测逻辑
    _detectRapidAccelDecel(
        now, factor, suppression.y, turnComp, currentPosition, currentSpeedMs);
    _detectJerk(now, factor, suppression.x, turnComp, currentPosition,
        currentSpeedMs, data.processedAccel.z);
    _detectWobble(now, currentSpeedKmh, factor, suppression.y, currentPosition,
        currentSpeedMs);
    _detectBump(now, data.processedAccel.z, currentPosition, currentSpeedMs);
  }

  void _cleanupHistory(DateTime now) {
    while (_xHistory.isNotEmpty &&
        now.difference(_xHistory.first.key).inMilliseconds >
            config.wobbleWindowMs) {
      _xHistory.removeFirst();
    }
    while (_yHistory.isNotEmpty &&
        now.difference(_yHistory.first.key).inMilliseconds >
            config.accelDecelWindowMs * 2) {
      _yHistory.removeFirst();
    }
    while (_yawRateHistory.isNotEmpty &&
        now.difference(_yawRateHistory.first.key).inMilliseconds >
            config.wobbleWindowMs) {
      _yawRateHistory.removeFirst();
    }
  }

  double _getPlatformAdaptabilityFactor(double speedKmh) {
    if (speedKmh < 10.0) return config.speedLowFactor;
    if (speedKmh > 80.0) return config.speedHighFactor;
    return 1.0;
  }

  ({double x, double y}) _calculateSuppression(Vector3 accel) {
    double sx = 1.0, sy = 1.0;
    final az = accel.z.abs();

    if (az > config.zyInterferenceThreshold) {
      sy = (1.0 +
              math.pow(az - config.zyInterferenceThreshold,
                      config.couplingCurveIndex) *
                  config.couplingStrengthY)
          .clamp(1.0, 3.5);
    }
    if (az > config.zxInterferenceThreshold) {
      sx = (1.0 +
              math.pow(az - config.zxInterferenceThreshold,
                      config.couplingCurveIndex) *
                  config.couplingStrengthX)
          .clamp(1.0, 5.0);
    }
    return (x: sx, y: sy);
  }

  double _calculateTurnCompensation(double yawRateRad) {
    final yawRate = yawRateRad.abs();
    if (yawRate > 0.1) {
      return (1.0 + (yawRate * config.turnCompMultiplier))
          .clamp(1.0, config.turnCompMax);
    }
    return 1.0;
  }

  bool _isDebounced(String type, DateTime now) {
    final last = _lastTriggered[type];
    if (last == null) return false;

    final interval = now.difference(last);

    // 🔧 针对急刹车/急加速使用更长的防抖时间（3.5秒）
    // 原因：这类事件往往是持续动作，短时间内的多次触发可能是同一事件
    if (type == 'rapidDeceleration' || type == 'rapidAcceleration') {
      return interval < const Duration(milliseconds: 3500); // 3.5 秒
    }

    // 其他事件类型使用默认防抖时间（2秒）
    return interval < _debounceDuration;
  }

  void _detectRapidAccelDecel(DateTime now, double factor, double suppressionY,
      double turnComp, Position? pos, double speed) {
    final window = _yHistory
        .where((e) =>
            now.difference(e.key).inMilliseconds < config.accelDecelWindowMs)
        .toList();
    final minPoints = isIos ? 10 : 5;

    if (window.length < minPoints) return;

    // ✅ 第一道防线：趋势过滤（过滤温和减速/加速）
    if (config.enableTrendFilter) {
      final yValues = window.map((e) => e.value).toList();
      final mid = yValues.length ~/ 2;

      // 计算前后半段的平均值
      final firstHalfAvg =
          yValues.sublist(0, mid).reduce((a, b) => a + b) / mid;
      final secondHalfAvg =
          yValues.sublist(mid).reduce((a, b) => a + b) / (yValues.length - mid);

      // 趋势变化 = |后半段平均值 - 前半段平均值|
      final trend = (secondHalfAvg - firstHalfAvg).abs();

      // 如果趋势变化小于阈值，说明是温和减速/加速，过滤掉
      if (trend < config.trendChangeThreshold) {
        debugPrint(
            '⚠️ [TrendFilter] 过滤温和事件: trend=${trend.toStringAsFixed(3)} < ${config.trendChangeThreshold}');
        return;
      }

      debugPrint(
          '✅ [TrendFilter] 通过趋势检测: trend=${trend.toStringAsFixed(3)} ≥ ${config.trendChangeThreshold}');
    }

    final decelThreshold =
        config.thresholdDecel * factor * suppressionY * turnComp;
    final accelThreshold =
        config.thresholdAccel * factor * suppressionY * turnComp;

    int decelCount = window.where((e) => e.value < decelThreshold).length;
    int accelCount = window.where((e) => e.value > accelThreshold).length;

    final coverage = (window.length * config.eventWindowCoverage).floor();

    // 🔍 DEBUG: 记录Y轴数据范围，帮助诊断方向问题
    final yValues = window.map((e) => e.value).toList();
    final minY = yValues.reduce((a, b) => a < b ? a : b);
    final maxY = yValues.reduce((a, b) => a > b ? a : b);
    final avgY = yValues.reduce((a, b) => a + b) / yValues.length;

    if (decelCount >= coverage && !_isDebounced('rapidDeceleration', now)) {
      debugPrint('🚨 [Event] Rapid DECELERATION detected!');
      debugPrint(
          '   Y-axis range: [${minY.toStringAsFixed(3)}, ${maxY.toStringAsFixed(3)}], avg: ${avgY.toStringAsFixed(3)}');
      debugPrint(
          '   Threshold: ${decelThreshold.toStringAsFixed(3)}, Count: $decelCount/$coverage');
      _lastTriggered['rapidDeceleration'] = now;
      _enqueue(EventType.rapidDeceleration, now, pos, speed);
    } else if (accelCount >= coverage &&
        !_isDebounced('rapidAcceleration', now)) {
      debugPrint('🚨 [Event] Rapid ACCELERATION detected!');
      debugPrint(
          '   Y-axis range: [${minY.toStringAsFixed(3)}, ${maxY.toStringAsFixed(3)}], avg: ${avgY.toStringAsFixed(3)}');
      debugPrint(
          '   Threshold: ${accelThreshold.toStringAsFixed(3)}, Count: $accelCount/$coverage');
      _lastTriggered['rapidAcceleration'] = now;
      _enqueue(EventType.rapidAcceleration, now, pos, speed);
    }
  }

  void _detectJerk(DateTime now, double factor, double suppressionX,
      double turnComp, Position? pos, double speed, double currentAz) {
    if (_isDebounced('jerk', now)) return;

    // 🔥 Z轴过滤：如果垂直加速度显著（>2.0 m/s²），很可能是减速带/颠簸，不触发jerk
    if (currentAz.abs() > 2.0) {
      debugPrint(
          '⚠️ [Jerk Filter] Z轴冲击显著 (${currentAz.toStringAsFixed(2)} m/s²), 疑似减速带/颠簸');
      return;
    }

    final window = _yHistory
        .where(
            (e) => now.difference(e.key).inMilliseconds < config.jerkWindowMs)
        .toList();
    if (window.length < 5) return;

    double maxJerk = 0;
    for (int i = 5; i < window.length; i++) {
      final dt = window[i].key.difference(window[i - 5].key).inMicroseconds /
          1000000.0;
      if (dt > 0.05) {
        final jerk = (window[i].value - window[i - 5].value) / dt;
        if (jerk.abs() > maxJerk.abs()) maxJerk = jerk;
      }
    }

    if (maxJerk.abs() >
            (config.thresholdJerk * factor * suppressionX * turnComp) &&
        maxJerk.abs() < config.maxJerkAllowed) {
      final peakAy = window.map((e) => e.value.abs()).reduce(math.max);
      if (peakAy > config.minAccelForJerk) {
        _lastTriggered['jerk'] = now;
        _enqueue(EventType.jerk, now, pos, speed);
      }
    }
  }

  void _detectWobble(DateTime now, double speedKmh, double factor,
      double suppressionY, Position? pos, double speed) {
    if (_isDebounced('wobble', now) || speedKmh <= 10.0) return;

    final recentX = _xHistory
        .where(
            (e) => now.difference(e.key).inMilliseconds < config.wobbleWindowMs)
        .toList();
    final recentYaw = _yawRateHistory
        .where(
            (e) => now.difference(e.key).inMilliseconds < config.wobbleWindowMs)
        .toList();
    final minPoints = isIos ? 8 : 4;

    if (recentX.length < minPoints) return;

    double minX = 0, maxX = 0;
    for (var e in recentX) {
      if (e.value < minX) minX = e.value;
      if (e.value > maxX) maxX = e.value;
    }
    final span = maxX - minX;

    int switches = 0;
    for (int i = 1; i < recentYaw.length; i++) {
      if (recentYaw[i].value.sign != recentYaw[i - 1].value.sign &&
          recentYaw[i].value.abs() > 0.05) switches++;
    }

    if (span > (config.thresholdWobbleSpan * factor * suppressionY) &&
        span < config.maxWobbleSpanAllowed &&
        switches >= 1) {
      _lastTriggered['wobble'] = now;
      _enqueue(EventType.wobble, now, pos, speed);
    }
  }

  void _detectBump(DateTime now, double az, Position? pos, double speed) {
    if (_isDebounced('bump', now)) return;
    final azAbs = az.abs();
    if (azAbs > config.thresholdBump && azAbs < config.maxBumpAllowed) {
      _lastTriggered['bump'] = now;
      _enqueue(EventType.bump, now, pos, speed);
    }
  }

  void _enqueue(EventType type, DateTime ts, Position? pos, double speed) {
    _pendingEvents.add(
        RawMotionEvent(type: type, timestamp: ts, speed: speed, position: pos));
    _fusionTimer ??=
        Timer(Duration(milliseconds: config.fusionWindowMs), _processPending);
  }

  void _processPending() {
    _fusionTimer = null;
    if (_pendingEvents.isEmpty) return;

    final priority = {
      EventType.rapidAcceleration: 1,
      EventType.rapidDeceleration: 1,
      EventType.bump: 2,
      EventType.jerk: 3,
      EventType.wobble: 4,
    };

    _pendingEvents.sort(
        (a, b) => (priority[a.type] ?? 99).compareTo(priority[b.type] ?? 99));

    final main = _pendingEvents.first;
    var finalType = main.type;

    if (finalType == EventType.rapidDeceleration &&
        (main.speed * 3.6) < config.lowSpeedJerkLimit) {
      finalType = EventType.jerk;
    }

    onEventDetected(finalType, main.timestamp, main.position, main.speed);
    _pendingEvents.clear();
  }

  void dispose() {
    _fusionTimer?.cancel();
  }
}
