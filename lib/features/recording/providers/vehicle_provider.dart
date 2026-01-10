import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/storage/storage_service.dart';

/// 监听所有可用品牌的 StreamProvider
final availableBrandsProvider = StreamProvider<List<Brand>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.watchBrands();
});

/// 根据品牌 ID 或名称获取显示名称的 Provider
final brandNameProvider = Provider.family<String, String>((ref, idOrNameRaw) {
  final idOrName = idOrNameRaw.trim();
  final brandsAsync = ref.watch(availableBrandsProvider);
  return brandsAsync.maybeWhen(
    data: (brands) {
      if (idOrName.isEmpty || idOrName.toLowerCase() == 'unknown') {
        return 'Unknown';
      }

      // 判定是否为 15 位的 PocketBase ID
      final isPbId = idOrName.length == 15 && !idOrName.contains(' ');

      final brand = brands.firstWhere(
        (b) =>
            b.cloudId == idOrName ||
            b.name.toLowerCase() == idOrName.toLowerCase(),
        orElse: () => Brand()..name = isPbId ? '' : idOrName,
      );

      if (brand.name.isEmpty && isPbId) return '...';
      return brand.displayName ?? brand.name;
    },
    orElse: () {
      final isPbId =
          idOrNameRaw.trim().length == 15 && !idOrNameRaw.contains(' ');
      return isPbId ? '...' : idOrNameRaw;
    },
  );
});

/// 监听所有可用版本的 StreamProvider
final allVersionsProvider = StreamProvider<List<SoftwareVersion>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  // 这里需要 StorageService 支持 watchAllVersions
  return storage.watchAllVersions();
});

/// 根据版本 ID 或字符串获取显示名称的 Provider
final versionNameProvider =
    Provider.family<String, String>((ref, idOrStringRaw) {
  final idOrString = idOrStringRaw.trim();
  final versionsAsync = ref.watch(allVersionsProvider);
  return versionsAsync.maybeWhen(
    data: (versions) {
      if (idOrString.isEmpty || idOrString.toLowerCase() == 'unknown') {
        return 'Unknown';
      }

      // 增强判定：PocketBase ID 是 15 位且不含点号（版本号通常带点）
      final isPbId = idOrString.length == 15 && !idOrString.contains('.');

      // 1. 尝试匹配 cloudId (最准确)
      final byId = versions.where((v) => v.cloudId == idOrString).toList();
      if (byId.isNotEmpty) return byId.first.versionString;

      // 2. 尝试匹配 versionString (用于老数据或自定义输入)
      final byString =
          versions.where((v) => v.versionString == idOrString).toList();
      if (byString.isNotEmpty) return byString.first.versionString;

      // 3. 如果没找到匹配，且判定是 ID，则绝对禁止返回 ID 字符串
      if (isPbId) {
        return '...';
      }

      // 4. 只有当判定不是 ID 时，才返回原字符串
      return idOrString;
    },
    // 加载或错误时，如果是 ID 则显示占位
    orElse: () {
      final isPbId =
          idOrStringRaw.trim().length == 15 && !idOrStringRaw.contains('.');
      return isPbId ? '...' : idOrStringRaw;
    },
  );
});

/// 根据品牌名称获取预设版本的 FutureProvider
final presetVersionsProvider =
    FutureProvider.family<List<SoftwareVersion>, String>(
        (ref, brandName) async {
  final storage = ref.read(storageServiceProvider);
  return await storage.getVersionsForBrand(brandName);
});
