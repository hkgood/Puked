import 'package:isar/isar.dart';

part 'db_models.g.dart';

@collection
class Trip {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late DateTime startTime;
  DateTime? endTime;

  String? carModel;
  String? brand;
  String? softwareVersion;
  String? notes;

  // 云端关联 ID (PocketBase Record ID)
  String? cloudId;

  // 轨迹点列表
  final trajectory = IsarLinks<TrajectoryPoint>();

  // 关联的事件列表
  final events = IsarLinks<RecordedEvent>();

  // 统计信息
  int eventCount = 0;
  double distance = 0.0;
}

@collection
class TrajectoryPoint {
  Id id = Isar.autoIncrement;

  late double lat;
  late double lng;
  late double altitude;
  late double speed;
  late DateTime timestamp;
  bool? isLowConfidence; // 是否为弱信号点
}

@collection
class RecordedEvent {
  Id id = Isar.autoIncrement;

  late String uuid;
  late DateTime timestamp;
  late String type; // rapidAcceleration, rapidDeceleration, etc.
  late String source; // AUTO, MANUAL

  double? lat;
  double? lng;

  // 存储传感器波形片段，由于 Isar 不直接支持自定义对象列表的嵌套存储，
  // 我们将传感器数据序列化为 JSON 字符串存储，或者使用嵌入式类。
  // 为了性能，我们这里使用 List<SensorPointEmbedded>。
  late List<SensorPointEmbedded> sensorData;
}

@embedded
class SensorPointEmbedded {
  double? ax;
  double? ay;
  double? az;
  double? gx;
  double? gy;
  double? gz;
  double? mx;
  double? my;
  double? mz;
  int? offsetMs;
}
