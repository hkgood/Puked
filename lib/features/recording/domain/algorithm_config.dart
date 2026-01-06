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
  final bool pitchValidationEnabled;

  final double speedLowFactor;
  final double speedHighFactor;

  final int version;
  final String updatedAt;

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
    required this.pitchValidationEnabled,
    required this.speedLowFactor,
    required this.speedHighFactor,
    required this.version,
    required this.updatedAt,
  });

  factory AlgorithmConfig.fromJson(Map<String, dynamic> json) {
    return AlgorithmConfig(
      thresholdAccel: (json['threshold_accel'] ?? 2.2).toDouble(),
      thresholdDecel: (json['threshold_decel'] ?? -2.0).toDouble(),
      thresholdWobbleSpan: (json['threshold_wobble_span'] ?? 2.0).toDouble(),
      thresholdBump: (json['threshold_bump'] ?? 5.5).toDouble(),
      thresholdJerk: (json['threshold_jerk'] ?? 5.5).toDouble(),
      thresholdPitch: (json['threshold_pitch'] ?? 1.5).toDouble(),
      jerkWindowMs: json['jerk_window_ms'] ?? 250,
      accelDecelWindowMs: json['accel_decel_window_ms'] ?? 600,
      wobbleWindowMs: json['wobble_window_ms'] ?? 1000,
      fusionWindowMs: json['fusion_window_ms'] ?? 3000,
      zyInterferenceThreshold:
          (json['zy_interference_threshold'] ?? 3.0).toDouble(),
      pitchValidationEnabled: json['pitch_validation_enabled'] ?? true,
      speedLowFactor: (json['speed_low_factor'] ?? 1.1).toDouble(),
      speedHighFactor: (json['speed_high_factor'] ?? 0.9).toDouble(),
      version: json['version'] ?? 1,
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
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
      'pitch_validation_enabled': pitchValidationEnabled,
      'speed_low_factor': speedLowFactor,
      'speed_high_factor': speedHighFactor,
      'version': version,
      'updatedAt': updatedAt,
    };
  }

  /// 默认配置 (2.1.3 基础版本)
  factory AlgorithmConfig.defaultConfig() {
    return AlgorithmConfig(
      thresholdAccel: 2.2,
      thresholdDecel: -2.0,
      thresholdWobbleSpan: 2.0,
      thresholdBump: 5.5,
      thresholdJerk: 5.5,
      thresholdPitch: 1.5,
      jerkWindowMs: 250,
      accelDecelWindowMs: 600,
      wobbleWindowMs: 1000,
      fusionWindowMs: 3000,
      zyInterferenceThreshold: 3.0,
      pitchValidationEnabled: true,
      speedLowFactor: 1.1,
      speedHighFactor: 0.9,
      version: 0,
      updatedAt: '2026-01-07T00:00:00Z',
    );
  }
}
