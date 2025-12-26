import 'sensor_data.dart';

enum EventType {
  rapidAcceleration,
  rapidDeceleration,
  bump,
  wobble,
  jerk, // 顿挫（含点刹、起步突踩、停车点头）
  manual, // 用户手动标记
}

class TripEvent {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final String source; // "AUTO" or "MANUAL"
  final double? latitude;
  final double? longitude;

  // 核心回溯数据片段 (30Hz)
  final List<SensorData> sensorFragment;

  TripEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.source,
    this.latitude,
    this.longitude,
    required this.sensorFragment,
  });

  Map<String, dynamic> toJson() => {
        'event_id': id,
        'timestamp': timestamp.millisecondsSinceEpoch / 1000.0,
        'type': type.name,
        'source': source,
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
        'sensor_fragment': {
          'sampling_rate': '30Hz',
          'data': sensorFragment.map((e) => e.toJson()).toList(),
        },
      };
}
