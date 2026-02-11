import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'isar_schemas.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  Isar? _isar;
  Future<void>? _initFuture;

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
      debugPrint(
          '[Storage] 🟢 Initializing Isar (Instance: $_instanceName)...');
      var isar = Isar.getInstance(_instanceName);
      if (isar != null && isar.isOpen) {
        try {
          await isar.collection<Brand>().count();
          _isar = isar;
          return;
        } catch (e) {
          await isar.close();
          isar = null;
        }
      }
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open(
        allIsarSchemas,
        directory: dir.path,
        name: _instanceName,
      );
      _isar = isar;
      await seedInitialData();
    } catch (e) {
      debugPrint('[Storage] ❌ Initialization error: $e');
      rethrow;
    }
  }

  Isar get _db {
    if (_isar == null || !_isar!.isOpen) throw StateError('Isar not ready');
    return _isar!;
  }

  Future<void> seedInitialData() async {
    final count = await _db.collection<Brand>().count();
    if (count > 0) return;
    final initialBrands = [
      'Tesla',
      'Xpeng',
      'LiAuto',
      'Nio',
      'Xiaomi',
      'Zeekr',
      'Huawei'
    ];
    await _db.writeTxn(() async {
      for (var name in initialBrands) {
        await _db.collection<Brand>().put(Brand()
          ..name = name
          ..displayName = name
          ..order = initialBrands.indexOf(name)
          ..isEnabled = true);
      }
    });
  }

  // --- 品牌与版本 ---

  Future<List<Brand>> getAllBrands() async {
    await init();
    return await _db
        .collection<Brand>()
        .where()
        .filter()
        .isEnabledEqualTo(true)
        .findAll();
  }

  Stream<List<Brand>> watchBrands() {
    return Stream.fromFuture(init()).asyncExpand((_) {
      return _db
          .collection<Brand>()
          .filter()
          .isEnabledEqualTo(true)
          .watch(fireImmediately: true);
    });
  }

  Stream<List<Brand>> watchAllBrands() {
    return Stream.fromFuture(init()).asyncExpand((_) {
      return _db.collection<Brand>().where().watch(fireImmediately: true);
    });
  }

  Stream<List<SoftwareVersion>> watchAllVersions({int? brandId}) {
    return Stream.fromFuture(init()).asyncExpand((_) {
      if (brandId != null) {
        return _db
            .collection<SoftwareVersion>()
            .filter()
            .brand((q) => q.idEqualTo(brandId))
            .watch(fireImmediately: true);
      }
      return _db
          .collection<SoftwareVersion>()
          .where()
          .watch(fireImmediately: true);
    });
  }

  Future<void> updateBrand(Brand brand) async {
    await init();
    await _db.writeTxn(() => _db.collection<Brand>().put(brand));
  }

  Future<void> deleteBrand(int id) async {
    await init();
    await _db.writeTxn(() => _db.collection<Brand>().delete(id));
  }

  Future<Brand?> getBrandByName(String name) async {
    await init();
    return await _db.collection<Brand>().filter().nameEqualTo(name).findFirst();
  }

  Future<Brand?> getBrandById(int id) async {
    await init();
    return await _db.collection<Brand>().get(id);
  }

  Future<void> addVersion(String brandName, String versionString,
      {bool isCustom = false, String? cloudId}) async {
    await init();
    debugPrint('🔍 [StorageService] addVersion called:');
    debugPrint('   brandName: $brandName');
    debugPrint('   versionString: $versionString');
    debugPrint('   cloudId: $cloudId');

    final brand = await _db
        .collection<Brand>()
        .filter()
        .nameEqualTo(brandName)
        .findFirst();

    if (brand != null) {
      debugPrint(
          '   ✅ Brand found: ${brand.name} (id: ${brand.id}, cloudId: ${brand.cloudId})');

      final existingV = await _db
          .collection<SoftwareVersion>()
          .filter()
          .brand((q) => q.idEqualTo(brand.id))
          .versionStringEqualTo(versionString)
          .findFirst();
      if (existingV == null) {
        debugPrint('   ℹ️ Version not exists, creating new...');
        final v = SoftwareVersion()
          ..versionString = versionString
          ..isCustom = isCustom
          ..cloudId = cloudId;
        v.brand.value = brand;
        await _db.writeTxn(() async {
          await _db.collection<SoftwareVersion>().put(v);
          await v.brand.save();
          // ✅ 同时维护 Brand → SoftwareVersion 的反向关系
          brand.versions.add(v);
          await brand.versions.save();
        });
        debugPrint('   ✅ Version created and linked to brand');
      } else {
        debugPrint('   ℹ️ Version already exists, updating...');
        if (cloudId != null) {
          existingV.cloudId = cloudId;
          existingV.isCustom = isCustom;
          await _db.writeTxn(() async {
            await _db.collection<SoftwareVersion>().put(existingV);
            // ✅ 确保反向关系存在
            await existingV.brand.load();
            if (existingV.brand.value?.id == brand.id) {
              await brand.versions.load();
              if (!brand.versions.any((v) => v.id == existingV.id)) {
                brand.versions.add(existingV);
                await brand.versions.save();
              }
            }
          });
          debugPrint('   ✅ Version updated');
        }
      }
    } else {
      debugPrint('   ❌ Brand not found for name: $brandName');
    }
  }

  Future<void> saveSoftwareVersion(SoftwareVersion version) async {
    await init();
    await _db.writeTxn(() async {
      await _db.collection<SoftwareVersion>().put(version);
      await version.brand.save();
    });
  }

  Future<List<SoftwareVersion>> getVersionsForBrand(int brandId) async {
    await init();
    final brand = await _db.collection<Brand>().get(brandId);
    if (brand != null) {
      await brand.versions.load();
      return brand.versions.toList();
    }
    return [];
  }

  Future<List<SoftwareVersion>> getVersionsForBrandName(
      String brandName) async {
    await init();
    final brand = await _db
        .collection<Brand>()
        .filter()
        .nameEqualTo(brandName)
        .findFirst();
    if (brand != null) {
      await brand.versions.load();
      return brand.versions.toList();
    }
    return [];
  }

  /// 通过品牌 cloudId 获取版本列表（更准确的查询方式）
  Future<List<SoftwareVersion>> getVersionsForBrandRef(String brandRef) async {
    await init();
    debugPrint('🔍 [StorageService] getVersionsForBrandRef called:');
    debugPrint('   brandRef: $brandRef');

    final brand = await _db
        .collection<Brand>()
        .filter()
        .cloudIdEqualTo(brandRef)
        .findFirst();

    if (brand != null) {
      debugPrint('   ✅ Brand found: ${brand.name} (id: ${brand.id})');
      await brand.versions.load();
      final versionsList = brand.versions.toList();
      debugPrint('   ✅ Loaded ${versionsList.length} versions');
      for (var v in versionsList) {
        debugPrint('      - ${v.versionString} (cloudId: ${v.cloudId})');
      }
      return versionsList;
    }

    debugPrint('   ❌ Brand not found for cloudId: $brandRef');
    return [];
  }

  /// 通过 cloudId 查询品牌对象
  Future<Brand?> getBrandByCloudId(String cloudId) async {
    await init();
    return await _db
        .collection<Brand>()
        .filter()
        .cloudIdEqualTo(cloudId)
        .findFirst();
  }

  /// 通过 cloudId 查询版本对象
  Future<SoftwareVersion?> getVersionByCloudId(String cloudId) async {
    await init();
    return await _db
        .collection<SoftwareVersion>()
        .filter()
        .cloudIdEqualTo(cloudId)
        .findFirst();
  }

  Future<SoftwareVersion?> getVersionByString(
      int brandId, String versionStr) async {
    await init();
    return await _db
        .collection<SoftwareVersion>()
        .filter()
        .brand((q) => q.idEqualTo(brandId))
        .versionStringEqualTo(versionStr)
        .findFirst();
  }

  Future<void> syncBrandsAndVersions(List<Map<String, dynamic>> brandsData,
      List<Map<String, dynamic>> versionsData) async {
    await init();
    await _db.writeTxn(() async {
      for (var bData in brandsData) {
        final name = bData['name'] as String;
        var existing = await _db
            .collection<Brand>()
            .filter()
            .nameEqualTo(name)
            .findFirst();
        if (existing == null) existing = Brand()..name = name;
        existing.displayName = bData['displayName'] ?? name;
        existing.logoUrl = bData['logoUrl'];
        existing.order = bData['order'] ?? 0;
        existing.isEnabled = bData['isEnabled'] ?? true;
        existing.cloudId = bData['id'];
        await _db.collection<Brand>().put(existing);
      }
      for (var vData in versionsData) {
        final brandName = vData['brandName'] as String;
        final versionStr = vData['versionString'] as String;
        final brand = await _db
            .collection<Brand>()
            .filter()
            .nameEqualTo(brandName)
            .findFirst();
        if (brand == null) continue;
        var existingV = await _db
            .collection<SoftwareVersion>()
            .filter()
            .brand((q) => q.idEqualTo(brand.id))
            .versionStringEqualTo(versionStr)
            .findFirst();
        if (existingV == null) {
          existingV = SoftwareVersion()..versionString = versionStr;
          existingV.brand.value = brand;
        }
        existingV.isEnabled = vData['isEnabled'] ?? true;
        existingV.cloudId = vData['id'];
        await _db.collection<SoftwareVersion>().put(existingV);
        await existingV.brand.save();
      }
    });
  }

  Future<void> updateBrandsFromRemote(List<Brand> brands) async {
    await init();
    await _db.writeTxn(() async {
      for (var b in brands) {
        var existing = await _db
            .collection<Brand>()
            .filter()
            .nameEqualTo(b.name)
            .findFirst();
        if (existing != null) b.id = existing.id;
        await _db.collection<Brand>().put(b);
      }
    });
  }

  Future<void> cleanupDirtyMetadata() async {}

  // --- 行程记录 ---

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
    await _db.writeTxn(() => _db.collection<Trip>().put(trip));
    return trip;
  }

  Future<void> addTrajectoryPoint(int tripId, TrajectoryPoint point,
      {double? distance}) async {
    await init();

    // 🔍 DEBUG: 检查传感器数据是否存在
    debugPrint('💾 [StorageService] addTrajectoryPoint called');
    debugPrint(
        '   Point has sensor data: ax=${point.ax}, ay=${point.ay}, az=${point.az}');
    debugPrint(
        '   Point has gyro data: gx=${point.gx}, gy=${point.gy}, gz=${point.gz}');

    await _db.writeTxn(() async {
      await _db.collection<TrajectoryPoint>().put(point);
      final trip = await _db.collection<Trip>().get(tripId);
      if (trip != null) {
        trip.trajectory.add(point);
        // ✅ 修复单位问题：distance参数是公里，需要转换为米存储
        if (distance != null) {
          trip.distance = distance * 1000; // 转换为米
          debugPrint(
              '   💾 Updated trip distance: ${trip.distance.toStringAsFixed(1)} m (${distance.toStringAsFixed(3)} km)');
        }
        await _db.collection<Trip>().put(trip);
        await trip.trajectory.save();
      }
    }, silent: true);

    debugPrint('✅ [StorageService] Trajectory point saved to database');
  }

  // 批量添加轨迹点（用于高频率传感器数据记录）
  final List<TrajectoryPoint> _pendingPoints = [];
  Timer? _batchFlushTimer;

  Future<void> addTrajectoryPointBatched(
      int tripId, TrajectoryPoint point) async {
    _pendingPoints.add(point);

    // 达到批量阈值或超时时批量写入
    if (_pendingPoints.length >= 20) {
      await _flushPendingPoints(tripId);
    } else {
      // 设置超时批量写入（最多延迟100ms）
      _batchFlushTimer?.cancel();
      _batchFlushTimer = Timer(const Duration(milliseconds: 100), () {
        _flushPendingPoints(tripId);
      });
    }
  }

  Future<void> _flushPendingPoints(int tripId) async {
    if (_pendingPoints.isEmpty) return;

    // ✅ 过滤掉无效GPS点（坐标接近0,0的点）
    final validPoints = _pendingPoints
        .where((p) => p.lat.abs() > 0.001 && p.lng.abs() > 0.001)
        .toList();

    _pendingPoints.clear();
    _batchFlushTimer?.cancel();

    if (validPoints.isEmpty) {
      debugPrint(
          '⚠️ [Batch] All ${_pendingPoints.length} points filtered out (invalid GPS coordinates)');
      return;
    }

    final pointsToSave = List<TrajectoryPoint>.from(validPoints);

    await init();
    await _db.writeTxn(() async {
      // 批量写入所有点
      await _db.collection<TrajectoryPoint>().putAll(pointsToSave);

      final trip = await _db.collection<Trip>().get(tripId);
      if (trip != null) {
        trip.trajectory.addAll(pointsToSave);
        await _db.collection<Trip>().put(trip);
        await trip.trajectory.save();
      }
    }, silent: true);

    debugPrint(
        '💾 [Batch] Flushed ${pointsToSave.length} valid trajectory points to database');
  }

  // 公开方法：强制flush所有待写入的点（在行程结束时调用）
  Future<void> flushPendingPoints(int tripId) async {
    await _flushPendingPoints(tripId);
  }

  Future<void> saveEvent(int tripId, RecordedEvent event) async {
    await init();
    await _db.writeTxn(() async {
      await _db.collection<RecordedEvent>().put(event);
      final trip = await _db.collection<Trip>().get(tripId);
      if (trip != null) {
        trip.events.add(event);
        if (event.source != 'PRO' && !event.type.startsWith('pro'))
          trip.eventCount++;
        await _db.collection<Trip>().put(trip);
        await trip.events.save();
      }
    });
  }

  Future<void> updateEvent(int tripId, int eventId,
      {String? type, String? voiceText, String? notes}) async {
    await init();
    await _db.writeTxn(() async {
      final event = await _db.collection<RecordedEvent>().get(eventId);
      if (event == null) return;

      final oldType = event.type;

      // 更新事件字段
      if (type != null) event.type = type;
      if (voiceText != null) event.voiceText = voiceText;
      if (notes != null) event.notes = notes;
      await _db.collection<RecordedEvent>().put(event);

      // 如果事件类型发生变化，更新 Trip 统计
      if (type != null && type != oldType) {
        final trip = await _db.collection<Trip>().get(tripId);
        if (trip != null) {
          _decrementEventStat(trip, oldType);
          _incrementEventStat(trip, type);
          await _db.collection<Trip>().put(trip);
          debugPrint('[EventStats] 事件类型变更: $oldType → $type');
        }
      }
    });
  }

  Future<void> deleteEvent(int tripId, int eventId) async {
    await init();
    await _db.writeTxn(() async {
      final event = await _db.collection<RecordedEvent>().get(eventId);
      if (event != null) {
        final trip = await _db.collection<Trip>().get(tripId);
        if (trip != null) {
          // 更新 eventCount（仅自动事件）
          if (event.source != 'PRO' && !event.type.startsWith('pro')) {
            trip.eventCount = math.max(0, trip.eventCount - 1);
          }

          // 更新事件统计
          _decrementEventStat(trip, event.type);

          await _db.collection<Trip>().put(trip);
          debugPrint('[EventStats] 删除事件: ${event.type}');
        }
        await _db.collection<RecordedEvent>().delete(eventId);
      }
    });
  }

  Future<void> endTrip(int tripId) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(tripId);
      if (trip != null) {
        trip.endTime = DateTime.now();

        // ✅ 计算并保存 metricsJson
        final duration = trip.endTime!.difference(trip.startTime);
        final durationMin = duration.inMinutes;
        final durationSec = duration.inSeconds;
        final distanceKm = trip.distance / 1000;
        final avgSpeedKmh =
            durationSec > 0 ? (distanceKm / (durationSec / 3600)) : 0.0;

        final metrics = {
          "distance_km": distanceKm.toStringAsFixed(2),
          "event_count": trip.eventCount,
          "duration_min": durationMin,
          "avg_speed_kmh": avgSpeedKmh.toStringAsFixed(1),
          "start_time": trip.startTime.toUtc().toIso8601String(),
          "end_time": trip.endTime!.toUtc().toIso8601String(),
        };

        trip.metricsJson = jsonEncode(metrics);

        debugPrint('✅ [EndTrip] Metrics calculated and saved:');
        debugPrint('   Distance: ${distanceKm.toStringAsFixed(2)} km');
        debugPrint('   Duration: $durationMin min');
        debugPrint('   Avg Speed: ${avgSpeedKmh.toStringAsFixed(1)} km/h');
        debugPrint('   Event Count: ${trip.eventCount}');

        await _db.collection<Trip>().put(trip);
      }
    });

    // 行程结束后，计算事件统计
    await calculateEventStats(tripId);
  }

  Future<void> updateTripCloudId(int id, String cloudId,
      {Map<String, dynamic>? metrics}) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(id);
      if (trip != null) {
        trip.cloudId = cloudId;
        trip.isUploaded = true;
        if (metrics != null) trip.metricsJson = jsonEncode(metrics);
        await _db.collection<Trip>().put(trip);
      }
    });
  }

  // 更新行程的云端metrics（用于同步时更新最新的统计数据）
  Future<void> updateTripWithCloudMetrics(
      int id, String cloudId, String metricsJsonStr) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(id);
      if (trip != null) {
        trip.cloudId = cloudId;
        trip.isUploaded = true;
        trip.cloudMetrics = metricsJsonStr; // 保存到cloudMetrics
        if (trip.metricsJson == null || trip.metricsJson!.isEmpty) {
          trip.metricsJson = metricsJsonStr; // 如果本地没有，也保存一份
        }
        await _db.collection<Trip>().put(trip);
      }
    });
  }

  Future<void> savePlaceholderTrip(Trip trip) async {
    await init();
    await _db.writeTxn(() async {
      // 检查是否已经存在该 UUID 的行程，防止重复创建占位符
      final existing = await _db
          .collection<Trip>()
          .filter()
          .uuidEqualTo(trip.uuid)
          .findFirst();
      if (existing == null) {
        await _db.collection<Trip>().put(trip);
      }
    });
  }

  Future<void> updateTripVehicleInfo(int id,
      {String? carModel,
      String? brand,
      String? softwareVersion,
      String? brandRef,
      String? softwareVersionRef}) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(id);
      if (trip != null) {
        if (carModel != null) trip.carModel = carModel;
        if (brand != null) trip.brand = brand;
        if (softwareVersion != null) trip.softwareVersion = softwareVersion;
        if (brandRef != null) trip.brand_ref = brandRef;
        if (softwareVersionRef != null)
          trip.software_version_ref = softwareVersionRef;
        await _db.collection<Trip>().put(trip);
      }
    });
  }

  Future<void> completePlaceholderTrip(
      int id, Map<String, dynamic> data) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(id);
      if (trip == null) return;

      final info = data['info'] as Map<String, dynamic>?;
      if (info != null) {
        trip.carModel = info['car_model'];
        trip.notes = info['notes'];
        trip.brand = info['brand'];
        trip.softwareVersion = info['software_version'];
        trip.appVersion = info['app_version'];
        trip.platform = info['platform'];
        trip.algorithm = info['algorithm'];
      }

      final trajectoryData = data['trajectory'] as List?;
      if (trajectoryData != null) {
        final List<TrajectoryPoint> points = [];
        for (var p in trajectoryData) {
          points.add(TrajectoryPoint()
            ..lat = (p['lat'] as num).toDouble()
            ..lng = (p['lng'] as num).toDouble()
            ..speed = (p['speed'] as num).toDouble()
            ..altitude = (p['altitude'] as num?)?.toDouble() ?? 0.0
            ..timestamp = DateTime.fromMillisecondsSinceEpoch(
                ((p['ts'] as num) * 1000).toInt())
            ..ax = (p['ax'] as num?)?.toDouble()
            ..ay = (p['ay'] as num?)?.toDouble()
            ..az = (p['az'] as num?)?.toDouble()
            ..gx = (p['gx'] as num?)?.toDouble()
            ..gy = (p['gy'] as num?)?.toDouble()
            ..gz = (p['gz'] as num?)?.toDouble());
        }
        await _db.collection<TrajectoryPoint>().putAll(points);
        trip.trajectory.addAll(points);
      }

      final eventsData = data['events'] as List?;
      if (eventsData != null) {
        final List<RecordedEvent> events = [];
        for (var e in eventsData) {
          final re = RecordedEvent()
            ..uuid = e['event_id'] ?? const Uuid().v4()
            ..timestamp = DateTime.fromMillisecondsSinceEpoch(
                ((e['timestamp'] as num) * 1000).toInt())
            ..type = e['type']
            ..source = e['source']
            ..voiceText = e['voice_text']
            ..notes = e['notes']
            ..speed = (e['location']?['speed'] as num?)?.toDouble()
            ..lat = (e['location']?['lat'] as num?)?.toDouble()
            ..lng = (e['location']?['lng'] as num?)?.toDouble();

          final sFragment = e['sensor_fragment']?['data'] as List?;
          re.sensorData = sFragment?.map((s) {
                final accel = s['accel'] as List?;
                final gyro = s['gyro'] as List?;
                final mag = s['mag'] as List?;
                return SensorPointEmbedded()
                  ..offsetMs = s['offset_ms']
                  ..ax = (accel?[0] as num?)?.toDouble()
                  ..ay = (accel?[1] as num?)?.toDouble()
                  ..az = (accel?[2] as num?)?.toDouble()
                  ..gx = (gyro?[0] as num?)?.toDouble()
                  ..gy = (gyro?[1] as num?)?.toDouble()
                  ..gz = (gyro?[2] as num?)?.toDouble()
                  ..mx = (mag?[0] as num?)?.toDouble()
                  ..my = (mag?[1] as num?)?.toDouble()
                  ..mz = (mag?[2] as num?)?.toDouble();
              }).toList() ??
              [];
          events.add(re);
        }
        await _db.collection<RecordedEvent>().putAll(events);
        trip.events.addAll(events);
      }

      trip.isLocalMissing = false;
      await _db.collection<Trip>().put(trip);
      await trip.trajectory.save();
      await trip.events.save();
    });

    // 下载完成后，计算事件统计
    await calculateEventStats(id);
  }

  Future<List<Trip>> getAllTrips() async {
    await init();
    return await _db.collection<Trip>().where().sortByStartTimeDesc().findAll();
  }

  Future<List<Trip>> getRecentTrips({int limit = 20}) async {
    await init();
    return await _db
        .collection<Trip>()
        .where()
        .sortByStartTimeDesc()
        .limit(limit)
        .findAll();
  }

  Stream<List<Trip>> watchTrips() {
    return Stream.fromFuture(init()).asyncExpand((_) {
      return _db
          .collection<Trip>()
          .where()
          .sortByStartTimeDesc()
          .watch(fireImmediately: true);
    });
  }

  Future<Trip?> getTripById(int id) async {
    await init();
    final trip = await _db.collection<Trip>().get(id);
    if (trip != null) {
      await trip.trajectory.load();
      await trip.events.load();
    }
    return trip;
  }

  Future<void> deleteTrips(List<int> ids) async {
    await init();
    await _db.writeTxn(() async {
      for (var id in ids) {
        final trip = await _db.collection<Trip>().get(id);
        if (trip != null) {
          await trip.trajectory.load();
          await trip.events.load();
          await _db
              .collection<TrajectoryPoint>()
              .deleteAll(trip.trajectory.map((p) => p.id).toList());
          await _db
              .collection<RecordedEvent>()
              .deleteAll(trip.events.map((e) => e.id).toList());
          await _db.collection<Trip>().delete(id);
        }
      }
    });
  }

  Future<void> updateTrip(Trip trip) async {
    await init();
    await _db.writeTxn(() => _db.collection<Trip>().put(trip));
  }

  Future<List<Trip>> getUnuploadedTrips() async {
    await init();
    return await _db
        .collection<Trip>()
        .filter()
        .isUploadedEqualTo(false)
        .findAll();
  }

  Future<void> markTripAsUploaded(int id, String cloudId) async {
    await updateTripCloudId(id, cloudId);
  }

  Future<Trip?> getTripByUuid(String uuid) async {
    await init();
    return await _db.collection<Trip>().filter().uuidEqualTo(uuid).findFirst();
  }

  Future<List<RecordedEvent>> getEventsForTrip(int tripId) async {
    await init();
    final trip = await _db.collection<Trip>().get(tripId);
    if (trip != null) {
      await trip.events.load();
      return trip.events.toList();
    }
    return [];
  }

  Future<List<TrajectoryPoint>> getTrajectoryForTrip(int tripId) async {
    await init();
    final trip = await _db.collection<Trip>().get(tripId);
    if (trip != null) {
      await trip.trajectory.load();
      return trip.trajectory.toList();
    }
    return [];
  }

  Future<void> clearAllData() async {
    await init();
    await _db.writeTxn(() async {
      await _db.collection<TrajectoryPoint>().clear();
      await _db.collection<RecordedEvent>().clear();
      await _db.collection<Trip>().clear();
    });
  }

  Future<int> getTripCount() async {
    await init();
    return await _db.collection<Trip>().count();
  }

  Future<double> getTotalDistance() async {
    await init();
    final trips = await _db.collection<Trip>().where().findAll();
    return trips.fold<double>(0.0, (prev, element) => prev + element.distance);
  }

  Future<int> getTotalEventCount() async {
    await init();
    final trips = await _db.collection<Trip>().where().findAll();
    return trips.fold<int>(0, (prev, element) => prev + element.eventCount);
  }
}

