import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/features/settings/providers/my_stats_provider.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/metadata_sync_service.dart';
import 'package:puked/services/user_session_manager.dart';
import 'package:puked/models/db_models.dart';
import '../models/arena_data.dart';

final arenaBrandsProvider = Provider<AsyncValue<List<Brand>>>((ref) {
  return ref.watch(allBrandsProvider);
});

final arenaTripsProvider = StreamProvider<List<Trip>>((ref) {
  final storage = ref.read(storageServiceProvider);
  return storage.watchTrips();
});

/// 云端统计快照 Provider (核心优化：不再拉取全量行程)
final arenaStatsProvider =
    StateNotifierProvider<ArenaStatsNotifier, AsyncValue<Map<String, dynamic>>>(
        (ref) {
  return ArenaStatsNotifier(ref);
});

class ArenaStatsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref ref;
  static const String _cacheKey = 'puked_arena_stats_cache';
  bool _isRefreshing = false; // 真正追踪网络任务的标志

  ArenaStatsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();

    // 🔥 监听会话变更，在账号切换时清理缓存
    ref.read(userSessionManagerProvider).sessionChanges.listen((event) {
      debugPrint('[Arena] Session event: $event');

      switch (event.type) {
        case SessionEventType.logout:
        case SessionEventType.switched:
          // 账号切换或退出 - 清理缓存
          _clearCache();
          state = const AsyncValue.loading();
          break;

        case SessionEventType.started:
          // 新账号登录 - 加载该账号的数据
          refresh(force: false, isSilent: false);
          break;

        case SessionEventType.restored:
          // 会话恢复 - 已在 _init 中处理
          break;
      }
    });
  }

  Future<void> _init() async {
    // 1. 先尝试加载本地缓存
    await _loadCache();

    // 2. 无论是否有缓存，都在后台发起一次轻量刷新 (非强制)
    // 这样用户一打开 App，数据就是最新的
    refresh(force: false, isSilent: true);
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> rawJson = jsonDecode(cachedStr);

        // ✅ 读取品牌和版本映射表
        final brandMap = (rawJson['brand_map'] as Map<String, dynamic>?) ?? {};
        final versionMap =
            (rawJson['version_map'] as Map<String, dynamic>?) ?? {};

        // 将 Map 还原为 RecordModel 列表，并显式指定泛型以确保 iOS 编译成功
        final List<RecordModel> allSummary =
            (rawJson['all_summary'] as List).map<RecordModel>((item) {
          final record = RecordModel(
              Map<String, dynamic>.from(item as Map<String, dynamic>));

          // ✅ 从映射表恢复 expand 信息
          final brandId = record.getStringValue('brand');
          if (brandId.isNotEmpty && brandMap.containsKey(brandId)) {
            final brandData = brandMap[brandId] as Map<String, dynamic>;
            record.expand['brand'] = [
              RecordModel({
                'id': brandId,
                'name': brandData['name'] ?? '',
                'logo': brandData['logo'] ?? '',
              })
            ];
          }

          final versionId = record.getStringValue('software_version');
          if (versionId.isNotEmpty && versionMap.containsKey(versionId)) {
            final versionData = versionMap[versionId] as Map<String, dynamic>;
            record.expand['software_version'] = [
              RecordModel({
                'id': versionId,
                'versionString': versionData['versionString'] ?? '',
                'version_name': versionData['version_name'] ?? '',
              })
            ];
          }

          return record;
        }).toList();

        // ✅ weeklySummary 也需要恢复 expand 信息
        final List<RecordModel> weeklySummary =
            (rawJson['weekly_summary'] as List).map<RecordModel>((item) {
          final record = RecordModel(
              Map<String, dynamic>.from(item as Map<String, dynamic>));

          // ✅ 从映射表恢复 expand 信息
          final brandId = record.getStringValue('brand');
          if (brandId.isNotEmpty && brandMap.containsKey(brandId)) {
            final brandData = brandMap[brandId] as Map<String, dynamic>;
            record.expand['brand'] = [
              RecordModel({
                'id': brandId,
                'name': brandData['name'] ?? '',
                'logo': brandData['logo'] ?? '',
              })
            ];
          }

          final versionId = record.getStringValue('software_version');
          if (versionId.isNotEmpty && versionMap.containsKey(versionId)) {
            final versionData = versionMap[versionId] as Map<String, dynamic>;
            record.expand['software_version'] = [
              RecordModel({
                'id': versionId,
                'versionString': versionData['versionString'] ?? '',
                'version_name': versionData['version_name'] ?? '',
              })
            ];
          }

          return record;
        }).toList();

        final data = {
          'all_summary': allSummary,
          'weekly_summary': weeklySummary,
        };

        // 如果当前是加载状态，将其设为数据状态（即使是旧数据）
        if (state.isLoading) {
          state = AsyncValue.data(data);
          debugPrint('[Arena] ✅ Local cache loaded with expand info restored.');
        }
      }
    } catch (e) {
      debugPrint('[Arena] Failed to load/reconstruct cache: $e');
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      if (data.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();

      // RecordModel 自带 toJson，但我们需要处理列表
      final allSummary = (data['all_summary'] as List<RecordModel>)
          .map((r) => r.toJson())
          .toList();
      final weeklySummary = (data['weekly_summary'] as List<RecordModel>)
          .map((r) => r.toJson())
          .toList();

      // ✅ 新增：同时缓存品牌和版本的映射表，解决 "Unknown" 问题
      final brandMap = <String, Map<String, String>>{};
      final versionMap = <String, Map<String, String>>{};

      // 遍历 all_summary
      for (final r in (data['all_summary'] as List<RecordModel>)) {
        final brandId = r.getStringValue('brand');
        final brandRecord = r.expand['brand']?.firstOrNull;
        if (brandId.isNotEmpty && brandRecord != null) {
          brandMap[brandId] = {
            'name': brandRecord.getStringValue('name'),
            'logo': brandRecord.getStringValue('logo'),
          };
        }

        final versionId = r.getStringValue('software_version');
        final versionRecord = r.expand['software_version']?.firstOrNull ??
            r.expand['software_versions']?.firstOrNull;
        if (versionId.isNotEmpty && versionRecord != null) {
          versionMap[versionId] = {
            'versionString': versionRecord.getStringValue('versionString'),
            'version_name': versionRecord.getStringValue('version_name'),
          };
        }
      }

      // ✅ 遍历 weekly_summary（周榜可能有独特的品牌/版本）
      for (final r in (data['weekly_summary'] as List<RecordModel>)) {
        final brandId = r.getStringValue('brand');
        final brandRecord = r.expand['brand']?.firstOrNull;
        if (brandId.isNotEmpty &&
            brandRecord != null &&
            !brandMap.containsKey(brandId)) {
          brandMap[brandId] = {
            'name': brandRecord.getStringValue('name'),
            'logo': brandRecord.getStringValue('logo'),
          };
        }

        final versionId = r.getStringValue('software_version');
        final versionRecord = r.expand['software_version']?.firstOrNull ??
            r.expand['software_versions']?.firstOrNull;
        if (versionId.isNotEmpty &&
            versionRecord != null &&
            !versionMap.containsKey(versionId)) {
          versionMap[versionId] = {
            'versionString': versionRecord.getStringValue('versionString'),
            'version_name': versionRecord.getStringValue('version_name'),
          };
        }
      }

      final serializableData = {
        'all_summary': allSummary,
        'weekly_summary': weeklySummary,
        'brand_map': brandMap, // ✅ 新增映射表
        'version_map': versionMap, // ✅ 新增映射表
        'cached_at': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_cacheKey, jsonEncode(serializableData));
    } catch (e) {
      debugPrint('[Arena] Failed to save cache: $e');
    }
  }

  /// 清理缓存（账号切换时调用）
  Future<void> _clearCache() async {
    debugPrint('[Arena] Clearing stats cache');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      debugPrint('[Arena] Failed to clear cache: $e');
    }
  }

  Future<void> refresh({bool force = false, bool isSilent = false}) async {
    // 核心防御：只有当真正的网络任务在运行时才跳过
    if (_isRefreshing && !force) {
      debugPrint(
          '[Arena] Refresh skipped: network task already in progress...');
      return;
    }

    debugPrint(
        '[Arena] Refresh called. force: $force, isSilent: $isSilent, hasValue: ${state.hasValue}');

    _isRefreshing = true;

    // ✅ 优化：只在完全没有数据时才显示 loading 状态
    // 如果已有数据，直接在后台刷新，保持旧数据显示，避免空白页面
    if (!state.hasValue) {
      state = const AsyncLoading<Map<String, dynamic>>();
    }
    // 如果有数据，不改变 state，保持旧数据显示

    try {
      final cloudService = ref.read(cloudTripServiceProvider);
      // ... 其余逻辑保持不变 ...
      final metadataService = ref.read(metadataSyncServiceProvider);

      // 同步元数据
      await metadataService.syncBrandsFromCloud();
      await Future.delayed(const Duration(milliseconds: 200));

      if (force) {
        debugPrint('[Arena] Triggering cloud stats recalculation...');
        ref.read(myStatsForceRefreshProvider.notifier).state =
            DateTime.now().millisecondsSinceEpoch;
        await cloudService.triggerArenaSync();
      }

      final stats = await cloudService.fetchArenaStats();

      // ✅ 只有成功获取数据后，才更新 state 和缓存
      if (stats.isNotEmpty) {
        await _saveCache(stats);
        state = AsyncValue.data(stats);
        debugPrint('[Arena] Refresh success - new data applied.');
      } else {
        debugPrint('[Arena] Refresh returned empty data - keeping old cache.');
      }

      _isRefreshing = false;
    } catch (e, stack) {
      _isRefreshing = false;
      debugPrint('[Arena] Error in refresh: $e');

      // ✅ 出错时，保留旧数据，不显示错误界面
      if (state.hasValue) {
        debugPrint('[Arena] Network error - keeping stale data for display.');
        // 不改变 state，继续显示旧数据
      } else {
        // 完全没有数据时才显示错误
        debugPrint('[Arena] No cached data available - showing error.');
        state = AsyncValue.error(e, stack);
      }
    }
  }
}

