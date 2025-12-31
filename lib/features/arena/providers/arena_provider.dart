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
    StateNotifierProvider<ArenaCloudTripsNotifier, List<Trip>>((ref) {
  return ArenaCloudTripsNotifier(ref);
});

class ArenaCloudTripsNotifier extends StateNotifier<List<Trip>> {
  final Ref ref;
  ArenaCloudTripsNotifier(this.ref) : super([]);

  Future<void> refresh() async {
    final cloudService = ref.read(cloudTripServiceProvider);
    final trips = await cloudService.fetchPublicTrips();
    state = trips;
  }
}

final arenaProvider = Provider((ref) {
  // 监听品牌列表
  final brandsAsync = ref.watch(arenaBrandsProvider);
  final brands = brandsAsync.when(
      data: (d) => d, loading: () => <Brand>[], error: (_, __) => <Brand>[]);

  // 监听云端公开行程 (Arena 只统计云端公开数据)
  final cloudTrips = ref.watch(arenaCloudTripsProvider);

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
      if (brandName == null || brandName.isEmpty) continue;

      String key;
      String? version;
      if (groupByBrand) {
        key = brandName;
      } else {
        version = trip.softwareVersion;
        if (version == null || version.isEmpty) continue;
        key = '$brandName|$version';
      }

      groups.putIfAbsent(key, () => []).add(trip);
    }

    final List<BrandData> result = [];
    groups.forEach((key, groupTrips) {
      double totalDist = 0;
      int totalEvents = 0;
      for (final t in groupTrips) {
        // 数据库存储的是米，转换为公里进行统计
        totalDist += (t.distance / 1000.0);
        totalEvents += t.eventCount;
      }

      final String brand = groupByBrand ? key : key.split('|')[0];
      final String? version = groupByBrand ? null : key.split('|')[1];

      result.add(BrandData(
        brand: brand,
        version: version,
        // 如果没有事件，则返回总里程，代表目前为止表现完美
        kmPerEvent: totalEvents == 0 ? totalDist : totalDist / totalEvents,
      ));
    });

    // 过滤掉里程过小的记录（比如小于 0.1km），避免异常高的 km/Event
    final filtered = result.where((e) => (e.kmPerEvent ?? 0) > 0).toList();
    filtered
        .sort((a, b) => (b.kmPerEvent ?? 0.0).compareTo(a.kmPerEvent ?? 0.0));
    return filtered.take(10).toList();
  }

  // 卡片2: 版本负体验进化趋势
  VersionEvolutionData getEvolutionData(String brand) {
    final brandTrips = trips.where((t) => t.brand == brand).toList();
    if (brandTrips.isEmpty) {
      return VersionEvolutionData(brand: brand, evolution: []);
    }

    // 按版本分组
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
        totalEvents += t.eventCount;
      }
      points.add(VersionPoint(
        version: version,
        kmPerEvent: totalEvents == 0 ? totalDist : totalDist / totalEvents,
      ));
    });

    // 简单的版本排序：按该版本最早行程时间排序
    points.sort((a, b) {
      final firstA = brandTrips
          .firstWhere((t) => t.softwareVersion == a.version)
          .startTime;
      final firstB = brandTrips
          .firstWhere((t) => t.softwareVersion == b.version)
          .startTime;
      return firstA.compareTo(firstB);
    });

    return VersionEvolutionData(brand: brand, evolution: points);
  }

  // 卡片3: 负面体验类型详情 (km/TypeEvent)
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

    // 各种可能的 Key 映射矩阵 (全小写匹配)
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

      // 解析数据源
      final Map<String, dynamic> source = {};

      // 1. 扫描 Trip 根部
      source['brand'] = t.brand?.toLowerCase();
      source['software_version'] = t.softwareVersion?.toLowerCase();

      // 2. 解析 notes 中的 metrics (云端数据摘要)
      Map<String, dynamic>? metrics;
      if (t.notes != null && t.notes!.contains('"metrics":')) {
        try {
          final data = jsonDecode(t.notes!);
          metrics = data['metrics'] as Map<String, dynamic>?;
        } catch (_) {}
      } else if (t.notes != null && t.notes!.contains('"breakdown":')) {
        // 兼容旧格式
        try {
          final data = jsonDecode(t.notes!);
          final breakdown = data['breakdown'] as Map<String, dynamic>?;
          if (breakdown != null) {
            breakdown.forEach((k, v) => source[k.toLowerCase()] = v);
          }
        } catch (_) {}
      }

      if (metrics != null) {
        // 如果存在 metrics 摘要，优先使用它
        metrics.forEach((k, v) => source[k.toLowerCase()] = v);
        final breakdown = metrics['event_breakdown'];
        if (breakdown is Map<String, dynamic>) {
          breakdown.forEach((k, v) => source[k.toLowerCase()] = v);
        }
      } else if (t.id != 0) {
        // 只有在没有云端 metrics 摘要时，才使用本地事件详情（针对未上传的本地行程）
        for (final event in t.events) {
          final type = event.type;
          source[type.toLowerCase()] = (source[type.toLowerCase()] ?? 0) + 1;
        }
      }

      // 累加每个类型的数量
      keyMap.forEach((mainKey, possibleKeys) {
        for (final k in possibleKeys) {
          if (source[k] != null) {
            // 【关键修复】使用 double.tryParse().toInt() 以兼容可能被解析为浮点数的 JSON 数值
            final count = double.tryParse(source[k].toString())?.toInt() ?? 0;
            if (count > 0) {
              typeCounts[mainKey] = (typeCounts[mainKey] ?? 0) + count;
              break; // 匹配到一个 Key 就跳过该类型的其他 Key
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

  // 卡片1.5: 总里程排名
  List<BrandData> getTotalMileageData() {
    final Map<String, double> mileageMap = {};
    for (final t in trips) {
      final b = t.brand;
      if (b == null || b.isEmpty) continue;
      // 转换为公里存储
      mileageMap[b] = (mileageMap[b] ?? 0) + (t.distance / 1000.0);
    }

    final List<BrandData> result = mileageMap.entries
        .map((e) => BrandData(
              brand: e.key,
              totalKm: e.value,
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
