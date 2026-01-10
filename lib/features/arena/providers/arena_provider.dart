import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/models/db_models.dart';
import '../models/arena_data.dart';

final arenaBrandsProvider = StreamProvider<List<Brand>>((ref) {
  final storage = ref.read(storageServiceProvider);
  return storage.watchBrands();
});

final arenaTripsProvider = StreamProvider<List<Trip>>((ref) {
  final storage = ref.read(storageServiceProvider);
  return storage.watchTrips();
});

/// 云端公开行程 Provider
final arenaCloudTripsProvider =
    StateNotifierProvider<ArenaCloudTripsNotifier, AsyncValue<List<Trip>>>(
        (ref) {
  return ArenaCloudTripsNotifier(ref);
});

class ArenaCloudTripsNotifier extends StateNotifier<AsyncValue<List<Trip>>> {
  final Ref ref;
  ArenaCloudTripsNotifier(this.ref) : super(const AsyncValue.loading());

  Future<void> refresh({bool force = false}) async {
    // 如果没有数据或者是强制刷新，显示加载状态
    if (!state.hasValue || force) {
      state = const AsyncValue.loading();
    }

    try {
      final cloudService = ref.read(cloudTripServiceProvider);
      final prefs = ref.read(sharedPreferencesProvider);

      // 如果不是强制刷新，先检查总数是否有变化
      if (!force) {
        final currentCount = await cloudService.getTotalPublicTripsCount();
        final lastCount = prefs.getInt('last_arena_total_trips') ?? -1;

        // 如果总数没变，且已经有数据，则跳过刷新
        if (currentCount != -1 && currentCount == lastCount && state.hasValue) {
          return;
        }

        // 更新记录的总数
        if (currentCount != -1) {
          await prefs.setInt('last_arena_total_trips', currentCount);
        }
      } else {
        // 强制刷新时，也尝试更新总数记录
        final currentCount = await cloudService.getTotalPublicTripsCount();
        if (currentCount != -1) {
          await prefs.setInt('last_arena_total_trips', currentCount);
        }
      }

      final trips = await cloudService.fetchPublicTrips();
      state = AsyncValue.data(trips);
    } catch (e, stack) {
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

  // 监听云端公开行程 (Arena 只统计云端公开数据)
  final cloudTripsAsync = ref.watch(arenaCloudTripsProvider);
  final cloudTrips = cloudTripsAsync.when(
      data: (d) => d, loading: () => <Trip>[], error: (_, __) => <Trip>[]);

  return ArenaService(ref, brands, versions, cloudTrips);
});

class ArenaService {
  final Ref _ref;
  final List<Brand> brands;
  final List<SoftwareVersion> versions;
  final List<Trip> trips;

  ArenaService(this._ref, this.brands, this.versions, this.trips);

  List<Brand> get availableBrands => brands;

  String getBrandName(String idOrName) {
    if (idOrName == 'Unknown') return 'Unknown';
    // 优先匹配 cloudId，然后匹配 name (忽略大小写)
    final brand = brands.firstWhere(
      (b) =>
          b.cloudId == idOrName ||
          b.name.toLowerCase() == idOrName.toLowerCase(),
      orElse: () => Brand()..name = idOrName,
    );
    return brand.displayName ?? brand.name;
  }

  String getVersionName(String idOrString) {
    if (idOrString == 'Unknown') return 'Unknown';
    final version = versions.firstWhere(
      (v) => v.cloudId == idOrString || v.versionString == idOrString,
      orElse: () => SoftwareVersion()..versionString = idOrString,
    );
    return version.versionString;
  }

  // 卡片1: Top 10 平均无负面体验里程 (km/Event)
  List<BrandData> getTop10Data({bool groupByBrand = true}) {
    return _calculateRanking(trips, groupByBrand: groupByBrand);
  }

  // --- 深度同步 Web 端：分场景排行榜 (城市 < 50km/h, 高速 >= 50km/h) ---
  List<BrandData> getScenarioRankingData(
      {required String scenario, bool groupByBrand = true}) {
    if (trips.isEmpty) return [];

    final filteredTrips = trips.where((t) {
      final avgSpeed = _calculateTripAvgSpeed(t);
      if (avgSpeed < 0 || avgSpeed > 200) return false;
      return scenario == 'city' ? avgSpeed < 50 : avgSpeed >= 50;
    }).toList();

    return _calculateRanking(filteredTrips, groupByBrand: groupByBrand);
  }

