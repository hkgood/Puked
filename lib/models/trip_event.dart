import 'sensor_data.dart';

enum EventType {
  rapidAcceleration,
  rapidDeceleration,
  bump,
  wobble,
  jerk, // 顿挫（含点刹、起步突踩、停车点头）
  manual, // 用户手动标记
  proDisengagement, // 接管：安全接管、走错路、卡死、绿灯不走
  proViolation, // 违章：压实线、走错车道、闯红灯
  proExperience, // 体验：误刹车、画龙、过快/过慢、轨迹不自然
}

class TripEvent {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final String source; // "AUTO" or "MANUAL"
  final double? latitude;
  final double? longitude;
  final double? speed; // 新增：记录触发时的融合车速 (m/s)
  final String? voiceText; // 新增：语音转文本信息

  // 核心回溯数据片段 (30Hz)
  final List<SensorData> sensorFragment;

  TripEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.source,
    this.latitude,
    this.longitude,
    this.speed,
    this.voiceText,
    required this.sensorFragment,
  });

  Map<String, dynamic> toJson() => {
        'event_id': id,
        'timestamp': timestamp.millisecondsSinceEpoch / 1000.0,
        'type': type.name,
        'source': source,
        'voice_text': voiceText,
        'location': {
          'lat': latitude,
          'lng': longitude,
          'speed': speed, // 确保导出的 JSON 包含速度
        },
        'sensor_fragment': {
          'sampling_rate': '30Hz',
          'data': sensorFragment.map((e) => e.toJson()).toList(),
        },
      };
}
