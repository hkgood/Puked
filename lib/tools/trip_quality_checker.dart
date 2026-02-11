import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

/// 行程质量检查器 - 用于识别和标记脏数据
class TripQualityChecker {
  final PocketBaseService pbService;

  TripQualityChecker(this.pbService);

  /// 分析单个行程的质量
  Map<String, dynamic> analyzeTripQuality(RecordModel trip) {
    final metrics = trip.get<Map<String, dynamic>?>('metrics') ?? {};

    final avgSpeed =
        double.tryParse(metrics['avg_speed_kmh']?.toString() ?? '0') ?? 0;
    final distanceKm =
        double.tryParse(metrics['distance_km']?.toString() ?? '0') ?? 0;
    final eventCount = metrics['event_count'] as int? ?? 0;
    final durationMin = metrics['duration_min'] as int? ?? 0;

    // P0 级别检测
    if (avgSpeed > 120) {
      return {
        'isDirty': true,
        'level': 'P0',
        'reason': '平均时速异常高 (${avgSpeed.toStringAsFixed(1)} km/h)',
      };
    }

    if (avgSpeed < 5 && distanceKm > 0.5) {
      return {
        'isDirty': true,
        'level': 'P0',
        'reason': '平均时速异常低 (${avgSpeed.toStringAsFixed(1)} km/h)',
      };
    }

    if (eventCount > 0 && distanceKm > 0) {
      final eventsPerKm = eventCount / distanceKm;
      if (eventsPerKm > 2.0) {
        return {
          'isDirty': true,
          'level': 'P0',
          'reason': '负体验密度异常高 (${eventsPerKm.toStringAsFixed(2)} 次/km)',
        };
      }
    }

    // P1 级别检测
    if (distanceKm < 0.5) {
      return {
        'isDirty': true,
        'level': 'P1',
        'reason': '行程距离过短 (${distanceKm.toStringAsFixed(2)} km)',
      };
    }

    if (durationMin < 3 && distanceKm > 0.5) {
      return {
        'isDirty': true,
        'level': 'P1',
        'reason': '行程时长过短 ($durationMin 分钟)',
      };
    }

    if (distanceKm > 10 && eventCount == 0) {
      return {
        'isDirty': true,
        'level': 'P1',
        'reason': '长距离零事件 (${distanceKm.toStringAsFixed(1)} km)',
      };
    }

    return {
      'isDirty': false,
      'level': null,
      'reason': null,
    };
  }

  /// 查询最近N天的行程
  Future<List<RecordModel>> fetchRecentTrips({int days = 7}) async {
    if (!pbService.isAuthenticated) {
      throw Exception('用户未登录');
    }

    final startDate =
        DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

    try {
      return await pbService.pb.collection('trips').getFullList(
            filter:
                'created >= "$startDate" && user = "${pbService.currentUserId}"',
            sort: '-created',
          );
    } catch (e) {
      debugPrint('查询行程失败: $e');
      rethrow;
    }
  }

  /// 批量分析行程质量
  Future<Map<String, dynamic>> analyzeRecentTrips({int days = 7}) async {
    final trips = await fetchRecentTrips(days: days);

    final List<Map<String, dynamic>> dirtyTrips = [];
    final List<RecordModel> cleanTrips = [];

    for (final trip in trips) {
      final result = analyzeTripQuality(trip);
      if (result['isDirty'] == true) {
        dirtyTrips.add({
          'trip': trip,
          'level': result['level'],
          'reason': result['reason'],
        });
      } else {
        cleanTrips.add(trip);
      }
    }

    return {
      'total': trips.length,
      'clean': cleanTrips.length,
      'dirty': dirtyTrips.length,
      'dirtyTrips': dirtyTrips,
      'pollutionRate': trips.isEmpty ? 0.0 : dirtyTrips.length / trips.length,
    };
  }

  /// 标记行程为不公开
  Future<bool> markTripAsPrivate(String recordId) async {
    try {
      await pbService.pb.collection('trips').update(recordId, body: {
        'is_public': false,
      });
      return true;
    } catch (e) {
      debugPrint('标记失败: $e');
      return false;
    }
  }

  /// 批量标记脏数据
  Future<Map<String, int>> batchMarkDirtyTrips(
      List<Map<String, dynamic>> dirtyTrips) async {
    int success = 0;
    int failed = 0;

    for (final item in dirtyTrips) {
      final trip = item['trip'] as RecordModel;
      final result = await markTripAsPrivate(trip.id);
      if (result) {
        success++;
      } else {
        failed++;
      }
    }

    return {'success': success, 'failed': failed};
  }
}

/// Provider
final tripQualityCheckerProvider = Provider((ref) {
  final pbService = ref.watch(pbServiceProvider);
  return TripQualityChecker(pbService);
});

/// 行程质量分析结果 Provider
final tripQualityAnalysisProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  final checker = ref.watch(tripQualityCheckerProvider);
  return await checker.analyzeRecentTrips(days: days);
});
