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
      debugPrint(
          '🔍 [ConfigSync] 正在尝试从 PocketBase 获取最新配置 (Collection: $_collectionName)...');
      // 获取最新的一条配置记录 (按版本号或更新时间排序)
      final records = await _pb.collection(_collectionName).getList(
            page: 1,
            perPage: 1,
            sort: '-version',
          );

      debugPrint('🔍 [ConfigSync] PocketBase 响应记录数: ${records.items.length}');

      if (records.items.isNotEmpty) {
        final record = records.items.first;
        debugPrint('🔍 [ConfigSync] 收到云端原始 JSON: ${record.data}');
        final cloudConfig =
            AlgorithmConfig.fromJson(record.data, recordId: record.id);
        debugPrint(
            '🔍 [ConfigSync] 解析后版本: ${cloudConfig.version}, 当前本地版本: ${state.version}');

        if (cloudConfig.version > state.version || state.id == null) {
          debugPrint(
              '🚀 [ConfigSync] 检测到新版本或补全ID! 升级: ${state.version} -> ${cloudConfig.version}');
          state = cloudConfig;
          await _prefs.setString(_storageKey, jsonEncode(cloudConfig.toJson()));
          debugPrint('✅ [ConfigSync] 新配置已成功持久化到本地缓存');
        } else {
          debugPrint(
              'ℹ️ [ConfigSync] 无需更新 (云端: ${cloudConfig.version}, 本地: ${state.version})');
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [ConfigSync] 获取云端配置失败: $e');
      if (e.toString().contains('403')) {
        debugPrint(
            '💡 [ConfigSync] 提示: 请检查 PocketBase 的 API Rules 是否允许公开 List/View');
      }
      debugPrint(stack.toString());
    }
  }

  Future<void> updateConfig(AlgorithmConfig newConfig) async {
    try {
      if (newConfig.id == null)
        throw Exception('Cannot update config without ID');

      // 更新到 PocketBase
      final record = await _pb.collection(_collectionName).update(
            newConfig.id!,
            body: newConfig.toJson(),
          );

      // 更新本地状态
      final updatedConfig =
          AlgorithmConfig.fromJson(record.data, recordId: record.id);
      state = updatedConfig;
      await _prefs.setString(_storageKey, jsonEncode(updatedConfig.toJson()));
      debugPrint('✅ [ConfigUpdate] 配置已成功更新到云端并同步本地');
    } catch (e) {
      debugPrint('❌ [ConfigUpdate] 更新失败: $e');
      rethrow;
    }
  }
}

final algorithmConfigProvider =
    StateNotifierProvider<AlgorithmConfigService, AlgorithmConfig>((ref) {
  final pb = ref.watch(pocketBaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AlgorithmConfigService(pb, prefs);
});