final arenaProvider = Provider((ref) {
  // 监听品牌列表
  final brandsAsync = ref.watch(arenaBrandsProvider);
  final brands = brandsAsync.when(
      data: (d) => d, loading: () => <Brand>[], error: (_, __) => <Brand>[]);

  // 监听版本列表
  final versionsAsync = ref.watch(allVersionsProvider);
  final versions = versionsAsync.when(
      data: (d) => d,
      loading: () => <SoftwareVersion>[],
      error: (_, __) => <SoftwareVersion>[]);

  // ✅ 监听原始统计数据 - 关键优化：loading 和 error 时保留旧值
  final statsAsync = ref.watch(arenaStatsProvider);
  final rawStats = statsAsync.when(
      data: (d) => d,
      loading: () => statsAsync.valueOrNull ?? <String, dynamic>{}, // 保留旧数据
      error: (_, __) => statsAsync.valueOrNull ?? <String, dynamic>{}); // 保留旧数据

  return ArenaService(ref, brands, versions, rawStats);
});

class ArenaService {
  final Ref _ref;
  final List<Brand> localBrands;
  final List<SoftwareVersion> versions;
  final Map<String, dynamic> rawStats;
  late final Map<String, dynamic> _processedStats;
  late final List<Brand> _mergedBrands; // 合并了统计数据中发现的新品牌

