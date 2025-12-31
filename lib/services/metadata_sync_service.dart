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
      debugPrint('Starting metadata sync from cloud...');
      // 1. 从 PocketBase 获取所有品牌（包含已禁用的，以便更新本地状态）
      final remoteBrands = await _pbService.pb.collection('brands').getFullList(
            sort: 'order',
          );

      debugPrint('Cloud returned ${remoteBrands.length} brands.');

      // 2. 将云端数据转换为本地模型并存入 Isar
      final List<Brand> brandsToStore = [];
      int disabledCount = 0;
      for (var record in remoteBrands) {
        final isEnabled = record.getBoolValue('isEnabled');
        if (!isEnabled) disabledCount++;

        final brand = Brand()
          ..name = record.getStringValue('name')
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
      debugPrint(
          'Local database updated. (${brandsToStore.length} total, $disabledCount disabled)');

      // 3. 异步拉取版本信息
      for (var brandRecord in remoteBrands) {
        if (!brandRecord.getBoolValue('isEnabled')) continue;

        final brandName = brandRecord.getStringValue('name');
        final remoteVersions = await _pbService.pb
            .collection('software_versions')
            .getFullList(
                filter: 'brand = "${brandRecord.id}" && isEnabled = true');

        for (var vRecord in remoteVersions) {
          await _storage.addVersion(
            brandName,
            vRecord.getStringValue('versionString'),
            isCustom: vRecord.getBoolValue('isCustom'),
          );
        }
      }

      debugPrint('Metadata sync from cloud completed successfully.');
    } catch (e) {
      debugPrint('Error syncing metadata from cloud: $e');
    }
  }
}