  String getCanonicalBrandKey(Trip t) {
    if (t.brand_ref != null && t.brand_ref!.isNotEmpty) return t.brand_ref!;
    if (t.brand == null ||
        t.brand!.isEmpty ||
        t.brand!.toLowerCase() == 'unknown') {
      return 'Unknown';
    }
    // 对于旧数据，尝试在本地品牌列表中查找匹配的名称
    final brandObj = brands.firstWhere(
      (b) => b.name.toLowerCase() == t.brand!.toLowerCase(),
      orElse: () => Brand()..name = t.brand!,
    );
    return brandObj.cloudId ?? brandObj.name;
  }

  String getCanonicalVersionKey(Trip t) {
    if (t.software_version_ref != null && t.software_version_ref!.isNotEmpty) {
      return t.software_version_ref!;
    }
    return t.softwareVersion ?? 'Unknown';
  }

  List<BrandData> _calculateRanking(List<Trip> sourceTrips,
      {bool groupByBrand = true}) {
    if (sourceTrips.isEmpty) return [];

    final Map<String, List<Trip>> groups = {};

    for (final trip in sourceTrips) {
      final brandKey = getCanonicalBrandKey(trip);
      if (brandKey == 'Unknown') continue;

      String key;
      if (groupByBrand) {
        key = brandKey;
      } else {
        final versionKey = getCanonicalVersionKey(trip);
        if (versionKey == 'Unknown') continue;
        key = '$brandKey|$versionKey';
      }

      groups.putIfAbsent(key, () => []).add(trip);
    }

    final List<BrandData> result = [];
    groups.forEach((key, groupTrips) {
      double totalDist = 0;
      int totalEvents = 0;
      for (final t in groupTrips) {
        totalDist += (t.distance / 1000.0);
        totalEvents += _getFilteredEventCount(t);
      }

      final String brandKey = groupByBrand ? key : key.split('|')[0];
      final String? versionKey = groupByBrand ? null : key.split('|')[1];

      final bNameForDisplay = getBrandName(brandKey);
      final vNameForDisplay =
          versionKey != null ? getVersionName(versionKey) : null;

      result.add(BrandData(
        brand: brandKey,
        brandName: bNameForDisplay,
        version: versionKey,
        versionName: vNameForDisplay, // 增加一个版本名字段（需要修改 BrandData 模型）
        totalKm: totalDist,
        totalEvents: totalEvents,
        kmPerEvent: totalEvents == 0
            ? (totalDist > 10 ? 10.0 : totalDist)
            : totalDist / totalEvents,
      ));
    });

    final filtered = result
        .where((e) => (e.totalKm ?? 0) >= 100) // 完全对齐 Web 端：里程需满 100km
        .toList();
    filtered
        .sort((a, b) => (b.kmPerEvent ?? 0.0).compareTo(a.kmPerEvent ?? 0.0));
    return filtered.take(10).toList();
  }

  double _calculateTripAvgSpeed(Trip t) {
    double durationHours = 0;
    Map<String, dynamic>? metrics;
    Map<String, dynamic>? metadata;

    if (t.notes != null && t.notes!.contains('{')) {
      try {
        final data = jsonDecode(t.notes!);
        metrics = data['metrics'] as Map<String, dynamic>?;
        metadata = data['metadata'] as Map<String, dynamic>?;
      } catch (_) {}
    }

    if (metadata != null || metrics != null) {
      final source = {...(metrics ?? {}), ...(metadata ?? {})};
      final startStr = source['start_time'];
      final endStr = source['end_time'];
      if (startStr != null && endStr != null) {
        try {
          final start = DateTime.parse(startStr.toString());
          final end = DateTime.parse(endStr.toString());
          if (end.isAfter(start)) {
            durationHours = end.difference(start).inSeconds / 3600.0;
          }
        } catch (_) {}
      }
    }

    if (durationHours <= 0 && t.endTime != null) {
      durationHours = t.endTime!.difference(t.startTime).inSeconds / 3600.0;
    }

    if (durationHours <= 0) {
      final source = {
        ...(metrics ?? {}),
        ...(metadata ?? {}),
        'duration_seconds':
            t.endTime != null ? t.endTime!.difference(t.startTime).inSeconds : 0
      };

      final seconds = double.tryParse((source['duration_seconds'] ??
                  source['duration_sec'] ??
                  source['duration_s'] ??
                  '0')
              .toString()) ??
          0.0;
      if (seconds > 0) {
        durationHours = seconds / 3600.0;
      } else {
        final mins = double.tryParse(
                (source['duration_minutes'] ?? source['duration_min'] ?? '0')
                    .toString()) ??
            0.0;
        if (mins > 0) durationHours = mins / 60.0;
      }
    }

    final km = t.distance / 1000.0;
    return durationHours > 0.01 ? km / durationHours : -1.0;
  }

