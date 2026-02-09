import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/storage/storage_service.dart';

/// 提供所有行程数据的 StreamProvider
/// 监听 Isar 数据库变化，实现自动刷新
final tripsProvider = StreamProvider<List<Trip>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.watchTrips();
});
