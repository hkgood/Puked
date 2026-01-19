import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/models/db_models.dart';
import 'package:http/http.dart' as http;

final metadataSyncServiceProvider = Provider((ref) {
  final pbService = ref.watch(pbServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return MetadataSyncService(pbService, storage);
});

class MetadataSyncService {
  final PocketBaseService _pbService;
  final StorageService _storage;

  MetadataSyncService(this._pbService, this._storage);

  final List<String> _initialBrands = [
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
    'Leapmotor'
  ];

  /// 将本地品牌数据同步到 PocketBase
  /// 注意：这需要 PocketBase 的 brands 集合具有 Create 权限，或者当前已登录管理员
  Future<void> syncBrandsToCloud() async {
    if (!_pbService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    for (var i = 0; i < _initialBrands.length; i++) {
      final brandName = _initialBrands[i];

      try {
        // 1. 检查品牌是否已存在
        final existing = await _pbService.pb.collection('brands').getList(
              filter: 'name = "$brandName"',
            );

        if (existing.items.isNotEmpty) {
          debugPrint('Brand $brandName already exists in cloud, skipping...');
          continue;
        }

        // 2. 加载本地 SVG 资产
        final assetPath = 'assets/logos/$brandName.svg';
        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List();

        // 3. 创建 MultipartFile
        final multipartFile = http.MultipartFile.fromBytes(
          'logo',
          bytes,
          filename: '$brandName.svg',
        );

        // 4. 上传到 PocketBase
        await _pbService.pb.collection('brands').create(
          body: {
            'name': brandName,
            'displayName': brandName,
            'order': i,
            'isEnabled': true,
            'isCustom': false,
          },
          files: [multipartFile],
        );

        debugPrint('Successfully uploaded $brandName to cloud.');
      } catch (e) {
        debugPrint('Error uploading $brandName: $e');
      }
    }
  }

  /// 从云端拉取品牌和版本数据并同步到本地 Isar
  Future<void> syncBrandsFromCloud() async {
    try {
      debugPrint('[MetadataSync] >>> ENTERING syncBrandsFromCloud');

      // 1. 清理脏数据
      debugPrint('[MetadataSync] Step 1: Cleaning dirty local metadata...');
      await _storage.cleanupDirtyMetadata();
      debugPrint('[MetadataSync] Step 1: Success.');

      // 2. 网络请求
      debugPrint('[MetadataSync] Step 2: Fetching brands from PocketBase...');
      final remoteBrands = await _pbService.pb.collection('brands').getFullList(
            sort: 'order',
          );
      debugPrint(
          '[MetadataSync] Step 2: Success. Cloud returned ${remoteBrands.length} brands.');

      // 3. 写入品牌
      debugPrint('[MetadataSync] Step 3: Updating local Brand table...');
      final List<Brand> brandsToStore = [];
      for (var record in remoteBrands) {
        final name = record.getStringValue('name').trim();
        final isEnabled = record.getBoolValue('isEnabled');

        final brand = Brand()
          ..name = name
          ..cloudId = record.id
          ..displayName = record.getStringValue('displayName')
          ..logoUrl = record.getStringValue('logo').isNotEmpty
              ? _pbService.pb.files
                  .getUrl(record, record.getStringValue('logo'))
                  .toString()
              : null
          ..order = record.getIntValue('order')
          ..isEnabled = isEnabled
          ..isCustom = record.getBoolValue('isCustom')
          ..updatedAt = DateTime.parse(record.get<String>('updated'));
        brandsToStore.add(brand);
      }

      await _storage.updateBrandsFromRemote(brandsToStore);
      debugPrint('[MetadataSync] Step 3: Local Brands updated.');

      // 4. 并行拉取版本
      debugPrint('[MetadataSync] Step 4: Starting parallel version sync...');
      int successCount = 0;
      int failCount = 0;

      await Future.wait(remoteBrands.map((brandRecord) async {
        final brandName = brandRecord.getStringValue('name').trim();
        try {
          final remoteVersions = await _pbService.pb
              .collection('software_versions')
              .getFullList(filter: 'brand = "${brandRecord.id}"');

          for (var vRecord in remoteVersions) {
            await _storage.addVersion(
              brandName,
              vRecord.getStringValue('versionString').trim(),
              cloudId: vRecord.id,
              isCustom: vRecord.getBoolValue('isCustom'),
            );
          }
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('[MetadataSync] !! Error for $brandName: $e');
        }
      }));

      debugPrint(
          '[MetadataSync] <<< EXITING syncBrandsFromCloud. Success: $successCount, Fail: $failCount');
    } catch (e, stack) {
      debugPrint(
          '[MetadataSync] !!! CRITICAL ERROR in syncBrandsFromCloud: $e');
      debugPrint('[MetadataSync] StackTrace: $stack');
    }
  }
}