  VersionEvolutionData getEvolutionData(String brandKey) {
    final brandTrips =
        trips.where((t) => getCanonicalBrandKey(t) == brandKey).toList();
    if (brandTrips.isEmpty) {
      return VersionEvolutionData(brand: brandKey, evolution: []);
    }

    final Map<String, List<Trip>> versionGroups = {};
    for (final t in brandTrips) {
      final v = getCanonicalVersionKey(t);
      versionGroups.putIfAbsent(v, () => []).add(t);
    }

    final List<VersionPoint> points = [];
    versionGroups.forEach((versionKey, group) {
      double totalDist = 0;
      int totalEvents = 0;
      for (final t in group) {
        totalDist += (t.distance / 1000.0);
        totalEvents += _getFilteredEventCount(t);
      }

      // 尝试查找版本字符串供显示
      String displayVersion = getVersionName(versionKey);

      points.add(VersionPoint(
        version: displayVersion,
        // 关键改进：如果 evt 为 0，表示“完美舒适度”，将其上限限制在 10km (或公里数本身，取小者)
        kmPerEvent: totalEvents == 0
            ? (totalDist > 10 ? 10.0 : totalDist)
            : totalDist / totalEvents,
      ));
    });

    // 关键修复：使用自然排序法排列版本号，确保 5.8.10 在 5.8.6 之后，旧版永远在左侧
    points.sort((a, b) {
      // 定义一个简单的版本号自然比较器
      return _compareVersions(a.version, b.version);
    });

    return VersionEvolutionData(brand: brandKey, evolution: points);
  }

  /// 版本号自然排序比较逻辑
  int _compareVersions(String v1, String v2) {
    if (v1 == 'Unknown') return -1;
    if (v2 == 'Unknown') return 1;

    final regExp = RegExp(r'(\d+)');
    final nums1 =
        regExp.allMatches(v1).map((m) => int.parse(m.group(0)!)).toList();
    final nums2 =
        regExp.allMatches(v2).map((m) => int.parse(m.group(0)!)).toList();

    for (var i = 0; i < nums1.length && i < nums2.length; i++) {
      if (nums1[i] != nums2[i]) return nums1[i].compareTo(nums2[i]);
    }
    return nums1.length.compareTo(nums2.length);
  }

