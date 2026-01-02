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

  // 是否已上传
  bool isUploaded = false;

  // 轨迹点列表
  final trajectory = IsarLinks<TrajectoryPoint>();

  // 关联的事件列表
  final events = IsarLinks<RecordedEvent>();

  // 统计信息
  int eventCount = 0;
  double distance = 0.0;

  /// 检查行程数据是否充足
  /// 1. 里程 >= 500m
  /// 2. 时长 >= 120s (2分钟)
  /// 3. 平均速度 >= 2.0 km/h
  bool get isDataSufficient {
    // 1. 距离检查
    if (distance < 500) return false;

    // 2. 时长检查
    if (endTime == null) return true; // 如果还没结束，暂不判断时长（理论上上传前已结束）
    final durationSeconds = endTime!.difference(startTime).inSeconds;
    if (durationSeconds < 120) return false;

    // 3. 平均车速检查 (km/h)
    // 速度 = (距离/1000) / (时长/3600) = (距离 * 3.6) / 时长
    final avgSpeedKmh = (distance * 3.6) / durationSeconds;
    if (avgSpeedKmh < 2.0) return false;

    return true;
  }
}

@collection
class Brand {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name; // 品牌标识，如 "Tesla"

  String? displayName; // 显示名称
  String? logoUrl; // 远程 SVG 图标地址

  int order = 0; // 排序权重
  bool isEnabled = true; // 是否启用
  bool isCustom = false; // 是否为自定义

  DateTime? updatedAt; // 最后更新时间

  // 关联的版本
  @Backlink(to: 'brand')
  final versions = IsarLinks<SoftwareVersion>();
}

@collection
class SoftwareVersion {
  Id id = Isar.autoIncrement;

  @Index()
  late String versionString; // 版本号，如 "v12.3.6"

  final brand = IsarLink<Brand>(); // 属于哪个品牌

  bool isEnabled = true;
  bool isCustom = false;

  DateTime? updatedAt;
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
  String? notes; // 备注信息（如聚合特征）

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