  Map<String, dynamic> get stats => _processedStats;
  List<Brand> get availableBrands => _mergedBrands;

  ArenaService(this._ref, this.localBrands, this.versions, this.rawStats) {
    _processedStats = _processRawStats(rawStats);
    _mergedBrands = _buildMergedBrands();
  }

  /// 合并本地品牌库和从统计数据中通过 expand 获取到的实时品牌信息
  List<Brand> _buildMergedBrands() {
    // 1. 先加入本地已启用的品牌 (这些是用户在 Web 后台明确开启的)
    // 增加 .distinct() 逻辑，防止本地数据库由于大小写同步问题出现重复项
    final Map<String, Brand> brandMap = {};

    for (var b in localBrands) {
      final lowerName = b.name.toLowerCase();
      // 如果品牌已启用，或者该 Key 尚未在 Map 中，则添加/更新
      if (b.isEnabled || !brandMap.containsKey(lowerName)) {
        brandMap[lowerName] = b;
      }
    }

    final allSummary = rawStats['all_summary'] as List<RecordModel>? ?? [];
    for (final s in allSummary) {
      final brandRecord = s.expand['brand']?.firstOrNull;
      if (brandRecord == null) continue;

      final brandName = brandRecord.getStringValue('name');
      if (brandName.isEmpty) continue;

      final logoFile = brandRecord.getStringValue('logo');
      final cloudLogoUrl = logoFile.isNotEmpty
          ? _ref
              .read(pbServiceProvider)
              .pb
              .files
              .getUrl(brandRecord, logoFile)
              .toString()
          : null;

      final lowerName = brandName.toLowerCase();
      if (brandMap.containsKey(lowerName)) {
        final local = brandMap[lowerName]!;
        // 只有当本地已启用该品牌时，才更新其云端信息
        if (local.logoUrl == null || local.logoUrl!.isEmpty) {
          local.logoUrl = cloudLogoUrl;
        }
        if (local.cloudId == null || local.cloudId!.isEmpty) {
          local.cloudId = brandRecord.id;
        }
      } else {
        // 如果本地没有该品牌，不再强制创建并显示，除非未来通过设置开启
      }
    }

    // 2. 最终过滤：只显示已启用的品牌 (遵守用户在设置中的选择)
    final result = brandMap.values.where((b) => b.isEnabled).toList();

    result.sort((a, b) {
      // 1. "Others" 品牌强制排在最后 (不分大小写)
      if (a.name.toLowerCase() == 'others') return 1;
      if (b.name.toLowerCase() == 'others') return -1;

      // 2. 其余品牌按 order 排序，若 order 相同按名称字母排序
      final int orderCompare = a.order.compareTo(b.order);
      if (orderCompare != 0) return orderCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return result;
  }

  Map<String, dynamic> _processRawStats(Map<String, dynamic> raw) {
    final allSummary = raw['all_summary'] as List<RecordModel>? ?? [];
    final weeklySummary = raw['weekly_summary'] as List<RecordModel>? ?? [];

    final stats = <String, dynamic>{
      'ranking_brand': [],
      'ranking_version': [],
      'ranking_city': [],
      'ranking_highway': [],
      'mileage': [],
      'leaderboard_total': [],
      'leaderboard_weekly': [],
      'brand_options': [],
      // 🆕 周度排名相关
      'ranking_city_weekly': [],
      'ranking_highway_weekly': [],
      'mileage_weekly': [],
      'global_summary': {
        'globalTotalMileage': 0.0,
        'totalUsers': 0,
      }
    };

    final brandMap = <String, dynamic>{};
    final brandCityMap = <String, dynamic>{};
    final brandHighwayMap = <String, dynamic>{};
    final versionMap = <String, dynamic>{};
    final userTotalMap = <String, dynamic>{};
    final userWeeklyMap = <String, dynamic>{};

    // 🆕 周度数据专用Map
    final brandCityWeeklyMap = <String, dynamic>{};
    final brandHighwayWeeklyMap = <String, dynamic>{};
    final brandWeeklyMileageMap = <String, dynamic>{};

    if (allSummary.isEmpty) return stats;

    // 用于计算全局总量
    double globalTotalMileage = 0;
    final Set<String> uniqueUsers = {};

    // --- 处理全量数据 (严格对齐 Web 端) ---
    for (final s in allSummary) {
      final brandId = s.getStringValue('brand');
      final brandRecord = s.expand['brand']?.firstOrNull;

      // 累加全局里程
      final dist = (s.get<num>('total_distance')).toDouble();
      globalTotalMileage += dist;

      final userId = s.getStringValue('user');
      if (userId.isNotEmpty) uniqueUsers.add(userId);

      final brandName = brandRecord?.getStringValue('name') ?? 'Unknown';

      // 提取品牌 Logo URL (关键：解决 ADAS 品牌 Logo 无法显示的问题)
      String? brandLogoUrl;
      final logoFile = brandRecord?.getStringValue('logo') ?? '';
      if (logoFile.isNotEmpty && brandRecord != null) {
        brandLogoUrl = _ref
            .read(pbServiceProvider)
            .pb
            .files
            .getUrl(brandRecord, logoFile)
            .toString();
      }

      final versionId = s.getStringValue('software_version');
      // 兼容性修复：尝试多种可能的 expand key
      final versionRecord = s.expand['software_version']?.firstOrNull ??
          s.expand['software_versions']?.firstOrNull;

      // 核心修复：极致增强版本号解析。
      // 优先级 1: 统计数据中的 software_version 关联记录 (处理空字符串 fallback)
      final vn = versionRecord?.getStringValue('version_name') ?? '';
      final vs = versionRecord?.getStringValue('versionString') ?? '';
      String versionName = vn.isNotEmpty ? vn : vs;

      if (versionName.isEmpty) {
        // 尝试从本地库匹配 (兜底)
        final localVersion = versions.firstWhere(
          (v) => v.cloudId == versionId || v.versionString == versionId,
          orElse: () => SoftwareVersion()..versionString = '',
        );
        versionName = localVersion.versionString;
      }

      if (versionName.isEmpty) {
        // 如果还是空的，尝试从 key 解析 (key 格式通常为: brandId_versionId_scenario)
        final keyParts = s.getStringValue('key').split('_');
        if (keyParts.length >= 2) {
          // 如果第二部分不全是小写字母数字（即含有点、横杠等版本特征），则认为是版本号
          // 或者如果它虽然是小写字母数字但不是 15 位（PB ID 的特征），也认为是版本号
          final part = keyParts[1];
          final isPbId =
              part.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(part);
          if (!isPbId) {
            versionName = part;
          }
        }
      }

      if (versionName.isEmpty) {
        versionName = 'Unknown';
      }

      final userRecord = s.expand['user']?.firstOrNull;

      String userName = userRecord?.getStringValue('username') ?? '';
      if (userName.isEmpty) userName = userRecord?.getStringValue('name') ?? '';
      if (userName.isEmpty) userName = 'Anonymous';

      final avatar = userRecord?.getStringValue('avatar') ?? '';
      final avatarUrl = (avatar.isNotEmpty && userRecord != null)
          ? _ref
              .read(pbServiceProvider)
              .pb
              .files
              .getUrl(userRecord, avatar)
              .toString()
          : null;

      final totalDistance = (s.get<num>('total_distance')).toDouble();
      final totalEvents = (s.get<num>('total_events')).toInt();
      final tripCount = (s.get<num>('trip_count')).toInt();

      // 解析速度分布
      final speedDist = s.get<Map<String, dynamic>?>('speed_dist') ?? {};
      double h = 0, sm = 0, u = 0, c = 0;
      if (speedDist.isNotEmpty) {
        h = (speedDist['highway'] as num? ?? 0).toDouble();
        sm = (speedDist['smooth'] as num? ?? 0).toDouble();
        u = (speedDist['urban'] as num? ?? 0).toDouble();
        c = (speedDist['congested'] as num? ?? 0).toDouble();
      }

      // 1. 基础品牌初始化
      brandMap.putIfAbsent(
          brandId,
          () => {
                'id': brandId,
                'name': brandName,
                'logoUrl': brandLogoUrl, // 存储云端 Logo
                'totalKm': 0.0,
                'totalEvents': 0,
                'tripCount': 0,
                'mileage_buckets': {
                  'h80': 0.0,
                  'm5080': 0.0,
                  'l2050': 0.0,
                  'c20': 0.0
                },
                'event_breakdown': {
                  'rapidAcceleration': 0,
                  'rapidDeceleration': 0,
                  'jerk': 0,
                  'bump': 0,
                  'wobble': 0
                }
              });

      final b = brandMap[brandId];
      b['totalKm'] += totalDistance;
      b['totalEvents'] += totalEvents;
      b['tripCount'] += tripCount;

      b['mileage_buckets']['h80'] += h;
      b['mileage_buckets']['m5080'] += sm;
      b['mileage_buckets']['l2050'] += u;
      b['mileage_buckets']['c20'] += c;

      // 2. 场景聚合 (深度对齐 Web 端逻辑：优先使用 scenario 字段)
      final keyStr = s.getStringValue('key');
      final scenario = s.getStringValue('scenario').isNotEmpty
          ? s.getStringValue('scenario')
          : (keyStr.contains('_highway_') ? 'highway' : 'city');

      final targetMap = scenario == 'highway' ? brandHighwayMap : brandCityMap;
      targetMap.putIfAbsent(
          brandId,
          () => {
                'id': brandId,
                'name': brandName,
                'logoUrl': brandLogoUrl,
                'km': 0.0,
                'events': 0,
              });
      final scenarioData = targetMap[brandId];
      scenarioData['km'] += totalDistance;
      scenarioData['events'] += totalEvents;

      // 3. 症状累加
      final eb = s.get<Map<String, dynamic>?>('event_breakdown') ?? {};
      if (eb.isNotEmpty) {
        b['event_breakdown']['rapidAcceleration'] +=
            (eb['rapidAcceleration'] as num? ?? 0).toInt();
        b['event_breakdown']['rapidDeceleration'] +=
            (eb['rapidDeceleration'] as num? ?? 0).toInt();
        b['event_breakdown']['jerk'] += (eb['jerk'] as num? ?? 0).toInt();
        b['event_breakdown']['bump'] += (eb['bump'] as num? ?? 0).toInt();
        b['event_breakdown']['wobble'] += (eb['wobble'] as num? ?? 0).toInt();
      }

      // 4. 版本和用户聚合
      final vKey = '${brandId}_$versionId';
      versionMap.putIfAbsent(
          vKey,
          () => {
                'brand': brandId,
                'brandName': brandName,
                'logoUrl': brandLogoUrl,
                'version': versionName,
                'totalKm': 0.0,
                'totalEvents': 0
              });
      final v = versionMap[vKey];
      v['totalKm'] += totalDistance;
      v['totalEvents'] += totalEvents;

      if (userId.isNotEmpty) {
        userTotalMap.putIfAbsent(
            userId,
            () =>
                {'userName': userName, 'avatarUrl': avatarUrl, 'totalKm': 0.0});
        userTotalMap[userId]['totalKm'] += totalDistance;
      }
    }

    // --- 处理周榜数据 (仅取最新一周) ---
    if (weeklySummary.isNotEmpty) {
      final weeks = weeklySummary
          .map((s) => s.getStringValue('period_value'))
          .toSet()
          .toList();
      weeks.sort((a, b) => b.compareTo(a));
      final latestWeek = weeks.first;

      for (final s in weeklySummary
          .where((s) => s.getStringValue('period_value') == latestWeek)) {
        // 🆕 提取品牌周度数据（对齐Web端）
        final brandId = s.getStringValue('brand');
        final brandRecord = s.expand['brand']?.firstOrNull;
        final brandName = brandRecord?.getStringValue('name') ?? 'Unknown';

        // 提取 Logo URL
        String? brandLogoUrl;
        final logoFile = brandRecord?.getStringValue('logo') ?? '';
        if (logoFile.isNotEmpty && brandRecord != null) {
          brandLogoUrl = _ref
              .read(pbServiceProvider)
              .pb
              .files
              .getUrl(brandRecord, logoFile)
              .toString();
        }

        final totalDistance = (s.get<num>('total_distance')).toDouble();
        final totalEvents = (s.get<num>('total_events')).toInt();

        // 🆕 解析速度分布 (用于周度里程排名的分段条)
        final speedDist = s.get<Map<String, dynamic>?>('speed_dist') ?? {};
        double h = 0, sm = 0, u = 0, c = 0;
        if (speedDist.isNotEmpty) {
          h = (speedDist['highway'] as num? ?? 0).toDouble();
          sm = (speedDist['smooth'] as num? ?? 0).toDouble();
          u = (speedDist['urban'] as num? ?? 0).toDouble();
          c = (speedDist['congested'] as num? ?? 0).toDouble();
        }

        // 🆕 累计品牌周度总里程（用于mileage_weekly）
        brandWeeklyMileageMap.putIfAbsent(
            brandId,
            () => {
                  'id': brandId,
                  'name': brandName,
                  'logoUrl': brandLogoUrl,
                  'totalKm': 0.0,
                  'mileage_buckets': {
                    'h80': 0.0,
                    'm5080': 0.0,
                    'l2050': 0.0,
                    'c20': 0.0
                  }
                });
        final weeklyMileage = brandWeeklyMileageMap[brandId];
        weeklyMileage['totalKm'] += totalDistance;
        weeklyMileage['mileage_buckets']['h80'] += h;
        weeklyMileage['mileage_buckets']['m5080'] += sm;
        weeklyMileage['mileage_buckets']['l2050'] += u;
        weeklyMileage['mileage_buckets']['c20'] += c;

        // 🆕 按场景分类（用于周度舒适度排名）
        final keyStr = s.getStringValue('key');
        final scenario = s.getStringValue('scenario').isNotEmpty
            ? s.getStringValue('scenario')
            : (keyStr.contains('_highway_') ? 'highway' : 'city');

        final targetMap =
            scenario == 'highway' ? brandHighwayWeeklyMap : brandCityWeeklyMap;
        targetMap.putIfAbsent(
            brandId,
            () => {
                  'id': brandId,
                  'name': brandName,
                  'logoUrl': brandLogoUrl,
                  'km': 0.0,
                  'events': 0
                });
        final scenarioData = targetMap[brandId];
        scenarioData['km'] += totalDistance;
        scenarioData['events'] += totalEvents;

        // 用户周榜（保持原有逻辑）
        final userId = s.getStringValue('user');
        if (userId.isEmpty) continue;

        final userRecord = s.expand['user']?.firstOrNull;
        String userName = userRecord?.getStringValue('username') ?? '';
        if (userName.isEmpty)
          userName = userRecord?.getStringValue('name') ?? '';
        if (userName.isEmpty) userName = 'Anonymous';

        final avatar = userRecord?.getStringValue('avatar') ?? '';
        final avatarUrl = (avatar.isNotEmpty && userRecord != null)
            ? _ref
                .read(pbServiceProvider)
                .pb
                .files
                .getUrl(userRecord, avatar)
                .toString()
            : null;

        userWeeklyMap.putIfAbsent(
            userId,
            () =>
                {'userName': userName, 'avatarUrl': avatarUrl, 'totalKm': 0.0});
        userWeeklyMap[userId]['totalKm'] +=
            (s.get<num>('total_distance')).toDouble();
      }
    }

    // --- 最终数据组装 (对齐 Web 端) ---

    // 舒适度排行门槛：移除 300km 限制，让所有品牌都能显示
    // 设定一个极小的阈值 (0.1km) 防止除以零
    const double rankingThreshold = 0.1;

    stats['ranking_brand'] = brandMap.values
        .where((b) => (b['totalKm'] as num) >= rankingThreshold)
        .map((b) => {
              'label': b['name'],
              'brand': b['name'],
              'brandId': b['id'],
              'logoUrl': b['logoUrl'], // 传给 UI
              'totalKm': b['totalKm'],
              'totalEvents': b['totalEvents'],
              'kmPerEvent': b['totalEvents'] > 0
                  ? b['totalKm'] / b['totalEvents']
                  : b['totalKm']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_brand'] = (stats['ranking_brand'] as List).take(10).toList();

    stats['ranking_version'] = versionMap.values
        .where((v) => (v['totalKm'] as num) >= rankingThreshold)
        .map((v) => {
              'label': '${v['brandName']} ${v['version']}',
              'brand': v['brandName'],
              'brandId': v['brand'],
              'logoUrl': v['logoUrl'],
              'version': v['version'],
              'totalKm': v['totalKm'],
              'totalEvents': v['totalEvents'],
              'kmPerEvent': v['totalEvents'] > 0
                  ? v['totalKm'] / v['totalEvents']
                  : v['totalKm']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_version'] =
        (stats['ranking_version'] as List).take(10).toList();

    stats['ranking_city'] = brandCityMap.values
        .where((b) => (b['km'] as num) >= (rankingThreshold / 2)) // 场景排行门槛减半
        .map((b) => {
              'label': b['name'],
              'brand': b['name'],
              'brandId': b['id'],
              'logoUrl': b['logoUrl'],
              'kmPerEvent': b['events'] > 0 ? b['km'] / b['events'] : b['km']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_city'] = (stats['ranking_city'] as List).take(10).toList();

    stats['ranking_highway'] = brandHighwayMap.values
        .where((b) => (b['km'] as num) >= (rankingThreshold / 2))
        .map((b) => {
              'label': b['name'],
              'brand': b['name'],
              'brandId': b['id'],
              'logoUrl': b['logoUrl'],
              'kmPerEvent': b['events'] > 0 ? b['km'] / b['events'] : b['km']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_highway'] =
        (stats['ranking_highway'] as List).take(10).toList();

    stats['mileage'] = brandMap.values
        .map((b) => {
              'brand': b['name'],
              'brandKey': b['id'],
              'logoUrl': b['logoUrl'],
              'totalKm': b['totalKm'],
              'breakdown': {
                'highway': b['mileage_buckets']['h80'],
                'smooth': b['mileage_buckets']['m5080'],
                'urban': b['mileage_buckets']['l2050'],
                'congested': b['mileage_buckets']['c20']
              }
            })
        .toList()
      ..sort((a, b) => (b['totalKm'] as num).compareTo(a['totalKm'] as num));

    stats['leaderboard_total'] = userTotalMap.values.toList()
      ..sort((a, b) => (b['totalKm'] as num).compareTo(a['totalKm'] as num));
    stats['leaderboard_total'] =
        (stats['leaderboard_total'] as List).take(10).toList();

    stats['leaderboard_weekly'] = userWeeklyMap.values.toList()
      ..sort((a, b) => (b['totalKm'] as num).compareTo(a['totalKm'] as num));
    stats['leaderboard_weekly'] =
        (stats['leaderboard_weekly'] as List).take(10).toList();

    // 🆕 周度场景舒适度排名
    stats['ranking_city_weekly'] = brandCityWeeklyMap.values
        .where((b) => (b['km'] as num) >= (rankingThreshold / 2))
        .map((b) => {
              'label': b['name'],
              'brand': b['name'],
              'brandId': b['id'],
              'logoUrl': b['logoUrl'],
              'kmPerEvent': b['events'] > 0 ? b['km'] / b['events'] : b['km']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_city_weekly'] =
        (stats['ranking_city_weekly'] as List).take(10).toList();

    stats['ranking_highway_weekly'] = brandHighwayWeeklyMap.values
        .where((b) => (b['km'] as num) >= (rankingThreshold / 2))
        .map((b) => {
              'label': b['name'],
              'brand': b['name'],
              'brandId': b['id'],
              'logoUrl': b['logoUrl'],
              'kmPerEvent': b['events'] > 0 ? b['km'] / b['events'] : b['km']
            })
        .toList()
      ..sort(
          (a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_highway_weekly'] =
        (stats['ranking_highway_weekly'] as List).take(10).toList();

    // 🆕 周度总里程排名（带速度分段）
    stats['mileage_weekly'] = brandWeeklyMileageMap.values
        .map((b) => {
              'brand': b['name'],
              'brandKey': b['id'],
              'logoUrl': b['logoUrl'],
              'totalKm': b['totalKm'],
              'breakdown': {
                'highway': b['mileage_buckets']['h80'],
                'smooth': b['mileage_buckets']['m5080'],
                'urban': b['mileage_buckets']['l2050'],
                'congested': b['mileage_buckets']['c20']
              }
            })
        .toList()
      ..sort((a, b) => (b['totalKm'] as num).compareTo(a['totalKm'] as num));
    stats['mileage_weekly'] =
        (stats['mileage_weekly'] as List).take(10).toList();

    stats['brand_options'] = brandMap.values
        .map((b) => {'key': b['id'], 'name': b['name']})
        .toList();

    // 注入全局汇总数据，用于计算贡献度、排名等
    stats['global_summary'] = {
      'globalTotalMileage': globalTotalMileage,
      'totalUsers': uniqueUsers.length,
    };

    for (final b in brandMap.values) {
      final brandId = b['id'];
      final eventBreakdown = b['event_breakdown'] as Map<String, dynamic>;
      final totalKm = b['totalKm'] as double;

      stats['symptoms_$brandId'] = {
        'details': {
          'rapidAcceleration': eventBreakdown['rapidAcceleration'] > 0
              ? totalKm / eventBreakdown['rapidAcceleration']
              : 0.0,
          'rapidDeceleration': eventBreakdown['rapidDeceleration'] > 0
              ? totalKm / eventBreakdown['rapidDeceleration']
              : 0.0,
          'jerk': eventBreakdown['jerk'] > 0
              ? totalKm / eventBreakdown['jerk']
              : 0.0,
          'bump': eventBreakdown['bump'] > 0
              ? totalKm / eventBreakdown['bump']
              : 0.0,
          'wobble': eventBreakdown['wobble'] > 0
              ? totalKm / eventBreakdown['wobble']
              : 0.0,
        },
        'counts': Map<String, int>.from(eventBreakdown),
        'totalKm': totalKm,
        'tripCount': b['tripCount']
      };

      stats['evolution_$brandId'] = versionMap.values
          .where((v) => v['brand'] == brandId)
          .map((v) => {
                'version': v['version'],
                'kmPerEvent': v['totalEvents'] > 0
                    ? v['totalKm'] / v['totalEvents']
                    : v['totalKm']
              })
          .toList()
        ..sort((a, b) =>
            (a['version'] as String).compareTo(b['version'] as String));
    }

    return stats;
  }

  // --- 辅助方法：依然使用本地基础库进行名称解析 (为了 UI 兼容) ---
  String getBrandName(String idOrName) {
    if (idOrName == 'Unknown') return 'Unknown';
    final brand = _mergedBrands.firstWhere(
      (b) =>
          b.cloudId == idOrName ||
          b.name.toLowerCase() == idOrName.toLowerCase(),
      orElse: () => Brand()..name = idOrName,
    );
    return brand.displayName ?? brand.name;
  }

  String? getBrandLogoUrl(String brandKey) {
    final brand = _mergedBrands.firstWhere(
      (b) =>
          b.cloudId == brandKey ||
          b.name.toLowerCase() == brandKey.toLowerCase(),
      orElse: () => Brand()..name = brandKey,
    );
    return brand.logoUrl;
  }

  String getVersionName(String idOrString) {
    if (idOrString == 'Unknown') return 'Unknown';
    final version = versions.firstWhere(
      (v) => v.cloudId == idOrString || v.versionString == idOrString,
      orElse: () => SoftwareVersion()..versionString = idOrString,
    );
    return version.versionString;
  }

  // --- 核心优化：直接从预计算快照中转换数据模型 ---

  List<BrandData> getTop10Data({bool groupByBrand = true}) {
    final list =
        _processedStats[groupByBrand ? 'ranking_brand' : 'ranking_version']
            as List?;
    if (list == null) return [];

    return list.map((item) => _mapToBrandData(item)).toList();
  }

  List<BrandData> getScenarioRankingData(
      {required String scenario, bool groupByBrand = true}) {
    // 移动端目前不支持按版本的场景排行，仅支持按品牌
    final list =
        _processedStats[scenario == 'city' ? 'ranking_city' : 'ranking_highway']
            as List?;
    if (list == null) return [];

    return list.map((item) => _mapToBrandData(item)).toList();
  }

  // 🆕 获取周度场景舒适度排名数据
  List<BrandData> getWeeklyScenarioRankingData({required String scenario}) {
    final list = _processedStats[scenario == 'city'
        ? 'ranking_city_weekly'
        : 'ranking_highway_weekly'] as List?;
    if (list == null) return [];

    return list.map((item) => _mapToBrandData(item)).toList();
  }

  // 🆕 获取周度里程排名数据
  List<BrandData> getWeeklyMileageData() {
    final list = _processedStats['mileage_weekly'] as List?;
    if (list == null) return [];

    return list.map((item) {
      final map = item as Map<String, dynamic>;

      final rawBreakdown = map['breakdown'] as Map<String, dynamic>? ?? {};
      final Map<String, double> breakdown =
          rawBreakdown.map((k, v) => MapEntry(k, (v as num).toDouble()));

      return BrandData(
        brand: map['brandKey'] ?? '',
        brandName: map['brand'] ?? '',
        logoUrl: map['logoUrl'],
        totalKm: (map['totalKm'] as num?)?.toDouble(),
        breakdown: breakdown,
      );
    }).toList();
  }

  BrandData _mapToBrandData(dynamic item) {
    final map = item as Map<String, dynamic>;
    final brandId = map['brandId'] ?? '';
    final brandName = map['brand'] ?? '';
    final versionName = map['version'] ?? '';

    return BrandData(
      brand: brandId.isNotEmpty ? brandId : brandName,
      brandName: brandName,
      logoUrl: map['logoUrl'],
      version: versionName,
      versionName: versionName, // 核心修复：直接透传处理好的 versionName，不再重新解析
      kmPerEvent: (map['kmPerEvent'] as num?)?.toDouble(),
      totalKm: (map['totalKm'] as num?)?.toDouble(),
      totalEvents: (map['totalEvents'] as num?)?.toInt(),
    );
  }

  VersionEvolutionData getEvolutionData(String brandKey) {
    final list = _processedStats['evolution_$brandKey'] as List?;
    if (list == null)
      return VersionEvolutionData(brand: brandKey, evolution: []);

    return VersionEvolutionData(
      brand: brandKey,
      evolution: list.map((item) {
        final map = item as Map<String, dynamic>;
        final vName = map['version'] ?? '';
        return VersionPoint(
          version: vName, // 核心修复：直接使用已解析的版本名称
          kmPerEvent: (map['kmPerEvent'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList(),
    );
  }

  SymptomData getSymptomDetails(String brandKey, {String? version}) {
    final data = _processedStats['symptoms_$brandKey'] as Map<String, dynamic>?;
    if (data == null) {
      return SymptomData(
          brand: brandKey, details: {}, counts: {}, totalKm: 0, tripCount: 0);
    }

    final rawDetails = data['details'] as Map<String, dynamic>? ?? {};
    final Map<String, double> details =
        rawDetails.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final rawCounts = data['counts'] as Map<String, dynamic>? ?? {};
    final Map<String, int> counts =
        rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

    return SymptomData(
      brand: brandKey,
      brandName: getBrandName(brandKey),
      details: details,
      counts: counts,
      totalKm: (data['totalKm'] as num?)?.toDouble() ?? 0.0,
      tripCount: (data['tripCount'] as num?)?.toInt() ?? 0,
    );
  }

  List<BrandData> getTotalMileageData() {
    final list = _processedStats['mileage'] as List?;
    if (list == null) return [];

    return list.map((item) {
      final map = item as Map<String, dynamic>;

      final rawBreakdown = map['breakdown'] as Map<String, dynamic>? ?? {};
      final Map<String, double> breakdown =
          rawBreakdown.map((k, v) => MapEntry(k, (v as num).toDouble()));

      return BrandData(
        brand: map['brandKey'] ?? '',
        brandName: map['brand'] ?? '',
        logoUrl: map['logoUrl'],
        totalKm: (map['totalKm'] as num?)?.toDouble(),
        breakdown: breakdown,
      );
    }).toList();
  }

  List<UserLeaderboardData> getUserLeaderboard({bool weekly = false}) {
    final list =
        _processedStats[weekly ? 'leaderboard_weekly' : 'leaderboard_total']
            as List?;
    if (list == null) return [];

    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return UserLeaderboardData(
        userName: map['userName'] ?? 'Anonymous',
        totalKm: (map['totalKm'] as num?)?.toDouble() ?? 0.0,
        tripCount: (map['tripCount'] as num?)?.toInt() ?? 0,
        avatarUrl: map['avatarUrl'],
      );
    }).toList();
  }

  String getDefaultBrand() {
    final settings = _ref.read(settingsProvider);
    if (settings.brandRef != null && settings.brandRef!.isNotEmpty) {
      return settings.brandRef!;
    }
    if (settings.brand != null && settings.brand!.isNotEmpty) {
      // 尝试解析名称为 ID
      final brandObj = _mergedBrands.firstWhere(
        (b) => b.name.toLowerCase() == settings.brand!.toLowerCase(),
        orElse: () => Brand()..name = settings.brand!,
      );
      return brandObj.cloudId ?? brandObj.name;
    }
    if (_mergedBrands.isNotEmpty) {
      return _mergedBrands.first.cloudId ?? _mergedBrands.first.name;
    }
    return 'Tesla';
  }
}
