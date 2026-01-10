import 'dart:math' as math;

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

  // --- 物理合理性上限 (Sanity Check) ---
  final double maxJerkAllowed; // 最大允许 Jerk (m/s³)，超过则认为是手机掉落/晃动
  final double maxAccelAllowed; // 最大允许加速度 (m/s²)，约 2G
  final double maxWobbleSpanAllowed; // 最大允许横摆跨度 (m/s²)
  final double maxBumpAllowed; // 最大允许垂直冲击 (m/s²)，约 4G
  final double minAccelForJerk; // Jerk 触发的最小加速度基准 (m/s²)

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
    required this.maxJerkAllowed,
    required this.maxAccelAllowed,
    required this.maxWobbleSpanAllowed,
    required this.maxBumpAllowed,
    required this.minAccelForJerk,
    required this.version,
    required this.updatedAt,
    this.id,
  });

  factory AlgorithmConfig.fromJson(Map<String, dynamic> json,
      {String? recordId}) {
    return AlgorithmConfig(
      thresholdAccel: (json['threshold_accel'] ?? 2.2).toDouble(),
      thresholdDecel: (json['threshold_decel'] ?? -2.0).toDouble(),
      thresholdWobbleSpan: (json['threshold_wobble_span'] ?? 2.5).toDouble(),
      thresholdBump: (json['threshold_bump'] ?? 5.5).toDouble(),
      thresholdJerk: (json['threshold_jerk'] ?? 6.0).toDouble(),
      thresholdPitch: (json['threshold_pitch'] ?? 1.5).toDouble(),
      jerkWindowMs: (json['jerk_window_ms'] ?? 250).toInt(),
      accelDecelWindowMs: (json['accel_decel_window_ms'] ?? 600).toInt(),
      wobbleWindowMs: (json['wobble_window_ms'] ?? 1000).toInt(),
      fusionWindowMs: (json['fusion_window_ms'] ?? 3000).toInt(),
      zyInterferenceThreshold:
          (json['zy_interference_threshold'] ?? 1.5).toDouble(),
      zxInterferenceThreshold:
          (json['zx_interference_threshold'] ?? 2.0).toDouble(),
      pitchValidationEnabled: json['pitch_validation_enabled'] ?? true,
      speedLowFactor: (json['speed_low_factor'] ?? 1.1).toDouble(),
      speedHighFactor: (json['speed_high_factor'] ?? 0.9).toDouble(),
      // 物理上限解析
      maxJerkAllowed: (json['max_jerk_allowed'] ?? 50.0).toDouble(),
      maxAccelAllowed: (json['max_accel_allowed'] ?? 20.0).toDouble(),
      maxWobbleSpanAllowed:
          (json['max_wobble_span_allowed'] ?? 20.0).toDouble(),
      maxBumpAllowed: (json['max_bump_allowed'] ?? 40.0).toDouble(),
      minAccelForJerk:
          (json['min_accel_for_jerk'] ?? 2.5).toDouble(), // 约 0.25G
      version: (json['version'] ?? 0).toInt(),
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
      'max_jerk_allowed': maxJerkAllowed,
      'max_accel_allowed': maxAccelAllowed,
      'max_wobble_span_allowed': maxWobbleSpanAllowed,
      'max_bump_allowed': maxBumpAllowed,
      'min_accel_for_jerk': minAccelForJerk,
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
    double? maxJerkAllowed,
    double? maxAccelAllowed,
    double? maxWobbleSpanAllowed,
    double? maxBumpAllowed,
    double? minAccelForJerk,
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
      maxJerkAllowed: maxJerkAllowed ?? this.maxJerkAllowed,
      maxAccelAllowed: maxAccelAllowed ?? this.maxAccelAllowed,
      maxWobbleSpanAllowed: maxWobbleSpanAllowed ?? this.maxWobbleSpanAllowed,
      maxBumpAllowed: maxBumpAllowed ?? this.maxBumpAllowed,
      minAccelForJerk: minAccelForJerk ?? this.minAccelForJerk,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      id: id ?? this.id,
    );
  }

  /// 默认配置 (2.1.5 物理边界版)
  factory AlgorithmConfig.defaultConfig() {
    return AlgorithmConfig(
      thresholdAccel: 2.2,
      thresholdDecel: -2.0,
      thresholdWobbleSpan: 2.5,
      thresholdBump: 5.5,
      thresholdJerk: 6.0,
      thresholdPitch: 1.5,
      jerkWindowMs: 250,
      accelDecelWindowMs: 600,
      wobbleWindowMs: 1000,
      fusionWindowMs: 3000,
      zyInterferenceThreshold: 1.5,
      zxInterferenceThreshold: 2.0,
      pitchValidationEnabled: true,
      speedLowFactor: 1.1,
      speedHighFactor: 0.9,
      maxJerkAllowed: 50.0,
      maxAccelAllowed: 20.0,
      maxWobbleSpanAllowed: 20.0,
      maxBumpAllowed: 40.0,
      minAccelForJerk: 2.5,
      version: 0,
      updatedAt: '2026-01-08T00:00:00Z',
    );
  }
}
