import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  Isar? _isar;
  Future<void>? _initFuture;

  Future<void> init() async {
    if (_isar != null) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    try {
      final existing = Isar.getInstance();
      if (existing != null) {
        _isar = existing;
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [
          TripSchema,
          TrajectoryPointSchema,
          RecordedEventSchema,
          BrandSchema,
          SoftwareVersionSchema
        ],
        directory: dir.path,
      );
      await seedInitialData();
    } catch (e) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> seedInitialData() async {
    final count = await _isar!.brands.count();
    if (count > 0) return;

    final initialBrands = [
      'Tesla',
      'Xpeng',
      'LiAuto',
      'Nio',
      'Xiaomi',
      'Huawei',
      'Zeekr',
      'Onvo',
      'ApolloGo',
      'PONYai',
      'WeRide',
      'Waymo',
      'Zoox',
      'Wayve',
      'Momenta',
      'Nvidia',
      'Horizon',
      'Deeproute',
      'Leapmotor',
      'Others'
    ];

    await _isar!.writeTxn(() async {
      for (var i = 0; i < initialBrands.length; i++) {
        final name = initialBrands[i];
        final brand = Brand()
          ..name = name
          ..displayName = name
          ..logoUrl = null // 初始使用本地资产逻辑，后续同步更新为远程 URL
          ..order = i
          ..isCustom = false;
        await _isar!.brands.put(brand);
      }
    });
  }

  Future<List<Brand>> getAllBrands() async {
    await init();
    return await _isar!.brands
        .filter()
        .isEnabledEqualTo(true)
        .sortByOrder()
        .findAll();
  }

  /// 监听品牌表的变化
  Stream<List<Brand>> watchBrands() async* {
    await init();
    yield* _isar!.brands
        .filter()
        .isEnabledEqualTo(true)
        .sortByOrder()
        .watch(fireImmediately: true);
  }

  Future<List<SoftwareVersion>> getVersionsForBrand(String brandName) async {
    await init();
    final brand =
        await _isar!.brands.filter().nameEqualTo(brandName).findFirst();
    if (brand == null) return [];

    return await _isar!.softwareVersions
        .filter()
        .brand((q) => q.nameEqualTo(brandName))
        .and()
        .isEnabledEqualTo(true)
        .findAll();
  }

  Future<void> addBrand(Brand brand) async {
    await init();
    await _isar!.writeTxn(() async {
      await _isar!.brands.put(brand);
    });
  }

  Future<void> addVersion(String brandName, String versionString,
      {bool isCustom = true}) async {
    await init();
    final brand =
        await _isar!.brands.filter().nameEqualTo(brandName).findFirst();
    if (brand == null) return;

    // 检查版本是否已存在，防止重复
    final existing = await _isar!.softwareVersions
        .filter()
        .versionStringEqualTo(versionString)
        .and()
        .brand((q) => q.nameEqualTo(brandName))
        .findFirst();
    if (existing != null) return;

    await _isar!.writeTxn(() async {
      final version = SoftwareVersion()
        ..versionString = versionString
        ..isCustom = isCustom;
      version.brand.value = brand;
      await _isar!.softwareVersions.put(version);
      await version.brand.save();
    });
  }

  /// 从远程同步更新品牌数据（全量对齐）
  Future<void> updateBrandsFromRemote(List<Brand> remoteBrands) async {
    await init();
    await _isar!.writeTxn(() async {
      final remoteNames = remoteBrands.map((e) => e.name).toSet();

      // 1. 更新或新增云端返回的品牌
      for (var remote in remoteBrands) {
        final local =
            await _isar!.brands.filter().nameEqualTo(remote.name).findFirst();

        if (local != null) {
          local.displayName = remote.displayName;
          local.logoUrl = remote.logoUrl;
          local.order = remote.order;
          local.isEnabled = remote.isEnabled;
          local.isCustom = remote.isCustom;
          local.updatedAt = remote.updatedAt;
          await _isar!.brands.put(local);
        } else {
          await _isar!.brands.put(remote);
        }
      }

      // 2. 【关键】处理本地多余的旧数据
      // 如果本地品牌在云端不存在，且不是用户自定义的，则将其设为禁用
      final allLocalBrands = await _isar!.brands.where().findAll();
      for (var local in allLocalBrands) {
        if (!remoteNames.contains(local.name) && !local.isCustom) {
          local.isEnabled = false;
          await _isar!.brands.put(local);
        }
      }
    });
  }

  Future<Trip> startTrip(
      {String? carModel, String? notes, String? algorithm}) async {
    await init();
    final packageInfo = await PackageInfo.fromPlatform();
    final trip = Trip()
      ..uuid = const Uuid().v4()
      ..startTime = DateTime.now()
      ..carModel = carModel
      ..notes = notes
      ..appVersion = packageInfo.version
      ..platform = Platform.operatingSystem
      ..algorithm = algorithm;

    await _isar!.writeTxn(() async {
      await _isar!.trips.put(trip);
    });
    return trip;
  }

  Future<void> addTrajectoryPoint(int tripId, TrajectoryPoint point,
      {double? distance}) async {
    final isar = _isar;
    if (isar == null) return;
    // 使用非阻塞事务并减少频繁写入带来的 UI 抖动
    await isar.writeTxn(() async {
      await isar.trajectoryPoints.put(point);
      final trip = await isar.trips.get(tripId);
      if (trip != null) {
        trip.trajectory.add(point);
        if (distance != null) {
          trip.distance = distance;
          await isar.trips.put(trip);
        }
        await trip.trajectory.save();
      }
    }, silent: true);
  }

  Future<void> saveEvent(int tripId, RecordedEvent event) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.recordedEvents.put(event);
      final trip = await isar.trips.get(tripId);
      if (trip != null) {
        trip.events.add(event);
        trip.eventCount++;
        await isar.trips.put(trip);
        await trip.events.save();
      }
    });
  }

  Future<void> endTrip(int tripId) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final trip = await isar.trips.get(tripId);
      if (trip != null) {
        trip.endTime = DateTime.now();
        await isar.trips.put(trip);
      }
    });
  }

  Future<void> updateTripCloudId(int tripId, String cloudId) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final trip = await isar.trips.get(tripId);
      if (trip != null) {
        trip.cloudId = cloudId;
        trip.isUploaded = true;
        await isar.trips.put(trip);
      }
    });
  }

  /// 批量根据云端 UUID 列表同步本地上传状态
  /// [cloudUuids] 云端存在的 UUID 列表
  /// 返回本地状态发生变化的行程数量
  Future<int> syncTripsStatus(List<String> cloudUuids) async {
    final isar = _isar;
    if (isar == null) return 0;
    int changeCount = 0;

    final cloudSet = cloudUuids.toSet();

    await isar.writeTxn(() async {
      final allTrips = await isar.trips.where().findAll();

      for (final trip in allTrips) {
        final shouldBeUploaded = cloudSet.contains(trip.uuid);

        if (trip.isUploaded != shouldBeUploaded) {
          trip.isUploaded = shouldBeUploaded;
          // 如果云端不存在了，也清理掉本地存储的 cloudId
          if (!shouldBeUploaded) {
            trip.cloudId = null;
          }
          await isar.trips.put(trip);
          changeCount++;
        }
      }
    });
    return changeCount;
  }

  Future<void> updateTripVehicleInfo(int tripId,
      {String? brand, String? carModel, String? softwareVersion}) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final trip = await isar.trips.get(tripId);
      if (trip != null) {
        trip.brand = brand;
        trip.carModel = carModel;
        trip.softwareVersion = softwareVersion;
        await isar.trips.put(trip);
      }
    });
  }

  Future<List<Trip>> getAllTrips() async {
    await init();
    final trips = await _isar!.trips.where().sortByStartTimeDesc().findAll();
    // 预加载关联数据（如果需要）
    for (final trip in trips) {
      await trip.events.load();
    }
    return trips;
  }

  /// 监听所有行程变化
  Stream<List<Trip>> watchTrips() async* {
    await init();
    // 监听 trips 集合的变化
    yield* _isar!.trips
        .where()
        .sortByStartTimeDesc()
        .watch(fireImmediately: true)
        .asyncMap((trips) async {
      // 加载每个行程的关联事件，以便进行统计
      for (final trip in trips) {
        await trip.events.load();
      }
      return trips;
    });
  }

  Future<Trip?> getTripById(int id) async {
    await init();
    final trip = await _isar!.trips.get(id);
    if (trip != null) {
      await trip.trajectory.load();
      await trip.events.load();
    }
    return trip;
  }

  Future<Trip?> getTripByUuid(String uuid) async {
    await init();
    final trip = await _isar!.trips.filter().uuidEqualTo(uuid).findFirst();
    if (trip != null) {
      await trip.trajectory.load();
      await trip.events.load();
    }
    return trip;
  }

  /// 保存一个占位行程（仅元数据）
  Future<void> savePlaceholderTrip(Trip trip) async {
    await init();
    await _isar!.writeTxn(() async {
      await _isar!.trips.put(trip);
    });
  }

  /// 将占位行程补充完整数据
  Future<void> completePlaceholderTrip(
      int tripId, Map<String, dynamic> data) async {
    debugPrint('[PukedSync] Starting to complete placeholder trip: $tripId');
    await init();
    final isar = _isar!;

    try {
      await isar.writeTxn(() async {
        final trip = await isar.trips.get(tripId);
        if (trip == null) {
          debugPrint('[PukedSync] Error: Trip not found in DB: $tripId');
          return;
        }

        final metadata = data['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          trip.endTime = metadata['end_time'] != null
              ? DateTime.parse(metadata['end_time'])
              : null;
          trip.appVersion = metadata['app_version'] as String?;
          trip.platform = metadata['platform'] as String?;
          trip.algorithm = metadata['algorithm'] as String?;
          trip.notes = metadata['notes'] as String?;
        }

        // 1. 轨迹点解析 (增加 num 转换 double 的安全性)
        final trajectoryData = data['trajectory'] as List<dynamic>?;
        if (trajectoryData != null) {
          final List<TrajectoryPoint> points = [];
          for (final p in trajectoryData) {
            final point = TrajectoryPoint()
              ..timestamp =
                  DateTime.fromMillisecondsSinceEpoch((p['ts'] * 1000).toInt())
              ..lat = (p['lat'] as num).toDouble()
              ..lng = (p['lng'] as num).toDouble()
              ..altitude = (p['alt'] as num? ?? 0.0).toDouble() // 修复：必须赋初值，否则 late 变量会崩溃
              ..speed = (p['speed'] as num? ?? 0.0).toDouble() // 增加：防御性处理
              ..isLowConfidence = p['low_conf'] as bool?;
            points.add(point);
          }
          await isar.trajectoryPoints.putAll(points);
          trip.trajectory.addAll(points);
          debugPrint('[PukedSync] Restored ${points.length} trajectory points');
        }

        // 2. 事件解析
        final eventsData = data['events'] as List<dynamic>?;
        if (eventsData != null) {
          final List<RecordedEvent> events = [];
          for (final e in eventsData) {
            final location = e['location'] as Map<String, dynamic>?;
            final sensorFragment = e['sensor_fragment'] as Map<String, dynamic>?;
            final sensorData = sensorFragment?['data'] as List<dynamic>?;

            final event = RecordedEvent()
              ..uuid = e['event_id'] as String
              ..timestamp = DateTime.fromMillisecondsSinceEpoch(
                  (e['timestamp'] * 1000).toInt())
              ..type = e['type'] as String
              ..source = e['source'] as String
              ..lat = (location?['lat'] as num?)?.toDouble()
              ..lng = (location?['lng'] as num?)?.toDouble()
              ..sensorData = sensorData?.map((s) {
                    final accel = s['accel'] as Map<String, dynamic>?;
                    final gyro = s['gyro'] as Map<String, dynamic>?;
                    final mag = s['mag'] as Map<String, dynamic>?;
                    return SensorPointEmbedded()
                      ..offsetMs = s['offset_ms'] as int?
                      ..ax = (accel?['x'] as num?)?.toDouble()
                      ..ay = (accel?['y'] as num?)?.toDouble()
                      ..az = (accel?['z'] as num?)?.toDouble()
                      ..gx = (gyro?['x'] as num?)?.toDouble()
                      ..gy = (gyro?['y'] as num?)?.toDouble()
                      ..gz = (gyro?['z'] as num?)?.toDouble()
                      ..mx = (mag?['x'] as num?)?.toDouble()
                      ..my = (mag?['y'] as num?)?.toDouble()
                      ..mz = (mag?['z'] as num?)?.toDouble();
                  }).toList() ??
                  [];
            events.add(event);
          }
          await isar.recordedEvents.putAll(events);
          trip.events.addAll(events);
          debugPrint('[PukedSync] Restored ${events.length} events');
        }

        // 3. 状态翻转 (核心：清除 [CLOUD_ONLY] 标记)
        trip.isLocalMissing = false;
        trip.isUploaded = true;
        // 如果云端没有备注，则设为空字符串，确保不再是 [CLOUD_ONLY]
        trip.notes = (metadata?['notes'] as String?) ?? "";
        
        await isar.trips.put(trip);
        await trip.trajectory.save();
        await trip.events.save();
        debugPrint('[PukedSync] Placeholder trip completed and persisted.');
      });
    } catch (e) {
      debugPrint('[PukedSync] Critical error in completePlaceholderTrip: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(int tripId, int eventId) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      final trip = await isar.trips.get(tripId);
      final event = await isar.recordedEvents.get(eventId);

      if (trip != null && event != null) {
        // 从行程关联中移除
        trip.events.remove(event);
        if (trip.eventCount > 0) trip.eventCount--;

        await isar.trips.put(trip);
        await isar.recordedEvents.delete(eventId);
        await trip.events.save();
      }
    });
  }

  Future<void> deleteTrips(List<int> ids) async {
    final isar = _isar;
    if (isar == null) return;
    await isar.writeTxn(() async {
      for (final id in ids) {
        final trip = await isar.trips.get(id);
        if (trip != null) {
          // 清理关联的轨迹点和事件
          await trip.trajectory.load();
          await trip.events.load();
          await isar.trajectoryPoints
              .deleteAll(trip.trajectory.map((e) => e.id).toList());
          await isar.recordedEvents
              .deleteAll(trip.events.map((e) => e.id).toList());
          await isar.trips.delete(id);
        }
      }
    });
  }
}
