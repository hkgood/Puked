import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/models/db_models.dart';

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

  double get contribution => globalTotalMileage > 0 ? (totalMileage / globalTotalMileage) : 0;
}

final myStatsProvider = Provider<AsyncValue<MyStats>>((ref) {
  final auth = ref.watch(authProvider);
  final arena = ref.watch(arenaProvider);
  final arenaStatsAsync = ref.watch(arenaStatsProvider);

  if (!auth.isAuthenticated || auth.user == null) {
    return const AsyncValue.loading();
  }

  return arenaStatsAsync.when(
    data: (_) {
      // 使用 ArenaService 处理后的数据，其中包含了正确的 global_summary
      final globalStats = arena.stats;
      final userId = auth.user!.id;
      final cloudService = ref.read(cloudTripServiceProvider);

      // 获取全局总量 (从 arena_stats 的 global_summary 中)
      final globalSummary = globalStats['global_summary'] as Map<String, dynamic>?;
      final globalTotalDist = (globalSummary?['globalTotalMileage'] as num?)?.toDouble() ?? 0.0;
      final totalGlobalUsers = (globalSummary?['totalUsers'] as num?)?.toInt() ?? 0;

      // 由于 myStatsProvider 是一个同步 Provider，我们使用 ref.watch 一个针对该用户的 FutureProvider
      final userStatsAsync = ref.watch(_userStatsEntryProvider(userId));

      return userStatsAsync.when(
        data: (userPayload) {
          if (userPayload == null) {
            return AsyncValue.data(MyStats(
              totalMileage: 0,
              brandDistribution: {},
              globalTotalMileage: globalTotalDist,
              rank: totalGlobalUsers + 1,
              totalUsers: totalGlobalUsers,
              pukedValue: 0,
            ));
          }

          // 核心修复：显式转换个人品牌分布 Map，防止 int/double 混用导致的崩溃
          final rawBrands = userPayload['brandDistribution'] as Map<String, dynamic>? ?? {};
          final brandDistribution = rawBrands.map((k, v) => MapEntry(k, (v as num).toDouble()));

          return AsyncValue.data(MyStats(
            totalMileage: (userPayload['totalMileage'] as num?)?.toDouble() ?? 0.0,
            brandDistribution: brandDistribution,
            globalTotalMileage: globalTotalDist,
            rank: (userPayload['rank'] as num?)?.toInt() ?? (totalGlobalUsers + 1),
            totalUsers: totalGlobalUsers,
            pukedValue: (userPayload['pukedValue'] as num?)?.toDouble() ?? 0.0,
          ));
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

final _userStatsEntryProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final cloudService = ref.read(cloudTripServiceProvider);
  return await cloudService.fetchUserStats(userId);
});

int _getFilteredEventCount(Trip t) {
  final Map<String, dynamic> source = {};
  source['event_count'] = t.eventCount;

  final metrics = t.cloudMetrics;

  if (metrics != null) {
    metrics.forEach((k, v) => source[k.toLowerCase()] = v);
    final breakdown = metrics['event_breakdown'];
    if (breakdown is Map<String, dynamic>) {
      breakdown.forEach((k, v) => source[k.toLowerCase()] = v);
    }
  } else if (t.id != 0) {
    for (final event in t.events) {
      final type = event.type;
      source[type.toLowerCase()] = (source[type.toLowerCase()] ?? 0) + 1;
    }
  }

  final negativeKeysMap = {
    'rapidAcceleration': [
      'rapidacceleration',
      'rapid_acceleration',
      'accel',
      'rapid_accel',
      'acceleration'
    ],
    'rapidDeceleration': [
      'rapiddeceleration',
      'rapid_deceleration',
      'brake',
      'rapid_brake',
      'deceleration',
      'braking'
    ],
    'jerk': ['jerk', 'jerk_event', 'jerks', 'jerk_count'],
    'wobble': ['wobble', 'wobble_event', 'wobbles', 'wobble_count']
  };

  int totalFiltered = 0;
  negativeKeysMap.forEach((mainKey, possibleKeys) {
    for (final k in possibleKeys) {
      if (source[k] != null) {
        final count = double.tryParse(source[k].toString())?.toInt() ?? 0;
        if (count > 0) {
          totalFiltered += count;
          break;
        }
      }
    }
  });

  return totalFiltered;
}
