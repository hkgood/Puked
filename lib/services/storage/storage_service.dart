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

  Future<void> init() async {
    if (_isar != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [TripSchema, TrajectoryPointSchema, RecordedEventSchema],
      directory: dir.path,
    );
  }

  Future<Trip> startTrip({String? carModel, String? notes}) async {
    await init();
    final trip = Trip()
      ..uuid = const Uuid().v4()
      ..startTime = DateTime.now()
      ..carModel = carModel
      ..notes = notes;

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
        await isar.trips.put(trip);
      }
    });
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
    return await _isar!.trips.where().sortByStartTimeDesc().findAll();
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
