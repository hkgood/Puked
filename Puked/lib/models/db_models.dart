import 'dart:convert';
import 'package:isar/isar.dart';

// ignore: uri_does_not_exist
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

  String? brand_ref;
  String? software_version_ref;

  String? appVersion;
  String? platform;
  String? algorithm;
  String? notes;
  String? metricsJson;

  // 新增：支持旧代码中的 metrics 字段名（如果它是 metricsJson 的别名）
  String? get metrics => metricsJson;
  set metrics(String? value) => metricsJson = value;

  // 新增：支持云端统计信息
  String? cloudMetrics;

  // 新增：本地事件统计缓存（JSON格式）
  String? eventStatsJson;

  @ignore
  String? userName;
  @ignore
  String? userId;
  @ignore
  String? userAvatar;

  String? cloudId;
  bool isUploaded = false;
  bool isLocalMissing = false;

  final trajectory = IsarLinks<TrajectoryPoint>();
  final events = IsarLinks<RecordedEvent>();

  double distance = 0.0;
  int eventCount = 0; // 自动事件数量（自动标记的负体验事件）

  // 辅助方法：解析事件统计
  @ignore
  Map<String, dynamic>? get eventStats {
    if (eventStatsJson == null || eventStatsJson!.isEmpty) return null;
    try {
      return jsonDecode(eventStatsJson!) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // 业务逻辑辅助方法
  bool get isDataSufficient => distance > 0.3; // 示例：大于 300 米认为数据充足

  // 获取显示用的公里数（优先使用云端metrics，回退到本地distance）
  double get displayDistance {
    // 1. 优先使用 cloudMetrics 中的 distance_km（最新的云端数据）
    if (cloudMetrics != null && cloudMetrics!.isNotEmpty) {
      try {
        final metrics = jsonDecode(cloudMetrics!) as Map<String, dynamic>;
        final distanceKm =
            double.tryParse(metrics['distance_km']?.toString() ?? '0');
        if (distanceKm != null && distanceKm > 0) {
          return distanceKm;
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 2. 回退到 metricsJson 中的 distance_km（上传时服务器返回的）
    if (metricsJson != null && metricsJson!.isNotEmpty) {
      try {
        final metrics = jsonDecode(metricsJson!) as Map<String, dynamic>;
        final distanceKm =
            double.tryParse(metrics['distance_km']?.toString() ?? '0');
        if (distanceKm != null && distanceKm > 0) {
          return distanceKm;
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 3. 最后回退到本地计算的 distance（存储单位是米，需要转换为公里）
    return distance / 1000;
  }

  String getDistanceDisplay() => "${displayDistance.toStringAsFixed(1)} km";

  String getAvgSpeedDisplay() {
    // 1. 优先使用 cloudMetrics 中的 avg_speed_kmh
    if (cloudMetrics != null && cloudMetrics!.isNotEmpty) {
      try {
        final metrics = jsonDecode(cloudMetrics!) as Map<String, dynamic>;
        final avgSpeed = metrics['avg_speed_kmh'];
        if (avgSpeed != null) {
          final speed = double.tryParse(avgSpeed.toString());
          if (speed != null && speed > 0) {
            return "${speed.toStringAsFixed(1)} km/h";
          }
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 2. 回退到 metricsJson 中的 avg_speed_kmh
    if (metricsJson != null && metricsJson!.isNotEmpty) {
      try {
        final metrics = jsonDecode(metricsJson!) as Map<String, dynamic>;
        final avgSpeed = metrics['avg_speed_kmh'];
        if (avgSpeed != null) {
          final speed = double.tryParse(avgSpeed.toString());
          if (speed != null && speed > 0) {
            return "${speed.toStringAsFixed(1)} km/h";
          }
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 3. 最后回退到基于 endTime 的本地计算
    if (endTime == null) return "0 km/h";
    final hours = endTime!.difference(startTime).inSeconds / 3600.0;
    return hours > 0
        ? "${(displayDistance / hours).toStringAsFixed(1)} km/h"
        : "0 km/h";
  }

  String getDurationDisplay() {
    // 1. 优先使用 cloudMetrics 中的 duration_min
    if (cloudMetrics != null && cloudMetrics!.isNotEmpty) {
      try {
        final metrics = jsonDecode(cloudMetrics!) as Map<String, dynamic>;
        final durationMin = metrics['duration_min'];
        if (durationMin != null) {
          final duration = int.tryParse(durationMin.toString());
          if (duration != null && duration > 0) {
            return "$duration min";
          }
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 2. 回退到 metricsJson 中的 duration_min
    if (metricsJson != null && metricsJson!.isNotEmpty) {
      try {
        final metrics = jsonDecode(metricsJson!) as Map<String, dynamic>;
        final durationMin = metrics['duration_min'];
        if (durationMin != null) {
          final duration = int.tryParse(durationMin.toString());
          if (duration != null && duration > 0) {
            return "$duration min";
          }
        }
      } catch (e) {
        // 解析失败，继续尝试其他来源
      }
    }

    // 3. 最后回退到基于 endTime 的本地计算
    if (endTime == null) return "0 min";
    return "${endTime!.difference(startTime).inMinutes} min";
  }
}

@collection
class TrajectoryPoint {
  Id id = Isar.autoIncrement;
  late double lat;
  late double lng;
  late double altitude;
  late double speed;
  late DateTime timestamp;
  bool isLowConfidence = false;

  // 传感器同步记录（可选，用于数据导出）
  double? ax, ay, az;
  double? gx, gy, gz;
}

@collection
class RecordedEvent {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  late DateTime timestamp;
  late String type;
  String? source;
  double? speed;
  double? gForce;
  String? notes;
  String? voiceText;

  double? lat;
  double? lng;

  late List<SensorPointEmbedded> sensorData;
}

@embedded
class SensorPointEmbedded {
  double? ax, ay, az;
  double? gx, gy, gz;
  double? mx, my, mz;
  int? offsetMs;
}

@collection
class Brand {
  Id id = Isar.autoIncrement;
  late String name;
  String? displayName;
  String? logoUrl;
  int order = 0;
  bool isEnabled = true;
  bool isCustom = false;
  DateTime? updatedAt;
  String? cloudId;

  final versions = IsarLinks<SoftwareVersion>();
}

@collection
class SoftwareVersion {
  Id id = Isar.autoIncrement;
  late String versionString;
  bool isEnabled = true;
  String? cloudId;
  bool isCustom = false;

  final brand = IsarLink<Brand>();
}
