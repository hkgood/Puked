import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class AlgorithmConfig {
  final double thresholdAccel;
  final double thresholdDecel;
  final double thresholdWobbleSpan;
  final double thresholdBump;
  final double thresholdJerk;
  final double thresholdPitch;

  final int jerkWindowMs;
  final int accelDecelWindowMs;
  final int wobbleWindowMs;
  final int fusionWindowMs;

  final double zyInterferenceThreshold; // Z轴活动抑制Y轴检测的阈值
  final double zxInterferenceThreshold; // Z轴活动抑制X轴检测的阈值
  final bool pitchValidationEnabled;

  final double speedLowFactor;
  final double speedHighFactor;

  // --- 动态抑制曲线参数 (v10.1 新增) ---
  final double couplingCurveIndex; // 抑制指数 (默认 1.2)
  final double couplingStrengthY; // Y轴(加减速)抑制强度 (默认 0.5)
  final double couplingStrengthX; // X轴(顿挫/摆动)抑制强度 (默认 0.8)
  final double turnCompMultiplier; // 转向补偿倍率 (默认 1.5)
  final double turnCompMax; // 转向补偿上限 (默认 2.5)
  final double eventWindowCoverage; // 窗口判定点数占比要求 (默认 0.75)
  final double lowSpeedJerkLimit; // 低速降级为顿挫的门槛 km/h (默认 2.0)

  // --- 物理合理性上限 (Sanity Check) ---
  final double maxJerkAllowed; // 最大允许 Jerk (m/s³)，超过则认为是手机掉落/晃动
  final double maxAccelAllowed; // 最大允许加速度 (m/s²)，约 2G
  final double maxWobbleSpanAllowed; // 最大允许横摆跨度 (m/s²)
  final double maxBumpAllowed; // 最大允许垂直冲击 (m/s²)，约 4G
  final double minAccelForJerk; // Jerk 触发的最小加速度基准 (m/s²)

  // --- 趋势过滤参数 (v13+ 新增，用于过滤温和减速/加速) ---
  final double trendChangeThreshold; // 趋势变化阈值 (默认 0.40)
  final bool enableTrendFilter; // 是否启用趋势过滤 (默认 true)
  final double minStdDevThreshold; // 标准差阈值（备用，默认 0.22）
  final double minRangeThreshold; // 跨度阈值（备用，默认 0.71）

  final int version;
  final String updatedAt;
  final String? id; // PocketBase Record ID

  AlgorithmConfig({
    required this.thresholdAccel,
    required this.thresholdDecel,
    required this.thresholdWobbleSpan,
    required this.thresholdBump,
    required this.thresholdJerk,
    required this.thresholdPitch,
    required this.jerkWindowMs,
    required this.accelDecelWindowMs,
    required this.wobbleWindowMs,
    required this.fusionWindowMs,
    required this.zyInterferenceThreshold,
    required this.zxInterferenceThreshold,
    required this.pitchValidationEnabled,
    required this.speedLowFactor,
    required this.speedHighFactor,
    required this.couplingCurveIndex,
    required this.couplingStrengthY,
    required this.couplingStrengthX,
    required this.turnCompMultiplier,
    required this.turnCompMax,
    required this.eventWindowCoverage,
    required this.lowSpeedJerkLimit,
    required this.maxJerkAllowed,
    required this.maxAccelAllowed,
    required this.maxWobbleSpanAllowed,
    required this.maxBumpAllowed,
    required this.minAccelForJerk,
    required this.trendChangeThreshold,
    required this.enableTrendFilter,
    required this.minStdDevThreshold,
    required this.minRangeThreshold,
    required this.version,
    required this.updatedAt,
    this.id,
  });

  factory AlgorithmConfig.fromJson(Map<String, dynamic> json,
      {String? recordId}) {
    debugPrint('🚀 [AlgorithmConfig] 开始解析云端 JSON, version: ${json['version']}');
    // 内部安全转换辅助函数
    double toDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      if (val is String) {
        final parsed = double.tryParse(val);
        if (parsed == null) {
          debugPrint(
              '⚠️ [AlgorithmConfig] 无法将 String "$val" 解析为 double, 使用默认值 $fallback');
        }
        return parsed ?? fallback;
      }
      return fallback;
    }

    int findInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    return AlgorithmConfig(
      thresholdAccel: toDouble(json['threshold_accel'], 2.2),
      thresholdDecel: toDouble(json['threshold_decel'], -2.0),
      thresholdWobbleSpan: toDouble(json['threshold_wobble_span'], 2.5),
      thresholdBump: toDouble(json['threshold_bump'], 5.5),
      thresholdJerk: toDouble(json['threshold_jerk'], 6.0),
      thresholdPitch: toDouble(json['threshold_pitch'], 1.5),
      jerkWindowMs: findInt(json['jerk_window_ms'], 250),
      accelDecelWindowMs: findInt(json['accel_decel_window_ms'], 600),
      wobbleWindowMs: findInt(json['wobble_window_ms'], 1000),
      fusionWindowMs: findInt(json['fusion_window_ms'], 3000),
      zyInterferenceThreshold: toDouble(json['zy_interference_threshold'], 1.5),
      zxInterferenceThreshold: toDouble(json['zx_interference_threshold'], 2.0),
      pitchValidationEnabled: json['pitch_validation_enabled'] ?? true,
      speedLowFactor: toDouble(json['speed_low_factor'], 1.1),
      speedHighFactor: toDouble(json['speed_high_factor'], 0.9),
      couplingCurveIndex: toDouble(json['coupling_curve_index'], 1.2),
      couplingStrengthY: toDouble(json['coupling_strength_y'], 0.5),
      couplingStrengthX: toDouble(json['coupling_strength_x'], 0.8),
      turnCompMultiplier: toDouble(json['turn_comp_multiplier'], 1.5),
      turnCompMax: toDouble(json['turn_comp_max'], 2.5),
      eventWindowCoverage: toDouble(json['event_window_coverage'], 0.75),
      lowSpeedJerkLimit: toDouble(json['low_speed_jerk_limit'], 2.0),
      maxJerkAllowed: toDouble(json['max_jerk_allowed'], 50.0),
      maxAccelAllowed: toDouble(json['max_accel_allowed'], 20.0),
      maxWobbleSpanAllowed: toDouble(json['max_wobble_span_allowed'], 20.0),
      maxBumpAllowed: toDouble(json['max_bump_allowed'], 40.0),
      minAccelForJerk: toDouble(json['min_accel_for_jerk'], 2.5),
      trendChangeThreshold: toDouble(json['trend_change_threshold'], 0.40),
      enableTrendFilter: json['enable_trend_filter'] ?? true,
      minStdDevThreshold: toDouble(json['min_std_dev_threshold'], 0.22),
      minRangeThreshold: toDouble(json['min_range_threshold'], 0.71),
      version: findInt(json['version'], 0),
      updatedAt: (json['updated'] ??
          json['updatedAt'] ??
          DateTime.now().toIso8601String()),
      id: recordId ?? json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'threshold_accel': thresholdAccel,
      'threshold_decel': thresholdDecel,
      'threshold_wobble_span': thresholdWobbleSpan,
      'threshold_bump': thresholdBump,
      'threshold_jerk': thresholdJerk,
      'threshold_pitch': thresholdPitch,
      'jerk_window_ms': jerkWindowMs,
      'accel_decel_window_ms': accelDecelWindowMs,
      'wobble_window_ms': wobbleWindowMs,
      'fusion_window_ms': fusionWindowMs,
      'zy_interference_threshold': zyInterferenceThreshold,
      'zx_interference_threshold': zxInterferenceThreshold,
      'pitch_validation_enabled': pitchValidationEnabled,
      'speed_low_factor': speedLowFactor,
      'speed_high_factor': speedHighFactor,
      'coupling_curve_index': couplingCurveIndex,
      'coupling_strength_y': couplingStrengthY,
      'coupling_strength_x': couplingStrengthX,
      'turn_comp_multiplier': turnCompMultiplier,
      'turn_comp_max': turnCompMax,
      'event_window_coverage': eventWindowCoverage,
      'low_speed_jerk_limit': lowSpeedJerkLimit,
      'max_jerk_allowed': maxJerkAllowed,
      'max_accel_allowed': maxAccelAllowed,
      'max_wobble_span_allowed': maxWobbleSpanAllowed,
      'max_bump_allowed': maxBumpAllowed,
      'min_accel_for_jerk': minAccelForJerk,
      'trend_change_threshold': trendChangeThreshold,
      'enable_trend_filter': enableTrendFilter,
      'min_std_dev_threshold': minStdDevThreshold,
      'min_range_threshold': minRangeThreshold,
      'version': version,
      'updatedAt': updatedAt,
      'id': id,
    };
  }

  AlgorithmConfig copyWith({
    double? thresholdAccel,
    double? thresholdDecel,
    double? thresholdWobbleSpan,
    double? thresholdBump,
    double? thresholdJerk,
    double? thresholdPitch,
    int? jerkWindowMs,
    int? accelDecelWindowMs,
    int? wobbleWindowMs,
    int? fusionWindowMs,
    double? zyInterferenceThreshold,
    double? zxInterferenceThreshold,
    bool? pitchValidationEnabled,
    double? speedLowFactor,
    double? speedHighFactor,
    double? couplingCurveIndex,
    double? couplingStrengthY,
    double? couplingStrengthX,
    double? turnCompMultiplier,
    double? turnCompMax,
    double? eventWindowCoverage,
    double? lowSpeedJerkLimit,
    double? maxJerkAllowed,
    double? maxAccelAllowed,
    double? maxWobbleSpanAllowed,
    double? maxBumpAllowed,
    double? minAccelForJerk,
    double? trendChangeThreshold,
    bool? enableTrendFilter,
    double? minStdDevThreshold,
    double? minRangeThreshold,
    int? version,
    String? updatedAt,
    String? id,
  }) {
    return AlgorithmConfig(
      thresholdAccel: thresholdAccel ?? this.thresholdAccel,
      thresholdDecel: thresholdDecel ?? this.thresholdDecel,
      thresholdWobbleSpan: thresholdWobbleSpan ?? this.thresholdWobbleSpan,
      thresholdBump: thresholdBump ?? this.thresholdBump,
      thresholdJerk: thresholdJerk ?? this.thresholdJerk,
      thresholdPitch: thresholdPitch ?? this.thresholdPitch,
      jerkWindowMs: jerkWindowMs ?? this.jerkWindowMs,
      accelDecelWindowMs: accelDecelWindowMs ?? this.accelDecelWindowMs,
      wobbleWindowMs: wobbleWindowMs ?? this.wobbleWindowMs,
      fusionWindowMs: fusionWindowMs ?? this.fusionWindowMs,
      zyInterferenceThreshold:
          zyInterferenceThreshold ?? this.zyInterferenceThreshold,
      zxInterferenceThreshold:
          zxInterferenceThreshold ?? this.zxInterferenceThreshold,
      pitchValidationEnabled:
          pitchValidationEnabled ?? this.pitchValidationEnabled,
      speedLowFactor: speedLowFactor ?? this.speedLowFactor,
      speedHighFactor: speedHighFactor ?? this.speedHighFactor,
      couplingCurveIndex: couplingCurveIndex ?? this.couplingCurveIndex,
      couplingStrengthY: couplingStrengthY ?? this.couplingStrengthY,
      couplingStrengthX: couplingStrengthX ?? this.couplingStrengthX,
      turnCompMultiplier: turnCompMultiplier ?? this.turnCompMultiplier,
      turnCompMax: turnCompMax ?? this.turnCompMax,
      eventWindowCoverage: eventWindowCoverage ?? this.eventWindowCoverage,
      lowSpeedJerkLimit: lowSpeedJerkLimit ?? this.lowSpeedJerkLimit,
      maxJerkAllowed: maxJerkAllowed ?? this.maxJerkAllowed,
      maxAccelAllowed: maxAccelAllowed ?? this.maxAccelAllowed,
      maxWobbleSpanAllowed: maxWobbleSpanAllowed ?? this.maxWobbleSpanAllowed,
      maxBumpAllowed: maxBumpAllowed ?? this.maxBumpAllowed,
      minAccelForJerk: minAccelForJerk ?? this.minAccelForJerk,
      trendChangeThreshold: trendChangeThreshold ?? this.trendChangeThreshold,
      enableTrendFilter: enableTrendFilter ?? this.enableTrendFilter,
      minStdDevThreshold: minStdDevThreshold ?? this.minStdDevThreshold,
      minRangeThreshold: minRangeThreshold ?? this.minRangeThreshold,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
    );
  }

  /// 默认配置 (同步云端 v14)
  factory AlgorithmConfig.defaultConfig() {
    return AlgorithmConfig(
      thresholdAccel: 2.0,
      thresholdDecel: -1.6,
      thresholdWobbleSpan: 3.5,
      thresholdBump: 4.5,
      thresholdJerk: 6.0,
      thresholdPitch: 0.8,
      jerkWindowMs: 250,
      accelDecelWindowMs: 400,
      wobbleWindowMs: 1000,
      fusionWindowMs: 3000,
      zyInterferenceThreshold: 2.5,
      zxInterferenceThreshold: 2.8,
      pitchValidationEnabled: true,
      speedLowFactor: 1.1,
      speedHighFactor: 0.9,
      couplingCurveIndex: 1.2,
      couplingStrengthY: 0.5,
      couplingStrengthX: 0.8,
      turnCompMultiplier: 2.0,
      turnCompMax: 3.5,
      eventWindowCoverage: 0.6,
      lowSpeedJerkLimit: 2.0,
      maxJerkAllowed: 50.0,
      maxAccelAllowed: 20.0,
      maxWobbleSpanAllowed: 20.0,
      maxBumpAllowed: 40.0,
      minAccelForJerk: 3.0,
      trendChangeThreshold: 0.40,
      enableTrendFilter: true,
      minStdDevThreshold: 0.22,
      minRangeThreshold: 0.71,
      version: 14,
      updatedAt: '2026-02-10T12:00:00.000Z',
    );
  }
}