// ============== 事件统计相关函数 ==============
extension StorageServiceEventStats on StorageService {
  /// 获取空的统计数据结构
  Map<String, dynamic> _getEmptyStatsMap() {
    return {
      "auto": {
        "rapidAcceleration": 0,
        "rapidDeceleration": 0,
        "jerk": 0,
        "bump": 0,
        "wobble": 0,
      },
      "pro": {
        "proDisengagement": 0,
        "proViolation": 0,
        "proExperience": 0,
      },
      "manual": 0,
    };
  }

  /// 全量计算行程的事件统计（用于首次生成或重新计算）
  Future<void> calculateEventStats(int tripId) async {
    await init();
    await _db.writeTxn(() async {
      final trip = await _db.collection<Trip>().get(tripId);
      if (trip == null) return;

      // 确保事件已加载
      await trip.events.load();

      final stats = _getEmptyStatsMap();

      for (final event in trip.events) {
        _incrementEventStatInMap(stats, event.type);
      }

      trip.eventStatsJson = jsonEncode(stats);
      await _db.collection<Trip>().put(trip);

      debugPrint(
          '[EventStats] 全量计算完成: Trip ${trip.id}, Stats: ${trip.eventStatsJson}');
    });
  }

  /// 在统计 Map 中增加某个事件类型的计数
  void _incrementEventStatInMap(Map<String, dynamic> stats, String eventType) {
    if (stats['auto'].containsKey(eventType)) {
      stats['auto'][eventType]++;
    } else if (eventType.startsWith('pro')) {
      stats['pro'][eventType] = (stats['pro'][eventType] ?? 0) + 1;
    } else if (eventType == 'manual') {
      stats['manual']++;
    }
  }

  /// 在统计 Map 中减少某个事件类型的计数
  void _decrementEventStatInMap(Map<String, dynamic> stats, String eventType) {
    if (stats['auto'].containsKey(eventType)) {
      stats['auto'][eventType] =
          math.max(0, (stats['auto'][eventType] as int) - 1);
    } else if (eventType.startsWith('pro')) {
      stats['pro'][eventType] =
          math.max(0, ((stats['pro'][eventType] ?? 0) as int) - 1);
    } else if (eventType == 'manual') {
      stats['manual'] = math.max(0, (stats['manual'] as int) - 1);
    }
  }

  /// 增量更新：增加某个事件类型的统计
  void _incrementEventStat(Trip trip, String eventType) {
    final stats = trip.eventStats ?? _getEmptyStatsMap();
    _incrementEventStatInMap(stats, eventType);
    trip.eventStatsJson = jsonEncode(stats);
  }

  /// 增量更新：减少某个事件类型的统计
  void _decrementEventStat(Trip trip, String eventType) {
    final stats = trip.eventStats ?? _getEmptyStatsMap();
    _decrementEventStatInMap(stats, eventType);
    trip.eventStatsJson = jsonEncode(stats);
  }
}
