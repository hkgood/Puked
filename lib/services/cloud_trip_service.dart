import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
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
  /// 返回上传后的 Record ID 和 metrics
  Future<Map<String, dynamic>> uploadTrip(Trip trip) async {
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
      "start_time": trip.startTime.toUtc().toIso8601String(), // 增加时间戳对齐
    };

    // 4. 上传到 PocketBase 'trips' 集合
    try {
      final record = await _pbService.pb.collection('trips').create(
        body: {
          'user': userId,
          'brand': trip.brand ?? 'Others',
          'brand_ref': trip.brand_ref ?? '',
          'car_model': trip.carModel ?? 'Others',
          'software_version': trip.softwareVersion ?? 'Others',
          'software_version_ref': trip.software_version_ref ?? '',
          'is_public': true,
          'metrics': metrics,
          'route_summary': {}, // 如果有聚合路径可以放在这里
          'share_slug': trip.uuid.substring(0, 8),
          'local_uuid': trip.uuid,
          'start_time': trip.startTime.toUtc().toIso8601String(),
        },
        files: [
          await http.MultipartFile.fromPath(
            'raw_log_file',
            file.path,
            filename: fileName,
          ),
        ],
      );
      return {
        'id': record.id,
        'metrics': metrics,
      };
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

  /// 获取当前用户云端所有的行程记录（包含元数据）
  Future<List<RecordModel>> fetchUserCloudTrips() async {
    final userId = _pbService.currentUserId;
    if (!_pbService.isAuthenticated || userId == null) return [];
    try {
      return await _pbService.pb.collection('trips').getFullList(
            filter: 'user = "$userId"', // 关键：只拉取当前用户的行程
            sort: '-created',
          );
    } catch (e) {
      debugPrint('Error fetching user cloud trips: $e');
      return [];
    }
  }

  /// 执行双向同步：
  /// 1. 发现本地缺失的云端行程，创建占位符
  /// 2. 更新本地行程的上传状态
  Future<int> syncCloudToLocal(dynamic storage) async {
    final userId = _pbService.currentUserId;
    final isAuth = _pbService.isAuthenticated;
    
    if (!isAuth || userId == null) {
      debugPrint('[PukedSync] Skip sync: isAuth=$isAuth, userId=$userId');
      return 0;
    }

    try {
      debugPrint('[PukedSync] Starting sync for user: $userId');
      final cloudRecords = await fetchUserCloudTrips();
      debugPrint('[PukedSync] Cloud returned ${cloudRecords.length} records');
      
      int newPlaceholders = 0;
      int updatedCount = 0;

      for (final record in cloudRecords) {
        final uuid = record.getStringValue('local_uuid');
        if (uuid.isEmpty) {
          debugPrint('[PukedSync] Warning: Cloud record ${record.id} has no local_uuid');
          continue;
        }

        final localTrip = await storage.getTripByUuid(uuid);
        if (localTrip == null) {
          debugPrint('[PukedSync] Creating placeholder for missing trip: $uuid');
          
          final metricsRaw = record.get('metrics');
          final Map<String, dynamic> metrics = metricsRaw is Map<String, dynamic> 
              ? metricsRaw 
              : {};
          
          final distanceKm = double.tryParse(metrics['distance_km']?.toString() ?? '0') ?? 0;
          final eventCount = metrics['event_count'] as int? ?? 0;

          // 核心修复：将云端完整的 metrics 序列化存入专门的 metricsJson 字段
          final String metricsJson = jsonEncode(metrics);

            final placeholder = Trip()
              ..uuid = uuid
              ..cloudId = record.id
              // 关键修复：使用业务上的 start_time 字段
              ..startTime = DateTime.parse(record.getStringValue('start_time').isNotEmpty 
                  ? record.getStringValue('start_time') 
                  : record.get<String>('created')).toLocal()
              ..brand = record.getStringValue('brand')
              ..brand_ref = record.getStringValue('brand_ref')
              ..carModel = record.getStringValue('car_model')
              ..softwareVersion = record.getStringValue('software_version')
              ..software_version_ref =
                  record.getStringValue('software_version_ref')
              ..distance = distanceKm * 1000
              ..eventCount = eventCount
              ..isUploaded = true
              ..isLocalMissing = true // 核心修复：显式标记为本地缺失详情
              ..metricsJson = metricsJson;

          await storage.savePlaceholderTrip(placeholder);
          newPlaceholders++;
        } else {
          // 本地有，同步更新状态
          if (!localTrip.isUploaded || localTrip.cloudId != record.id || localTrip.metricsJson == null) {
            final metricsRaw = record.get('metrics');
            final Map<String, dynamic> metrics = metricsRaw is Map<String, dynamic> 
                ? metricsRaw 
                : {};
            await storage.updateTripCloudId(localTrip.id, record.id, metrics: metrics);
            updatedCount++;
          }
        }
      }
      debugPrint('[PukedSync] Sync completed. New: $newPlaceholders, Updated: $updatedCount');
      return newPlaceholders;
    } catch (e) {
      debugPrint('[PukedSync] Sync cloud to local failed: $e');
      return 0;
    }
  }

  /// 下载行程的原始日志文件并解析
  Future<Map<String, dynamic>?> downloadTripData(
      String recordId, String fileName) async {
    if (!_pbService.isAuthenticated) return null;

    try {
      final url = _pbService.pb.files.getUrl(
        RecordModel({
          'id': recordId,
          'collectionId': 'trips',
          'collectionName': 'trips'
        }),
        fileName,
      );

      // 关键修复：PocketBase 文件访问如果不是 Public，必须在 Header 中带上 Token
      // 并且在 PocketBase 中，Token 通常不需要 Bearer 前缀，但为了保险我们做个判定
      final String token = _pbService.pb.authStore.token;
      debugPrint('[PukedSync] Starting download from URL: $url');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': token,
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        debugPrint(
            '[PukedSync] Download success. Size: ${bytes.length} bytes');

        Map<String, dynamic> data;
        // 优化：针对小文件 (< 100KB) 直接在主线程解析，避免 compute (Isolate) 的启动和通信开销
        if (bytes.length < 100 * 1024) {
          debugPrint('[PukedSync] Small file detected, parsing on main thread...');
          data = _parseJson(bytes);
        } else {
          debugPrint('[PukedSync] Large file detected, starting JSON parse (compute)...');
          data = await compute(_parseJson, bytes);
        }
        
        debugPrint('[PukedSync] JSON parse returned ${data.length} keys');

        debugPrint(
            '[PukedSync] JSON parse complete. Root keys: ${data.keys.toList()}');
        return data;
      } else {
        debugPrint(
            '[PukedSync] Download failed. HTTP Status: ${response.statusCode}');
        debugPrint('[PukedSync] Response Body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PukedSync] Error downloading trip data: $e');
      return null;
    }
  }

  /// 从云端抓取公开行程的总数，用于判断是否需要刷新
  Future<int> getTotalPublicTripsCount() async {
    try {
      final result = await _pbService.pb.collection('trips').getList(
            page: 1,
            perPage: 1,
            filter: 'is_public = true',
            fields: 'id', // 只返回 id 减少数据量
          );
      return result.totalItems;
    } catch (e) {
      debugPrint('Error fetching public trips count: $e');
      return -1;
    }
  }

  /// 获取 Arena 聚合统计数据 (从新的 trip_stats_summary 数据源)
  Future<Map<String, dynamic>> fetchArenaStats() async {
    try {
      // 1. 并行获取所有汇总数据和周榜数据 (对齐 Web 端)
      // 移除 fields 限制，确保 expand 数据完整返回
      final results = await Future.wait([
        _pbService.pb.collection('trip_stats_summary').getFullList(
              filter: 'period_type="all"',
              expand: 'brand,software_version,user',
              sort: '-total_distance',
            ),
        _pbService.pb.collection('trip_stats_summary').getFullList(
              filter: 'period_type="weekly"',
              expand: 'user',
              sort: '-total_distance',
            ),
      ]);

      return {
        'all_summary': results[0],
        'weekly_summary': results[1],
      };
    } catch (e) {
      debugPrint('Error fetching arena stats from summary table: $e');
      return {};
    }
  }

  /// 获取特定用户的统计数据
  Future<Map<String, dynamic>?> fetchUserStats(String userId) async {
    try {
      final record = await _pbService.pb
          .collection('user_stats')
          .getFirstListItem('user_id = "$userId"');
      return record.get('payload');
    } catch (e) {
      debugPrint('Error fetching user stats for $userId: $e');
      return null;
    }
  }

  /// 触发云端同步逻辑 (对齐 Web 端路由)
  Future<bool> triggerArenaSync() async {
    try {
      // 注意：Web 端调用的是 /api/custom/sync-stats (GET)
      // 这里根据实际后端配置调整，通常移动端也会调用同样的自定义接口
      await _pbService.pb.send('/api/custom/sync-stats', method: 'GET');
      return true;
    } catch (e) {
      debugPrint('Error triggering arena sync: $e');
      return false;
    }
  }

  // 辅助方法：在后台线程解析 JSON
  static Map<String, dynamic> _parseJson(Uint8List bytes) {
    try {
      final decodedString = utf8.decode(bytes);
      final dynamic decodedJson = jsonDecode(decodedString);
      if (decodedJson is! Map<String, dynamic>) {
        throw Exception('JSON is not a Map: ${decodedJson.runtimeType}');
      }
      return decodedJson;
    } catch (e) {
      debugPrint('[PukedSync] CRITICAL: JSON parse error in Isolate: $e');
      rethrow;
    }
  }

  /// 从云端抓取所有公开的行程数据，用于 Arena 展示
  Future<List<Trip>> fetchPublicTrips() async {
    try {
      final records = await _pbService.pb.collection('trips').getFullList(
            filter: 'is_public = true',
            sort: '-created',
            expand: 'user,owner', // 尝试同时展开 user 和 owner 字段
          );

      return records.map((r) {
        final metrics = r.get<Map<String, dynamic>>('metrics');
        final distanceKm =
            double.tryParse(metrics['distance_km']?.toString() ?? '0') ?? 0;
        final eventCount = metrics['event_count'] as int? ?? 0;

        // 获取用户信息
        String? userName;
        String? userAvatar;
        String? userId = r.getStringValue('user');

        // 优先尝试直接访问 expand['user']，这是最标准的方式
        final expandedUsers = r.get<List<RecordModel>?>('expand.user');
        if (expandedUsers != null && expandedUsers.isNotEmpty) {
          final userRecord = expandedUsers.first;
          userId = userRecord.id;

          final name = userRecord.get<String>('name');
          final username = userRecord.get<String>('username');
          final avatar = userRecord.get<String>('avatar');

          if (name.isNotEmpty) {
            userName = name;
          } else if (username.isNotEmpty) {
            userName = username;
          }

          if (avatar.isNotEmpty) {
            userAvatar =
                _pbService.pb.files.getUrl(userRecord, avatar).toString();
          }
        } else {
          // 备用方案：如果 expand['user'] 为空，递归扫描所有 expand 入口
          final expand = r.get<Map<String, List<RecordModel>>?>('expand');
          if (expand != null) {
            for (final entry in expand.entries) {
              for (final record in entry.value) {
                final n = record.get<String>('name');
                final un = record.get<String>('username');
                final av = record.get<String>('avatar');
                if (n.isNotEmpty || un.isNotEmpty) {
                  userId = record.id;
                  userName = n.isNotEmpty ? n : un;
                  if (av.isNotEmpty) {
                    userAvatar =
                        _pbService.pb.files.getUrl(record, av).toString();
                  }
                  break;
                }
              }
              if (userName != null) break;
            }
          }
        }

        // 重构一个用于展示的 Trip 对象
        final trip = Trip()
          ..uuid = r.getStringValue('local_uuid')
          ..brand = r.getStringValue('brand')
          ..brand_ref = r.getStringValue('brand_ref')
          ..carModel = r.getStringValue('car_model')
          ..softwareVersion = r.getStringValue('software_version')
          ..software_version_ref = r.getStringValue('software_version_ref')
          ..distance = distanceKm * 1000 // 转回米
          ..eventCount = eventCount
          ..startTime = DateTime.parse(r.get<String>('created'))
          ..cloudId = r.id
          ..userName = userName
          ..userAvatar = userAvatar
          ..userId = userId;

        // 这里有个难点：RecordedEvent 是 Isar 集合，不能直接在内存中构建并关联。
        // 我们在 ArenaService 中需要修改逻辑，使其支持这种从 metrics 中读取的 breakdown。
        // 为了兼容现有代码，我们可以通过一种“技巧”：在内存中模拟事件，或者扩展 Trip 对象。
        // 但最稳妥的是修改 ArenaService。

        // 暂时我们将整个 metrics 存在 metricsJson 字段里
        trip.metricsJson = jsonEncode(metrics);

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
                  "sampling_rate": "25Hz", // 配合 recording_provider 的抽稀
                  "data": e.sensorData
                      .map((s) => {
                            "offset_ms": s.offsetMs,
                            // 采用扁平化结构并限制小数位数，大幅减小 JSON 体积
                            "accel": [
                              double.parse(s.ax?.toStringAsFixed(3) ?? "0"),
                              double.parse(s.ay?.toStringAsFixed(3) ?? "0"),
                              double.parse(s.az?.toStringAsFixed(3) ?? "0")
                            ],
                            "gyro": [
                              double.parse(s.gx?.toStringAsFixed(3) ?? "0"),
                              double.parse(s.gy?.toStringAsFixed(3) ?? "0"),
                              double.parse(s.gz?.toStringAsFixed(3) ?? "0")
                            ],
                            "mag": [
                              double.parse(s.mx?.toStringAsFixed(1) ?? "0"),
                              double.parse(s.my?.toStringAsFixed(1) ?? "0"),
                              double.parse(s.mz?.toStringAsFixed(1) ?? "0")
                            ],
                          })
                      .toList(),
                }
              })
          .toList(),
    };
  }
}
