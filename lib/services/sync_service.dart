import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/storage/storage_service.dart';

class SyncService {
  final PocketBaseService _pbService;
  final StorageService _storage;

  SyncService(this._pbService, this._storage);

  /// 同步一个单次行程到云端
  Future<String> syncTrip(Trip trip) async {
    if (!_pbService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    // 1. 准备摘要数据 (Metrics)
    final metrics = {
      'event_count': trip.eventCount,
      'distance': trip.distance,
      'duration_seconds':
          trip.endTime?.difference(trip.startTime).inSeconds ?? 0,
      // 可以在这里计算更多评分逻辑
    };

    // 2. 准备轨迹简报 (Route Summary) - 降采样
    // 为了节省流量和渲染性能，我们只取部分点
    await trip.trajectory.load();
    final List<Map<String, double>> routeSummary = [];
    final totalPoints = trip.trajectory.length;
    if (totalPoints > 0) {
      final step = (totalPoints / 50).ceil().clamp(1, totalPoints);
      for (int i = 0; i < totalPoints; i += step) {
        final p = trip.trajectory.elementAt(i);
        routeSummary.add({'lat': p.lat, 'lng': p.lng});
      }
    }

    // 3. 上传原始 JSON 文件 (如果有的话)
    // 这里我们可以根据 trip.uuid 找到对应的 log 文件，或者将当前内存中的数据序列化
    // 为了简化，这里假设我们已经有了原始数据 JSON 字符串
    // (实际逻辑中可能需要调用 ExportService 生成 JSON)

    // 4. 在 PocketBase 创建记录
    final body = <String, dynamic>{
      'user': _pbService.currentUserId,
      'brand': trip.brand,
      'car_model': trip.carModel,
      'software_version': trip.softwareVersion,
      'is_public': false, // 默认不公开
      'metrics': metrics,
      'route_summary': routeSummary,
      'share_slug': trip.uuid.substring(0, 8), // 使用 UUID 前 8 位作为短链接
    };

    final record = await _pbService.pb.collection('trips').create(body: body);

    // 5. 更新本地记录的 cloudId
    await _storage.updateTripCloudId(trip.id, record.id);

    return record.id;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final pb = ref.watch(pbServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return SyncService(pb, storage);
});
