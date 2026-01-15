import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/metadata_sync_service.dart';
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
  ArenaStatsNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> refresh({bool force = false}) async {
    // 核心追踪：只要进入 refresh，无论是否强制，都先打一行 log
    debugPrint('[Arena] Refresh called. force: $force, hasValue: ${state.hasValue}');

    if (!state.hasValue || force) {
      state = const AsyncValue.loading();
    }

    try {
      final cloudService = ref.read(cloudTripServiceProvider);
      final metadataService = ref.read(metadataSyncServiceProvider);

      // 只要进入 Arena 页面就尝试同步一次元数据 (不再受 force 限制)
      // 这样即便后台开启了新品牌，用户一进来就能同步到
      debugPrint('[MetadataSync] Starting background metadata sync...');
      await metadataService.syncBrandsFromCloud();
      
      // 给数据库写入留一点缓冲
      await Future.delayed(const Duration(milliseconds: 200));

      // 如果是强制刷新，先触发云端重新计算统计数据
      if (force) {
        debugPrint('[Arena] Triggering cloud stats recalculation...');
        await cloudService.triggerArenaSync();
      }

      final stats = await cloudService.fetchArenaStats();
      state = AsyncValue.data(stats);
    } catch (e, stack) {
      debugPrint('[Arena] Error in refresh: $e');
      state = AsyncValue.error(e, stack);
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

  // 监听原始统计数据 (从 trip_stats_summary 获取)
  final statsAsync = ref.watch(arenaStatsProvider);
  final rawStats = statsAsync.when(
      data: (d) => d,
      loading: () => <String, dynamic>{},
      error: (_, __) => <String, dynamic>{});

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
        // 核心修复：如果在统计数据中发现了该品牌，强制将其设为启用，确保 UI 显示
        local.isEnabled = true;
        
        if (local.logoUrl == null || local.logoUrl!.isEmpty) {
          local.logoUrl = cloudLogoUrl;
        }
        if (local.cloudId == null || local.cloudId!.isEmpty) {
          local.cloudId = brandRecord.id;
        }
      } else {
        // 如果本地没有，但在统计数据中有记录，说明该品牌有历史数据，强制显示
        final newBrand = Brand()
          ..name = brandName
          ..displayName = brandName
          ..cloudId = brandRecord.id
          ..logoUrl = cloudLogoUrl
          ..isEnabled = true;
        brandMap[lowerName] = newBrand;
      }
    }

    // 2. 最终过滤：只显示已启用的品牌 (或者统计数据中强制发现的)
    final result = brandMap.values.where((b) => b.isEnabled).toList();

    result.sort((a, b) {
      // 1. "Others" 品牌强制排在最后 (不分大小写)
      if (a.name.toLowerCase() == 'others') return 1;
      if (b.name.toLowerCase() == 'others') return -1;

      // 2. 其余品牌按 order 排序，若 order 相同按名称字母排序
      final int orderCompare = (a.order ?? 999).compareTo(b.order ?? 999);
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

    if (allSummary.isEmpty) return stats;

    // 用于计算全局总量
    double globalTotalMileage = 0;
    final Set<String> uniqueUsers = {};

    // --- 处理全量数据 (严格对齐 Web 端) ---
    for (final s in allSummary) {
      final brandId = s.getStringValue('brand');
      final brandRecord = s.expand['brand']?.firstOrNull;
      
      // 累加全局里程
      final dist = (s.get<num>('total_distance') ?? 0).toDouble();
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
          final isPbId = part.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(part);
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

      final totalDistance = (s.get<num>('total_distance') ?? 0).toDouble();
      final totalEvents = (s.get<num>('total_events') ?? 0).toInt();
      final tripCount = (s.get<num>('trip_count') ?? 0).toInt();

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
        userTotalMap.putIfAbsent(userId,
            () => {'userName': userName, 'avatarUrl': avatarUrl, 'totalKm': 0.0});
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
        final userId = s.getStringValue('user');
        if (userId.isEmpty) continue;

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

        userWeeklyMap.putIfAbsent(userId,
            () => {'userName': userName, 'avatarUrl': avatarUrl, 'totalKm': 0.0});
        userWeeklyMap[userId]['totalKm'] +=
            (s.get<num>('total_distance') ?? 0).toDouble();
      }
    }

    // --- 最终数据组装 (对齐 Web 端) ---

    // 舒适度排行门槛：只有总里程 >= 300km 的品牌/版本才参与“无负体验排行”
    // 防止极小样本量导致的 MPI 数据失真 (例如 500米 0 负体验)
    const double rankingThreshold = 300.0;

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
      ..sort((a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
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
      ..sort((a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_version'] = (stats['ranking_version'] as List).take(10).toList();

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
      ..sort((a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
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
      ..sort((a, b) => (b['kmPerEvent'] as num).compareTo(a['kmPerEvent'] as num));
    stats['ranking_highway'] = (stats['ranking_highway'] as List).take(10).toList();

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
    stats['leaderboard_total'] = (stats['leaderboard_total'] as List).take(10).toList();

    stats['leaderboard_weekly'] = userWeeklyMap.values.toList()
      ..sort((a, b) => (b['totalKm'] as num).compareTo(a['totalKm'] as num));
    stats['leaderboard_weekly'] = (stats['leaderboard_weekly'] as List).take(10).toList();

    stats['brand_options'] =
        brandMap.values.map((b) => {'key': b['id'], 'name': b['name']}).toList();

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
          'jerk': eventBreakdown['jerk'] > 0 ? totalKm / eventBreakdown['jerk'] : 0.0,
          'bump': eventBreakdown['bump'] > 0 ? totalKm / eventBreakdown['bump'] : 0.0,
          'wobble':
              eventBreakdown['wobble'] > 0 ? totalKm / eventBreakdown['wobble'] : 0.0,
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
        ..sort(
            (a, b) => (a['version'] as String).compareTo(b['version'] as String));
    }

    return stats;
  }

  // --- 辅助方法：依然使用本地基础库进行名称解析 (为了 UI 兼容) ---
  String getBrandName(String idOrName) {
    if (idOrName == 'Unknown') return 'Unknown';
    final brand = _mergedBrands.firstWhere(
      (b) =>
          b.cloudId == idOrName || b.name.toLowerCase() == idOrName.toLowerCase(),
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
    final list = _processedStats[groupByBrand ? 'ranking_brand' : 'ranking_version'] as List?;
    if (list == null) return [];
    
    return list.map((item) => _mapToBrandData(item)).toList();
  }

  List<BrandData> getScenarioRankingData({required String scenario, bool groupByBrand = true}) {
    // 移动端目前不支持按版本的场景排行，仅支持按品牌
    final list = _processedStats[scenario == 'city' ? 'ranking_city' : 'ranking_highway'] as List?;
    if (list == null) return [];

    return list.map((item) => _mapToBrandData(item)).toList();
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
    if (list == null) return VersionEvolutionData(brand: brandKey, evolution: []);

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
      return SymptomData(brand: brandKey, details: {}, counts: {}, totalKm: 0, tripCount: 0);
    }

    final rawDetails = data['details'] as Map<String, dynamic>? ?? {};
    final Map<String, double> details = rawDetails.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final rawCounts = data['counts'] as Map<String, dynamic>? ?? {};
    final Map<String, int> counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

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
    final list = _processedStats[weekly ? 'leaderboard_weekly' : 'leaderboard_total'] as List?;
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

class _MileageRecord {
  final String brand;
  double totalKm = 0;
  final Map<String, double> breakdown = {
    'congested': 0,
    'urban': 0,
    'smooth': 0,
    'highway': 0,
  };

  _MileageRecord(this.brand);
}

class _UserMileageRecord {
  final String userName;
  final String? avatarUrl;
  double totalKm = 0;
  int tripCount = 0;

  _UserMileageRecord(this.userName, this.avatarUrl);
}
