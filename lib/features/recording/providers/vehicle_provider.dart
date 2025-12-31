import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/storage/storage_service.dart';

/// 监听所有可用品牌的 StreamProvider
final availableBrandsProvider = StreamProvider<List<Brand>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.watchBrands();
});

/// 根据品牌名称获取预设版本的 FutureProvider
final presetVersionsProvider =
    FutureProvider.family<List<SoftwareVersion>, String>(
        (ref, brandName) async {
  final storage = ref.read(storageServiceProvider);
  return await storage.getVersionsForBrand(brandName);
});
