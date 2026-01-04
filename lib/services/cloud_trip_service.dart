import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/pocketbase_service.dart';

final cloudTripServiceProvider = Provider((ref) {
  final pbService = ref.watch(pbServiceProvider);
  return CloudTripService(pbService);
});

class CloudTripService {
  final PocketBaseService _pbService;

  CloudTripService(this._pbService);

  /// 上传行程到 PocketBase
  /// 返回上传后的 Record ID
  Future<String> uploadTrip(Trip trip) async {
    if (!_pbService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // 确保轨迹和事件数据已加载 (IsarLinks 需要 load)
    if (!trip.trajectory.isLoaded) await trip.trajectory.load();
    if (!trip.events.isLoaded) await trip.events.load();

    final userId = _pbService.currentUserId;
    if (userId == null) throw Exception('User ID not found');

    // 1. 准备行程数据 JSON (导出逻辑复用)
    final exportData = _buildTripExportData(trip);
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // 2. 写入临时文件用于上传
    final directory = await getTemporaryDirectory();
    final fileName = 'Trip_${trip.uuid.substring(0, 8)}.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);

    // 3. 构建 metrics 和 route_summary
    final metrics = {
      "distance_km": (trip.distance / 1000).toStringAsFixed(2),
      "event_count": trip.eventCount,
      "event_breakdown": _buildEventBreakdown(trip),
      "duration_min": trip.endTime != null
          ? trip.endTime!.difference(trip.startTime).inMinutes
          : 0,
      "avg_speed_kmh": (trip.endTime != null && trip.distance > 0)
          ? (trip.distance /
                  1000 /
                  (trip.endTime!.difference(trip.startTime).inSeconds / 3600))
              .toStringAsFixed(1)
          : "0.0",
    };

    // 4. 上传到 PocketBase 'trips' 集合
    try {
      final record = await _pbService.pb.collection('trips').create(
        body: {
          'user': userId,
          'brand': trip.brand ?? 'Unknown',
          'car_model': trip.carModel ?? 'Unknown',
          'software_version': trip.softwareVersion ?? 'Unknown',
          'is_public': true,
          'metrics': metrics,
          'route_summary': {}, // 如果有聚合路径可以放在这里
          'share_slug': trip.uuid.substring(0, 8),
          'local_uuid': trip.uuid,
        },
        files: [
          await http.MultipartFile.fromPath(
            'raw_log_file',
            file.path,
            filename: fileName,
          ),
        ],
      );
      return record.id;
    } catch (e) {
      debugPrint('Upload failed: $e');
      rethrow;
    } finally {
      // 清理临时文件
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 获取云端所有已上传行程的 local_uuid 列表
  Future<List<String>> getUploadedLocalUuids() async {
    if (!_pbService.isAuthenticated) return [];

    try {
      final records = await _pbService.pb.collection('trips').getFullList(
            fields: 'local_uuid',
          );
      return records
          .map((r) => r.getStringValue('local_uuid'))
          .where((uuid) => uuid.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error fetching cloud UUIDs: $e');
      return [];
    }
  }

  /// 从云端抓取所有公开的行程数据，用于 Arena 展示
  Future<List<Trip>> fetchPublicTrips() async {
    try {
      final records = await _pbService.pb.collection('trips').getFullList(
            filter: 'is_public = true',
            sort: '-created',
          );

      return records.map((r) {
        final metrics = r.get<Map<String, dynamic>>('metrics');
        final distanceKm =
            double.tryParse(metrics['distance_km']?.toString() ?? '0') ?? 0;
        final eventCount = metrics['event_count'] as int? ?? 0;

        // 重构一个用于展示的 Trip 对象
        final trip = Trip()
          ..uuid = r.getStringValue('local_uuid')
          ..brand = r.getStringValue('brand')
          ..carModel = r.getStringValue('car_model')
          ..softwareVersion = r.getStringValue('software_version')
          ..distance = distanceKm * 1000 // 转回米
          ..eventCount = eventCount
          ..startTime = DateTime.parse(r.get<String>('created'))
          ..cloudId = r.id;

        // 这里有个难点：RecordedEvent 是 Isar 集合，不能直接在内存中构建并关联。
        // 我们在 ArenaService 中需要修改逻辑，使其支持这种从 metrics 中读取的 breakdown。
        // 为了兼容现有代码，我们可以通过一种“技巧”：在内存中模拟事件，或者扩展 Trip 对象。
        // 但最稳妥的是修改 ArenaService。

        // 暂时我们将整个 metrics 存在 notes 字段里，作为一个临时方案
        trip.notes = jsonEncode({'metrics': metrics});

        return trip;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching public trips: $e');
      return [];
    }
  }

  Map<String, int> _buildEventBreakdown(Trip trip) {
    final Map<String, int> breakdown = {
      'rapidAcceleration': 0,
      'rapidDeceleration': 0,
      'jerk': 0,
      'bump': 0,
      'wobble': 0,
    };
    for (final event in trip.events) {
      if (breakdown.containsKey(event.type)) {
        breakdown[event.type] = (breakdown[event.type] ?? 0) + 1;
      }
    }
    return breakdown;
  }

  /// 构建导出的 Map 数据 (逻辑来源于 ExportService)
  Map<String, dynamic> _buildTripExportData(Trip trip) {
    return {
      "version": "1.0.0",
      "trip_id": trip.uuid,
      "metadata": {
        "start_time": trip.startTime.toIso8601String(),
        "end_time": trip.endTime?.toIso8601String(),
        "car_model": trip.carModel ?? "Unknown",
        "app_version": trip.appVersion ?? "Unknown",
        "platform": trip.platform ?? "Unknown",
        "algorithm": trip.algorithm ?? "Unknown",
        "notes": trip.notes ?? "",
        "event_count": trip.eventCount,
      },
      "trajectory": trip.trajectory
          .map((p) => {
                "ts": p.timestamp.millisecondsSinceEpoch / 1000.0,
                "lat": p.lat,
                "lng": p.lng,
                "speed": p.speed,
                "low_conf": p.isLowConfidence ?? false,
              })
          .toList(),
      "events": trip.events
          .map((e) => {
                "event_id": e.uuid,
                "timestamp": e.timestamp.millisecondsSinceEpoch / 1000.0,
                "type": e.type,
                "source": e.source,
                "location": {"lat": e.lat, "lng": e.lng},
                "sensor_fragment": {
                  "sampling_rate": "30Hz",
                  "data": e.sensorData
                      .map((s) => {
                            "offset_ms": s.offsetMs,
                            "accel": {"x": s.ax, "y": s.ay, "z": s.az},
                            "gyro": {"x": s.gx, "y": s.gy, "z": s.gz},
                            "mag": {"x": s.mx, "y": s.my, "z": s.mz},
                          })
                      .toList(),
                }
              })
          .toList(),
    };
  }
}
