import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/models/db_models.dart';

/// 记录最后一次强制刷新的时间戳，用于强制忽略过期快照
final myStatsForceRefreshProvider = StateProvider<int>((ref) => 0);

class MyStats {
  final double totalMileage;
  final Map<String, double> brandDistribution;
  final double globalTotalMileage;
  final int rank;
  final int totalUsers;
  final double pukedValue;

  MyStats({
    required this.totalMileage,
    required this.brandDistribution,
    required this.globalTotalMileage,
    required this.rank,
    required this.totalUsers,
    required this.pukedValue,
  });

  double get contribution =>
      globalTotalMileage > 0 ? (totalMileage / globalTotalMileage) : 0;
}

final myStatsProvider = Provider<AsyncValue<MyStats?>>((ref) {
  final auth = ref.watch(authProvider);

  if (!auth.isAuthenticated || auth.user == null) {
    return const AsyncValue.loading();
  }

  final userId = auth.user!.id;
  // 核心优化：只监听个人统计，不再监听臃肿的全局 arenaStatsProvider
  final userStatsAsync = ref.watch(userStatsEntryProvider(userId));

  return userStatsAsync.when(
    data: (userPayload) {
      if (userPayload == null) {
        // 兜底策略：如果个人快照不存在，尝试从全局汇总中提取该用户的基本里程
        final arenaStats = ref.watch(arenaStatsProvider).value;
        double fallbackMileage = 0;
        double globalTotal = 0;
        int totalUsers = 0;

        if (arenaStats != null) {
          final allSummary =
              arenaStats['all_summary'] as List<RecordModel>? ?? [];
          globalTotal =
              (arenaStats['global_summary']?['globalTotalMileage'] as num?)
                      ?.toDouble() ??
                  0;
          totalUsers =
              (arenaStats['global_summary']?['totalUsers'] as num?)?.toInt() ??
                  0;

          for (final s in allSummary) {
            if (s.getStringValue('user') == userId) {
              fallbackMileage += (s.get<num>('total_distance')).toDouble();
            }
          }
        }

        return AsyncValue.data(MyStats(
          totalMileage: fallbackMileage,
          brandDistribution: {},
          globalTotalMileage: globalTotal > 0 ? globalTotal : fallbackMileage,
          rank: totalUsers + 1,
          totalUsers: totalUsers,
          pukedValue: 0,
        ));
      }

      // 直接从快照中提取所有数据，包括 Web 端预先计算好的 globalTotalMileage
      final totalMileage =
          (userPayload['totalMileage'] as num?)?.toDouble() ?? 0.0;
      final globalTotalMileage =
          (userPayload['globalTotalMileage'] as num?)?.toDouble() ??
              totalMileage; // 兜底为个人里程
      final totalGlobalUsers =
          (userPayload['totalUsers'] as num?)?.toInt() ?? 0;
      final rank =
          (userPayload['rank'] as num?)?.toInt() ?? (totalGlobalUsers + 1);
      final pukedValue = (userPayload['pukedValue'] as num?)?.toDouble() ?? 0.0;

      final rawBrands =
          userPayload['brandDistribution'] as Map<String, dynamic>? ?? {};
      final brandDistribution =
          rawBrands.map((k, v) => MapEntry(k, (v as num).toDouble()));

      return AsyncValue.data(MyStats(
        totalMileage: totalMileage,
        brandDistribution: brandDistribution,
        globalTotalMileage: globalTotalMileage,
        rank: rank,
        totalUsers: totalGlobalUsers,
        pukedValue: pukedValue,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

final userStatsEntryProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final cloudService = ref.read(cloudTripServiceProvider);

  // 核心优化：直接请求个人快照记录。
  // 所有的复杂聚合逻辑已经在 Web 端完成，手机端只负责“读”。
  final snapshot = await cloudService.fetchUserStats(userId);
  if (snapshot != null) return snapshot;

  // 如果快照不存在且有上传过的行程，则尝试通过 arenaStats 兜底（这种情况极少）
  debugPrint(
      '[MyStats] Snapshot missing, fallback to partial data from summary...');
  return null;
});
