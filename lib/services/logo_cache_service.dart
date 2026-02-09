import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puked/services/pocketbase_service.dart';

/// Logo 缓存服务
///
/// 职责：
/// 1. 在 App 首次启动时，预加载所有已知品牌的云端 logo 到本地缓存
/// 2. 提供缓存命中检查和 logo 路径获取
/// 3. 增量更新：只下载缺失的 logo
class LogoCacheService {
  final PocketBaseService _pbService;
  final SharedPreferences _prefs;

  static const _cacheVersionKey = 'logo_cache_version';
  static const _currentCacheVersion = 2; // 版本号：每次有新 logo 时递增
  static const _preloadCompleteKey =
      'logo_preload_complete_v$_currentCacheVersion';

  // 已知本地内置的品牌（assets/logos/ 中的 SVG）
  static const Set<String> _localBrands = {
    'ApolloGo',
    'Deeproute',
    'Horizon',
    'Huawei',
    'Leapmotor',
    'LiAuto',
    'Momenta',
    'Nio',
    'Nvidia',
    'Onvo',
    'PONYai',
    'Tesla',
    'Waymo',
    'Wayve',
    'WeRide',
    'Xiaomi',
    'Xpeng',
    'Zeekr',
    'Zoox',
    'lynk&co',
    'others',
    'zyt',
  };

  LogoCacheService(this._pbService, this._prefs);

  /// 检查是否需要预加载
  bool get needsPreload {
    final cacheVersion = _prefs.getInt(_cacheVersionKey) ?? 0;
    if (cacheVersion < _currentCacheVersion) {
      return true; // 版本不匹配，需要重新预加载
    }
    return !(_prefs.getBool(_preloadCompleteKey) ?? false);
  }

  /// 预加载所有品牌 Logo
  ///
  /// 策略：
  /// 1. 本地已有的品牌（assets）直接跳过
  /// 2. 云端品牌的 logo 下载到应用缓存目录
  /// 3. 并发下载，限制最大并发数为 5
  Future<void> preloadLogos({
    Function(int current, int total, String brandName)? onProgress,
  }) async {
    try {
      debugPrint('[LogoCache] 开始预加载 Logo...');

      // 1. 获取所有品牌
      final records = await _pbService.pb.collection('brands').getFullList(
            sort: 'name',
          );

      debugPrint('[LogoCache] 找到 ${records.length} 个品牌');

      // 2. 获取缓存目录
      final cacheDir = await _getCacheDirectory();

      // 3. 筛选需要下载的品牌
      final needDownload = <Map<String, String>>[];
      for (final record in records) {
        final brandName = record.getStringValue('name');
        final logoFile = record.getStringValue('logo');

        if (brandName.isEmpty || logoFile.isEmpty) continue;

        // 如果是本地品牌，跳过
        if (_localBrands.contains(brandName)) {
          debugPrint('[LogoCache] 跳过本地品牌: $brandName');
          continue;
        }

        // 检查缓存是否存在
        final cachedFile = File('${cacheDir.path}/$brandName.svg');
        if (await cachedFile.exists()) {
          debugPrint('[LogoCache] 缓存已存在: $brandName');
          continue;
        }

        // 构建下载 URL
        final logoUrl = _pbService.pb.files.getUrl(record, logoFile).toString();
        needDownload.add({
          'name': brandName,
          'url': logoUrl,
          'path': cachedFile.path,
        });
      }

      if (needDownload.isEmpty) {
        debugPrint('[LogoCache] 所有 Logo 已缓存');
        await _markPreloadComplete();
        return;
      }

      debugPrint('[LogoCache] 需要下载 ${needDownload.length} 个 Logo');

      // 4. 并发下载（限制并发数为 5）
      int completed = 0;
      final total = needDownload.length;

      await _downloadWithConcurrencyLimit(
        needDownload,
        maxConcurrent: 5,
        onEach: (item, success) {
          completed++;
          if (success) {
            debugPrint('[LogoCache] [$completed/$total] 成功: ${item['name']}');
          } else {
            debugPrint('[LogoCache] [$completed/$total] 失败: ${item['name']}');
          }
          onProgress?.call(completed, total, item['name']!);
        },
      );

      // 5. 标记预加载完成
      await _markPreloadComplete();
      debugPrint('[LogoCache] 预加载完成！');
    } catch (e, stack) {
      debugPrint('[LogoCache] 预加载失败: $e');
      debugPrint(stack.toString());
    }
  }

  /// 获取 Logo 缓存路径（如果存在）
  Future<String?> getCachedLogoPath(String brandName) async {
    // 1. 优先检查本地 assets
    if (_localBrands.contains(brandName)) {
      return 'assets/logos/$brandName.svg';
    }

    // 2. 检查应用缓存目录
    final cacheDir = await _getCacheDirectory();
    final cachedFile = File('${cacheDir.path}/$brandName.svg');
    if (await cachedFile.exists()) {
      return cachedFile.path;
    }

    return null;
  }

  /// 下载单个 Logo 到缓存
  Future<bool> downloadLogo(String brandName, String logoUrl) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cachedFile = File('${cacheDir.path}/$brandName.svg');

      final response = await http.get(Uri.parse(logoUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        await cachedFile.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[LogoCache] 下载失败 ($brandName): $e');
      return false;
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      await _prefs.remove(_preloadCompleteKey);
      await _prefs.remove(_cacheVersionKey);
      debugPrint('[LogoCache] 缓存已清理');
    } catch (e) {
      debugPrint('[LogoCache] 清理缓存失败: $e');
    }
  }

  // ========== 内部方法 ==========

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final logoDir = Directory('${appDir.path}/logos');
    if (!await logoDir.exists()) {
      await logoDir.create(recursive: true);
    }
    return logoDir;
  }

  Future<void> _markPreloadComplete() async {
    await _prefs.setBool(_preloadCompleteKey, true);
    await _prefs.setInt(_cacheVersionKey, _currentCacheVersion);
  }

  Future<void> _downloadWithConcurrencyLimit(
    List<Map<String, String>> items, {
    required int maxConcurrent,
    required Function(Map<String, String> item, bool success) onEach,
  }) async {
    // 分批处理：每批最多 maxConcurrent 个
    for (int i = 0; i < items.length; i += maxConcurrent) {
      final batch = items.skip(i).take(maxConcurrent).toList();

      // 并发下载当前批次
      await Future.wait(
        batch.map((item) async {
          final success = await _downloadItem(item);
          onEach(item, success);
        }),
      );
    }
  }

  Future<bool> _downloadItem(Map<String, String> item) async {
    try {
      final response = await http.get(Uri.parse(item['url']!)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final file = File(item['path']!);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Provider
final logoCacheServiceProvider = Provider<LogoCacheService>((ref) {
  final pbService = ref.watch(pbServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return LogoCacheService(pbService, prefs);
});
