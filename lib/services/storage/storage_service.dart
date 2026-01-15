import 'dart:io';
import 'dart:async';
import 'dart:convert';
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

  // 使用唯一的实例名称，防止与其他插件冲突
  static const String _instanceName = 'puked_master_v2_db';

  Future<void> init() async {
    if (_isar != null && _isar!.isOpen) return;

    if (_initFuture != null) {
      await _initFuture;
      if (_isar != null && _isar!.isOpen) return;
    }

    _initFuture = _doInit();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _doInit() async {
    try {
      debugPrint('[Storage] 🟢 Initializing Isar (Instance: $_instanceName)...');
      
      var isar = Isar.getInstance(_instanceName);
      
      if (isar != null && isar.isOpen) {
        try {
          await isar.brands.count();
          _isar = isar;
          debugPrint('[Storage] 🟡 Existing instance is healthy.');
          return;
        } catch (e) {
          debugPrint('[Storage] ⚠️ Existing instance is a ZOMBIE: $e. Closing it...');
          try {
            await isar.close();
          } catch (_) {}
          isar = null;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      
      try {
        isar = await Isar.open(
          [
            TripSchema,
            TrajectoryPointSchema,
            RecordedEventSchema,
            BrandSchema,
            SoftwareVersionSchema
          ],
          directory: dir.path,
          name: _instanceName,
        );
      } catch (e) {
        debugPrint('[Storage] 🚨 Isar.open failed: $e');
        rethrow;
      }
      
      _isar = isar;
      debugPrint('[Storage] ✅ Isar opened successfully.');
      await seedInitialData();
    } catch (e, stack) {
      debugPrint('[Storage] ❌ Critical initialization error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Isar get _db {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError('StorageService: Isar is not ready.');
    }
    return _isar!;
  }

  Future<void> seedInitialData() async {
    final count = await _db.brands.count();
    if (count > 0) return;

    final initialBrands = [
      'Tesla', 'Xpeng', 'LiAuto', 'Nio', 'Xiaomi', 'Huawei', 'Zeekr', 'Onvo', 'Others'
    ];

    await _db.writeTxn(() async {
      for (var i = 0; i < initialBrands.length; i++) {
        final name = initialBrands[i];
        final brand = Brand()
          ..name = name
          ..displayName = name
          ..order = i
          ..isEnabled = true;
        await _db.brands.put(brand);
      }
    });
  }

  // --- 品牌与版本 ---

  Future<List<Brand>> getAllBrands() async {
    await init();
    return await _db.brands.where().sortByOrder().findAll();
  }

  Stream<List<Brand>> watchAllBrands() async* {
    await init();
    yield* _db.brands.where().sortByOrder().watch(fireImmediately: true);
  }

  Stream<List<Brand>> watchBrands() async* {
    await init();
    yield* _db.brands.filter().isEnabledEqualTo(true).sortByOrder().watch(fireImmediately: true);
  }

  Future<List<SoftwareVersion>> getVersionsForBrand(String brandName) async {
    await init();
    return await _db.softwareVersions
        .filter()
        .brand((q) => q.nameEqualTo(brandName))
        .findAll();
  }

  Stream<List<SoftwareVersion>> watchAllVersions() async* {
    await init();
    yield* _db.softwareVersions.where().watch(fireImmediately: true);
  }

  Future<void> addVersion(String brandName, String versionString, {String? cloudId, bool isCustom = true}) async {
    await init();
    final brand = await _db.brands.filter().nameEqualTo(brandName).findFirst();
    if (brand == null) return;
    final existing = await _db.softwareVersions.filter().versionStringEqualTo(versionString).and().brand((q) => q.nameEqualTo(brandName)).findFirst();
    if (existing != null) {
      if (cloudId != null && existing.cloudId != cloudId) {
        await _db.writeTxn(() async { existing.cloudId = cloudId; await _db.softwareVersions.put(existing); });
      }
      return;
    }
    await _db.writeTxn(() async {
      final version = SoftwareVersion()..versionString = versionString..cloudId = cloudId..isCustom = isCustom;
      version.brand.value = brand;
      await _db.softwareVersions.put(version);
      await version.brand.save();
    });
  }

  Future<void> updateBrandsFromRemote(List<Brand> remoteBrands) async {
    await init();
    await _db.writeTxn(() async {
      final remoteNames = remoteBrands.map((e) => e.name.toLowerCase().trim()).toSet();
      for (var remote in remoteBrands) {
        final cleanName = remote.name.trim();
        final local = await _db.brands.filter().cloudIdEqualTo(remote.cloudId).or().nameEqualTo(cleanName, caseSensitive: false).findFirst();
        if (local != null) {
          local.name = cleanName; local.cloudId = remote.cloudId; local.displayName = remote.displayName;
          local.logoUrl = remote.logoUrl; local.order = remote.order; local.isEnabled = remote.isEnabled;
          local.isCustom = remote.isCustom; local.updatedAt = remote.updatedAt;
          await _db.brands.put(local);
        } else {
          remote.name = cleanName; await _db.brands.put(remote);
        }
      }
    });
  }

  Future<void> cleanupDirtyMetadata() async {
    await init();
    await _db.writeTxn(() async {
      final allVersions = await _db.softwareVersions.where().findAll();
      final dirtyVersionIds = allVersions.where((v) => v.versionString.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(v.versionString)).map((v) => v.id).toList();
      if (dirtyVersionIds.isNotEmpty) await _db.softwareVersions.deleteAll(dirtyVersionIds);

      final allBrands = await _db.brands.where().findAll();
      final dirtyBrandIds = allBrands.where((b) => b.name.length == 15 && RegExp(r'^[a-z0-9]+$').hasMatch(b.name)).map((b) => b.id).toList();
      if (dirtyBrandIds.isNotEmpty) await _db.brands.deleteAll(dirtyBrandIds);
    });
  }

  // --- 行程记录 ---

  Future<Trip> startTrip({String? carModel, String? notes, String? algorithm}) async {
    await init();
    final packageInfo = await PackageInfo.fromPlatform();
    final trip = Trip()..uuid = const Uuid().v4()..startTime = DateTime.now()..carModel = carModel..notes = notes..appVersion = packageInfo.version..platform = Platform.operatingSystem..algorithm = algorithm;
    await _db.writeTxn(() async { await _db.trips.put(trip); });
    return trip;
  }

  Future<void> addTrajectoryPoint(int tripId, TrajectoryPoint point, {double? distance}) async {
    await init();
    await _db.writeTxn(() async {
      await _db.trajectoryPoints.put(point);
      final trip = await _db.trips.get(tripId);
      if (trip != null) {
        trip.trajectory.add(point);
        if (distance != null) { trip.distance = distance; await _db.trips.put(trip); }
        await trip.trajectory.save();
      }
    }, silent: true);
  }

  Future<void> saveEvent(int tripId, RecordedEvent event) async {
    await init();
    await _db.writeTxn(() async {
      await _db.recordedEvents.put(event);
      final trip = await _db.trips.get(tripId);
      if (trip != null) { trip.events.add(event); trip.eventCount++; await _db.trips.put(trip); await trip.events.save(); }
    });
  }

  Future<void> endTrip(int tripId) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.trips.get(tripId);
      if (trip != null) {
        trip.endTime = DateTime.now();
        // 行程结束时立即计算并缓存初步的 metrics
        trip.metricsJson = jsonEncode(trip.generateMetrics());
        await _db.trips.put(trip);
      }
    });
  }

  Future<List<Trip>> getAllTrips() async {
    await init();
    final trips = await _db.trips.where().sortByStartTimeDesc().findAll();
    for (final trip in trips) await trip.events.load();
    return trips;
  }

  Stream<List<Trip>> watchTrips() async* {
    try {
      await init();
      yield* _db.trips.where().sortByStartTimeDesc().watch(fireImmediately: true);
    } catch (e) {
      debugPrint('[Storage] Error in watchTrips: $e');
      yield [];
    }
  }

  Future<Trip?> getTripById(int id) async {
    await init();
    final trip = await _db.trips.get(id);
    if (trip != null) { await trip.trajectory.load(); await trip.events.load(); }
    return trip;
  }

  Future<Trip?> getTripByUuid(String uuid) async {
    await init();
    final trip = await _db.trips.filter().uuidEqualTo(uuid).findFirst();
    if (trip != null) { await trip.trajectory.load(); await trip.events.load(); }
    return trip;
  }

  Future<void> updateTripCloudId(int tripId, String cloudId, {Map<String, dynamic>? metrics}) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.trips.get(tripId);
      if (trip != null) {
        trip.cloudId = cloudId;
        trip.isUploaded = true;
        if (metrics != null) {
          trip.metricsJson = jsonEncode(metrics);
        }
        await _db.trips.put(trip);
      }
    });
  }

  Future<void> updateTripVehicleInfo(int tripId, {String? brand, String? brandRef, String? carModel, String? softwareVersion, String? softwareVersionRef}) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.trips.get(tripId);
      if (trip != null) {
        trip.brand = brand; trip.brand_ref = brandRef; trip.carModel = carModel;
        trip.softwareVersion = softwareVersion; trip.software_version_ref = softwareVersionRef;
        await _db.trips.put(trip);
      }
    });
  }

  Future<void> savePlaceholderTrip(Trip trip) async {
    await init();
    await _db.writeTxn(() async { await _db.trips.put(trip); });
  }

  Future<void> completePlaceholderTrip(int tripId, Map<String, dynamic> data) async {
    await init();
    debugPrint('[PukedSync] Entering completePlaceholderTrip for ID: $tripId');
    await _db.writeTxn(() async {
      debugPrint('[PukedSync] Started Isar Write Transaction for ID: $tripId');
      final trip = await _db.trips.get(tripId);
      if (trip == null) {
        debugPrint('[PukedSync] ERROR: Trip with ID $tripId not found in DB');
        return;
      }

      final metadata = data['metadata'] as Map<String, dynamic>?;
      if (metadata != null) {
        debugPrint('[PukedSync] Parsing metadata...');
        trip.endTime = metadata['end_time'] != null ? DateTime.parse(metadata['end_time']).toLocal() : null;
        trip.appVersion = metadata['app_version'] as String?;
        trip.platform = metadata['platform'] as String?;
        trip.algorithm = metadata['algorithm'] as String?;
        trip.notes = metadata['notes'] as String?;
      }

      // 1. 轨迹点解析 (增加防御性类型检查)
      final dynamic trajectoryRaw = data['trajectory'];
      debugPrint('[PukedSync] Parsing trajectory (type: ${trajectoryRaw.runtimeType})...');
      List<dynamic>? trajectoryData;
      if (trajectoryRaw is List) {
        trajectoryData = trajectoryRaw;
      } else if (trajectoryRaw is Map) {
        trajectoryData = (trajectoryRaw as Map).values.toList();
      }

      if (trajectoryData != null) {
        final List<TrajectoryPoint> points = [];
        for (final p in trajectoryData) {
          if (p is! Map) continue;
          points.add(TrajectoryPoint()
            ..timestamp = DateTime.fromMillisecondsSinceEpoch(((p['ts'] ?? 0) * 1000).toInt())
            ..lat = (p['lat'] as num? ?? 0).toDouble()
            ..lng = (p['lng'] as num? ?? 0).toDouble()
            ..altitude = (p['alt'] as num? ?? 0.0).toDouble()
            ..speed = (p['speed'] as num? ?? 0.0).toDouble()
            ..isLowConfidence = p['low_conf'] as bool?);
        }
        debugPrint('[PukedSync] Inserting ${points.length} trajectory points...');
        await _db.trajectoryPoints.putAll(points);
        trip.trajectory.addAll(points);
      }

      // 2. 事件解析 (增加防御性类型检查)
      final dynamic eventsRaw = data['events'];
      debugPrint('[PukedSync] Parsing events (type: ${eventsRaw.runtimeType})...');
      List<dynamic>? eventsData;
      if (eventsRaw is List) {
        eventsData = eventsRaw;
      } else if (eventsRaw is Map) {
        eventsData = (eventsRaw as Map).values.toList();
      }

      if (eventsData != null) {
        final List<RecordedEvent> events = [];
        for (final e in eventsData) {
          if (e is! Map) continue;
          final loc = e['location'] as Map<String, dynamic>?;
          final sensorFragment = e['sensor_fragment'] as Map<String, dynamic>?;
          
          final dynamic sensorDataRaw = sensorFragment?['data'];
          List<dynamic>? sensorDataList;
          if (sensorDataRaw is List) {
            sensorDataList = sensorDataRaw;
          } else if (sensorDataRaw is Map) {
            sensorDataList = (sensorDataRaw as Map).values.toList();
          }

          final event = RecordedEvent()
            ..uuid = (e['event_id'] ?? e['uuid'] ?? "") as String
            ..timestamp = DateTime.fromMillisecondsSinceEpoch(((e['timestamp'] ?? 0) * 1000).toInt())
            ..type = (e['type'] ?? "unknown") as String
            ..source = (e['source'] ?? "AUTO") as String
            ..lat = (loc?['lat'] as num?)?.toDouble()
            ..lng = (loc?['lng'] as num?)?.toDouble();

          if (sensorDataList != null) {
            event.sensorData = sensorDataList.map((s) {
              if (s is! Map) return SensorPointEmbedded();
              
              // 关键修复：防御性地处理 accel 和 gyro (防止 Map/List 混淆)
              final dynamic accelRaw = s['accel'];
              List<dynamic>? accel;
              if (accelRaw is List) {
                accel = accelRaw;
              } else if (accelRaw is Map) {
                accel = accelRaw.values.toList();
              }

              final dynamic gyroRaw = s['gyro'];
              List<dynamic>? gyro;
              if (gyroRaw is List) {
                gyro = gyroRaw;
              } else if (gyroRaw is Map) {
                gyro = gyroRaw.values.toList();
              }

              return SensorPointEmbedded()
                ..offsetMs = s['offset_ms'] as int?
                ..ax = (accel != null && accel.length >= 1) ? (accel[0] as num).toDouble() : (s['ax'] as num?)?.toDouble()
                ..ay = (accel != null && accel.length >= 2) ? (accel[1] as num).toDouble() : (s['ay'] as num?)?.toDouble()
                ..az = (accel != null && accel.length >= 3) ? (accel[2] as num).toDouble() : (s['az'] as num?)?.toDouble()
                ..gx = (gyro != null && gyro.length >= 1) ? (gyro[0] as num).toDouble() : (s['gx'] as num?)?.toDouble()
                ..gy = (gyro != null && gyro.length >= 2) ? (gyro[1] as num).toDouble() : (s['gy'] as num?)?.toDouble()
                ..gz = (gyro != null && gyro.length >= 3) ? (gyro[2] as num).toDouble() : (s['gz'] as num?)?.toDouble();
            }).toList();
          } else {
            event.sensorData = [];
          }
          events.add(event);
        }
        debugPrint('[PukedSync] Inserting ${events.length} events...');
        await _db.recordedEvents.putAll(events);
        trip.events.addAll(events);
      }

      trip.isLocalMissing = false;
      trip.isUploaded = true;
      
      // 如果本地还没有统计信息，或者需要从元数据中恢复备注
      if (trip.metricsJson == null) {
        trip.metricsJson = jsonEncode(trip.generateMetrics());
      }
      
      if (trip.notes == null || trip.notes!.isEmpty) {
        trip.notes = (metadata?['notes'] as String?) ?? "";
      }

      debugPrint('[PukedSync] Persisting trip object...');
      await _db.trips.put(trip);
      debugPrint('[PukedSync] Saving links...');
      await trip.trajectory.save();
      await trip.events.save();
      debugPrint('[PukedSync] Placeholder trip completed and persisted.');
    });
  }

  Future<void> deleteEvent(int tripId, int eventId) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.trips.get(tripId);
      final event = await _db.recordedEvents.get(eventId);
      if (trip != null && event != null) { trip.events.remove(event); if (trip.eventCount > 0) trip.eventCount--; await _db.trips.put(trip); await _db.recordedEvents.delete(eventId); await trip.events.save(); }
    });
  }

  Future<void> deleteTrips(List<int> ids) async {
    await init();
    await _db.writeTxn(() async {
      for (final id in ids) {
        final trip = await _db.trips.get(id);
        if (trip != null) {
          // 核心逻辑：如果已经上传到云端，删除本地时将其转为占位符，而不是彻底删除
          if (trip.isUploaded && trip.cloudId != null) {
            await trip.trajectory.load();
            await trip.events.load();
            
            // 删除关联的详细数据
            await _db.trajectoryPoints.deleteAll(trip.trajectory.map((e) => e.id).toList());
            await _db.recordedEvents.deleteAll(trip.events.map((e) => e.id).toList());
            
            // 重置行程为占位状态
            trip.isLocalMissing = true;
            await _db.trips.put(trip);
            await trip.trajectory.save();
            await trip.events.save();
            debugPrint('[Storage] Trip $id converted to placeholder instead of deletion.');
          } else {
            // 未上传或没云端 ID，执行彻底删除
            await trip.trajectory.load();
            await trip.events.load();
            await _db.trajectoryPoints.deleteAll(trip.trajectory.map((e) => e.id).toList());
            await _db.recordedEvents.deleteAll(trip.events.map((e) => e.id).toList());
            await _db.trips.delete(id);
            debugPrint('[Storage] Trip $id deleted permanently.');
          }
        }
      }
    });
  }
}
