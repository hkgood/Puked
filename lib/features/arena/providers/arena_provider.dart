import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/cloud_trip_service.dart';
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

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final cloudService = ref.read(cloudTripServiceProvider);
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

  // 监听云端公开行程 (Arena 只统计云端公开数据)
  final cloudTripsAsync = ref.watch(arenaCloudTripsProvider);
  final cloudTrips = cloudTripsAsync.when(
      data: (d) => d, loading: () => <Trip>[], error: (_, __) => <Trip>[]);

  return ArenaService(ref, brands, cloudTrips);
});

class ArenaService {
  final Ref _ref;
  final List<Brand> brands;
  final List<Trip> trips;

  ArenaService(this._ref, this.brands, this.trips);

  List<Brand> get availableBrands => brands;

  List<String> get _allBrands => brands.map((b) => b.name).toList();

  // 卡片1: Top 10 平均无负面体验里程 (km/Event)
  List<BrandData> getTop10Data({bool groupByBrand = true}) {
    if (trips.isEmpty) return [];

    final Map<String, List<Trip>> groups = {};

    for (final trip in trips) {
      final brandName = trip.brand;
      if (brandName == null ||
          brandName.isEmpty ||
          brandName.toLowerCase() == 'unknown') continue;

      String key;
      String? version;
      if (groupByBrand) {
        key = brandName;
      } else {
        version = trip.softwareVersion;
        if (version == null ||
            version.isEmpty ||
            version.toLowerCase() == 'unknown') continue;
        key = '$brandName|$version';
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

      final String brand = groupByBrand ? key : key.split('|')[0];
      final String? version = groupByBrand ? null : key.split('|')[1];

      result.add(BrandData(
        brand: brand,
        version: version,
        // 关键改进：如果 evt 为 0，表示“完美舒适度”，
        // 但为了防止坐标轴被撑爆，将其上限限制在 10km (或公里数本身，取小者)
        kmPerEvent: totalEvents == 0
            ? (totalDist > 10 ? 10.0 : totalDist)
            : totalDist / totalEvents,
      ));
    });

    final filtered = result.where((e) => (e.kmPerEvent ?? 0) > 0).toList();
    filtered
        .sort((a, b) => (b.kmPerEvent ?? 0.0).compareTo(a.kmPerEvent ?? 0.0));
    return filtered.take(10).toList();
  }

  VersionEvolutionData getEvolutionData(String brand) {
    final brandTrips = trips.where((t) => t.brand == brand).toList();
    if (brandTrips.isEmpty) {
      return VersionEvolutionData(brand: brand, evolution: []);
    }

    final Map<String, List<Trip>> versionGroups = {};
    for (final t in brandTrips) {
      final v = t.softwareVersion ?? 'Unknown';
      versionGroups.putIfAbsent(v, () => []).add(t);
    }

    final List<VersionPoint> points = [];
    versionGroups.forEach((version, group) {
      double totalDist = 0;
      int totalEvents = 0;
      for (final t in group) {
        totalDist += (t.distance / 1000.0);
        totalEvents += _getFilteredEventCount(t);
      }
      points.add(VersionPoint(
        version: version,
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

    return VersionEvolutionData(brand: brand, evolution: points);
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

  SymptomData getSymptomDetails(String brand, {String? version}) {
    final filteredTrips = trips.where((t) {
      final tripBrand = (t.brand ?? '').toLowerCase().trim();
      final targetBrand = brand.toLowerCase().trim();
      if (tripBrand != targetBrand) return false;
      if (version != null &&
          version.isNotEmpty &&
          t.softwareVersion != version) {
        return false;
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
      brand: brand,
      version: version,
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
      final brand = t.brand;
      if (brand == null || brand.isEmpty || brand.toLowerCase() == 'unknown')
        continue;

      final km = t.distance / 1000.0;
      if (!mileageMap.containsKey(brand)) {
        mileageMap[brand] = _MileageRecord(brand);
      }
      final record = mileageMap[brand]!;
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

    final List<BrandData> result = mileageMap.values
        .map((e) => BrandData(
              brand: e.brand,
              totalKm: e.totalKm,
              breakdown: e.breakdown,
            ))
        .toList();

    result.sort((a, b) => (b.totalKm ?? 0.0).compareTo(a.totalKm ?? 0.0));
    return result;
  }

  String getDefaultBrand() {
    final settings = _ref.read(settingsProvider);
    if (settings.brand != null && settings.brand!.isNotEmpty) {
      return settings.brand!;
    }
    if (_allBrands.isNotEmpty) {
      return _allBrands.first;
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
