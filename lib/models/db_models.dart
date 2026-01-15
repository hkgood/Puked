import 'dart:convert';
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

  // 云端关联 ID (PocketBase Record ID)
  String? brand_ref;
  String? software_version_ref;

  String? appVersion;
  String? platform;
  String? algorithm;
  String? notes;
  String? metricsJson; // 新增：专门存储计算后的统计信息 (JSON)

  @ignore
  String? userName;

  @ignore
  String? userId;

  @ignore
  String? userAvatar;

  // 云端关联 ID (PocketBase Record ID)
  String? cloudId;

  // 是否已上传
  bool isUploaded = false;

  // 是否仅存在于云端（本地数据缺失）
  bool isLocalMissing = false;

  // 轨迹点列表
  final trajectory = IsarLinks<TrajectoryPoint>();

  // 关联的事件列表
  final events = IsarLinks<RecordedEvent>();

  // 统计信息
  int eventCount = 0;
  double distance = 0.0;

  /// 优先从 metricsJson 中解析，兼容老的 notes 解析逻辑
  @ignore
  Map<String, dynamic>? get cloudMetrics {
    // 1. 优先读取专门的字段
    if (metricsJson != null && metricsJson!.startsWith('{')) {
      try {
        final decoded = jsonDecode(metricsJson!);
        return (decoded['metrics'] ?? decoded) as Map<String, dynamic>?;
      } catch (_) {}
    }

    // 2. 兼容老版本存储在 notes 里的逻辑
    if (notes != null && notes!.startsWith('{')) {
      try {
        final decoded = jsonDecode(notes!);
        return decoded['metrics'] as Map<String, dynamic>?;
      } catch (_) {}
    }
    return null;
  }

  /// 获取平均车速的显示文本
  String getAvgSpeedDisplay(String fallback) {
    final metrics = cloudMetrics;
    if (metrics != null && metrics.containsKey('avg_speed_kmh')) {
      final val = metrics['avg_speed_kmh'].toString();
      return "$val km/h";
    }
    
    if (endTime != null && distance > 0) {
      final durationSeconds = endTime!.difference(startTime).inSeconds.abs();
      if (durationSeconds > 0) {
        final speed = (distance / 1000) / (durationSeconds / 3600);
        return "${speed.toStringAsFixed(1)} km/h";
      }
    }
    return fallback;
  }

  /// 获取时长的显示文本
  String getDurationDisplay(String unit, String fallback) {
    final metrics = cloudMetrics;
    if (metrics != null && metrics.containsKey('duration_min')) {
      return "${metrics['duration_min']} $unit";
    }

    if (endTime != null) {
      return "${endTime!.difference(startTime).inMinutes.abs()} $unit";
    }
    return fallback;
  }

  /// 获取距离的显示文本
  String getDistanceDisplay() {
    final metrics = cloudMetrics;
    if (metrics != null && metrics.containsKey('distance_km')) {
      final val = metrics['distance_km'].toString();
      return "$val km";
    }
    return "${(distance / 1000).toStringAsFixed(2)} km";
  }

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

  /// 辅助方法：生成用于本地或云端的 metrics Map
  Map<String, dynamic> generateMetrics() {
    final durationMin = endTime != null ? endTime!.difference(startTime).inMinutes : 0;
    final durationSec = endTime != null ? endTime!.difference(startTime).inSeconds : 1;
    final avgSpeedKmh = (endTime != null && distance > 0)
        ? (distance / 1000 / (durationSec / 3600)).toStringAsFixed(1)
        : "0.0";

    return {
      "distance_km": (distance / 1000).toStringAsFixed(2),
      "event_count": eventCount,
      "duration_min": durationMin,
      "avg_speed_kmh": avgSpeedKmh,
    };
  }
}

@collection
class Brand {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name; // 品牌标识，如 "Tesla"

  String? cloudId; // PocketBase Record ID
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

  String? cloudId; // PocketBase Record ID

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
  double? speed; // 新增：记录触发时的融合车速 (m/s)
  double? gForce; // 新增：记录触发时的 G 值

  // 存储传感器波形片段
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