  int _getFilteredEventCount(Trip t) {
    final Map<String, dynamic> source = {};
    source['event_count'] = t.eventCount;

    Map<String, dynamic>? metrics;
    if (t.notes != null && t.notes!.contains('"metrics":')) {
      try {
        final data = jsonDecode(t.notes!);
        metrics = data['metrics'] as Map<String, dynamic>?;
      } catch (_) {}
    }

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

  SymptomData getSymptomDetails(String brandKey, {String? version}) {
    final filteredTrips = trips.where((t) {
      if (getCanonicalBrandKey(t) != brandKey) return false;

      if (version != null && version.isNotEmpty) {
        if (getCanonicalVersionKey(t) != version) {
          return false;
        }
      }
      return true;
    }).toList();

    double totalKm = 0;
    final Map<String, int> typeCounts = {
      'rapidAcceleration': 0,
      'rapidDeceleration': 0,
      'jerk': 0,
      'bump': 0,
      'wobble': 0,
    };

    final keyMap = {
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
      'bump': ['bump', 'bump_event', 'bumps', 'bump_count'],
      'wobble': ['wobble', 'wobble_event', 'wobbles', 'wobble_count']
    };

    for (final t in filteredTrips) {
      double tripDistKm = t.distance / 1000.0;
      totalKm += tripDistKm;

      final Map<String, dynamic> source = {};
      source['brand'] = t.brand?.toLowerCase();
      source['software_version'] = t.softwareVersion?.toLowerCase();

      Map<String, dynamic>? metrics;
      if (t.notes != null && t.notes!.contains('"metrics":')) {
        try {
          final data = jsonDecode(t.notes!);
          metrics = data['metrics'] as Map<String, dynamic>?;
        } catch (_) {}
      } else if (t.notes != null && t.notes!.contains('"breakdown":')) {
        try {
          final data = jsonDecode(t.notes!);
          final breakdown = data['breakdown'] as Map<String, dynamic>?;
          if (breakdown != null) {
            breakdown.forEach((k, v) => source[k.toLowerCase()] = v);
          }
        } catch (_) {}
      }

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

      keyMap.forEach((mainKey, possibleKeys) {
        for (final k in possibleKeys) {
          if (source[k] != null) {
            final count = double.tryParse(source[k].toString())?.toInt() ?? 0;
            if (count > 0) {
              typeCounts[mainKey] = (typeCounts[mainKey] ?? 0) + count;
              break;
            }
          }
        }
      });
    }

    final Map<String, double> details = {};
    typeCounts.forEach((type, count) {
      details[type] = count == 0 ? totalKm : totalKm / count;
    });

    return SymptomData(
      brand: brandKey,
      brandName: getBrandName(brandKey),
      version: version,
      versionName: version != null ? getVersionName(version) : null,
      details: details,
      counts: typeCounts,
      totalKm: totalKm,
      tripCount: filteredTrips.length,
    );
  }

  // --- 核心修复：深度同步 Web 端的精细化里程统计 ---
  List<BrandData> getTotalMileageData() {
    const double speedCongestedThreshold = 20.0;
    const double speedUrbanThreshold = 50.0;
    const double speedSmoothThreshold = 80.0;

    final Map<String, _MileageRecord> mileageMap = {};

    for (final t in trips) {
      final brandKey = getCanonicalBrandKey(t);
      if (brandKey == 'Unknown') continue;

      final km = t.distance / 1000.0;
      if (!mileageMap.containsKey(brandKey)) {
        mileageMap[brandKey] = _MileageRecord(brandKey);
      }
      final record = mileageMap[brandKey]!;
      record.totalKm += km;

      // --- 贪婪时长解析 (完全对齐 Web 端 logic) ---
      double durationHours = 0;
      Map<String, dynamic>? metrics;
      Map<String, dynamic>? metadata;

      if (t.notes != null && t.notes!.contains('{')) {
        try {
          final data = jsonDecode(t.notes!);
          metrics = data['metrics'] as Map<String, dynamic>?;
          metadata = data['metadata'] as Map<String, dynamic>?;
        } catch (_) {}
      }

      // 1. 优先尝试解析 metadata 中的物理时间差 (最准确)
      if (metadata != null || metrics != null) {
        final source = {...(metrics ?? {}), ...(metadata ?? {})};
        final startStr = source['start_time'];
        final endStr = source['end_time'];
        if (startStr != null && endStr != null) {
          try {
            final start = DateTime.parse(startStr.toString());
            final end = DateTime.parse(endStr.toString());
            if (end.isAfter(start)) {
              durationHours = end.difference(start).inSeconds / 3600.0;
            }
          } catch (_) {}
        }
      }

      // 2. 如果时间戳解析失败且不是云端行程，用本地字段
      if (durationHours <= 0 && t.endTime != null) {
        durationHours = t.endTime!.difference(t.startTime).inSeconds / 3600.0;
      }

      // 3. 降级扫描各种时长秒数/分钟字段 (彻底兼容各品牌差异)
      if (durationHours <= 0) {
        final source = {
          ...(metrics ?? {}),
          ...(metadata ?? {}),
          'duration_seconds': t.endTime != null
              ? t.endTime!.difference(t.startTime).inSeconds
              : 0
        };

        final seconds = double.tryParse((source['duration_seconds'] ??
                    source['duration_sec'] ??
                    source['duration_s'] ??
                    '0')
                .toString()) ??
            0.0;
        if (seconds > 0) {
          durationHours = seconds / 3600.0;
        } else {
          final mins = double.tryParse(
                  (source['duration_minutes'] ?? source['duration_min'] ?? '0')
                      .toString()) ??
              0.0;
          if (mins > 0) durationHours = mins / 60.0;
        }
      }

      // 计算该行程平均速度
      final avgSpeed = durationHours > 0.01 ? km / durationHours : -1.0;

      // 根据均速将整段里程归入对应的“桶”
      if (avgSpeed < 0 || avgSpeed > 200) {
        record.breakdown['urban'] = (record.breakdown['urban'] ?? 0) + km;
      } else if (avgSpeed < speedCongestedThreshold) {
        record.breakdown['congested'] =
            (record.breakdown['congested'] ?? 0) + km;
      } else if (avgSpeed < speedUrbanThreshold) {
        record.breakdown['urban'] = (record.breakdown['urban'] ?? 0) + km;
      } else if (avgSpeed < speedSmoothThreshold) {
        record.breakdown['smooth'] = (record.breakdown['smooth'] ?? 0) + km;
      } else {
        record.breakdown['highway'] = (record.breakdown['highway'] ?? 0) + km;
      }
    }

    final List<BrandData> result = mileageMap.values.map((e) {
      final bNameForDisplay = getBrandName(e.brand);
      return BrandData(
        brand: e.brand,
        brandName: bNameForDisplay,
        totalKm: e.totalKm,
        breakdown: e.breakdown,
      );
    }).toList();

    result.sort((a, b) => (b.totalKm ?? 0.0).compareTo(a.totalKm ?? 0.0));
    return result;
  }

  // --- 用户里程贡献榜 ---
  List<UserLeaderboardData> getUserLeaderboard({bool weekly = false}) {
    if (trips.isEmpty) return [];

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // 使用 userId 作为 Key 进行聚合，而不是用户名
    final Map<String, _UserMileageRecord> userMap = {};

    for (final t in trips) {
      if (weekly && t.startTime.isBefore(sevenDaysAgo)) {
        continue;
      }

      // 如果 userId 缺失，则使用 'unknown_user'，但这种情况理论上不应该发生
      final uId = t.userId ?? 'unknown_user';

      if (!userMap.containsKey(uId)) {
        // 如果没有用户名，生成一个可读的临时名称，如 User-a1b2
        String displayName = t.userName ?? '';
        if (displayName.isEmpty) {
          if (uId.length > 4) {
            displayName = 'User-${uId.substring(uId.length - 4)}';
          } else {
            displayName = 'Anonymous';
          }
        }
        userMap[uId] = _UserMileageRecord(displayName, t.userAvatar);
      }

      final record = userMap[uId]!;
      record.totalKm += (t.distance / 1000.0);
      record.tripCount += 1;
    }

    final List<UserLeaderboardData> result = userMap.values
        .map((e) => UserLeaderboardData(
              userName: e.userName,
              avatarUrl: e.avatarUrl,
              totalKm: e.totalKm,
              tripCount: e.tripCount,
            ))
        .toList();

    result.sort((a, b) => b.totalKm.compareTo(a.totalKm));
    return result.take(10).toList(); // 只取前 10 名
  }

  String getDefaultBrand() {
    final settings = _ref.read(settingsProvider);
    if (settings.brandRef != null && settings.brandRef!.isNotEmpty) {
      return settings.brandRef!;
    }
    if (settings.brand != null && settings.brand!.isNotEmpty) {
      // 尝试解析名称为 ID
      final brandObj = brands.firstWhere(
        (b) => b.name.toLowerCase() == settings.brand!.toLowerCase(),
        orElse: () => Brand()..name = settings.brand!,
      );
      return brandObj.cloudId ?? brandObj.name;
    }
    if (availableBrands.isNotEmpty) {
      return availableBrands.first.cloudId ?? availableBrands.first.name;
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
