import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';
import '../features/recording/domain/algorithm_config.dart';
import 'pocketbase_service.dart';

class AlgorithmConfigService extends StateNotifier<AlgorithmConfig> {
  final PocketBase _pb;
  final SharedPreferences _prefs;
  static const String _storageKey = 'cached_algorithm_config';
  static const String _collectionName = 'algorithm_configs';

  AlgorithmConfigService(this._pb, this._prefs)
      : super(AlgorithmConfig.defaultConfig()) {
    _loadFromCache();
    // 异步尝试从云端更新，不阻塞初始化
    fetchAndSync();
  }

  void _loadFromCache() {
    final cached = _prefs.getString(_storageKey);
    if (cached != null) {
      try {
        final json = jsonDecode(cached);
        state = AlgorithmConfig.fromJson(json);
        debugPrint('Loaded AlgorithmConfig v${state.version} from cache');
      } catch (e) {
        debugPrint('Error loading cached AlgorithmConfig: $e');
      }
    }
  }

  Future<void> fetchAndSync() async {
    try {
      // 获取最新的一条配置记录 (按版本号或更新时间排序)
      final records = await _pb.collection(_collectionName).getList(
            page: 1,
            perPage: 1,
            sort: '-version',
          );

      if (records.items.isNotEmpty) {
        final record = records.items.first;
        final cloudConfig = AlgorithmConfig.fromJson(record.data);

        if (cloudConfig.version > state.version) {
          debugPrint(
              'New algorithm version found: ${cloudConfig.version}. Updating...');
          state = cloudConfig;
          await _prefs.setString(_storageKey, jsonEncode(cloudConfig.toJson()));
        } else {
          debugPrint('AlgorithmConfig is up to date (v${state.version})');
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch AlgorithmConfig from cloud: $e');
      // 网络失败时保持当前(缓存或默认)状态
    }
  }
}

final algorithmConfigProvider =
    StateNotifierProvider<AlgorithmConfigService, AlgorithmConfig>((ref) {
  final pb = ref.watch(pocketBaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AlgorithmConfigService(pb, prefs);
});
