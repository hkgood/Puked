import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一个自定义的 PocketBase AuthStore，使用 SharedPreferences 实现 Token 持久化。
class SharedPreferencesAuthStore extends AuthStore {
  static const _storeKey = 'pb_auth';
  final SharedPreferences prefs;

  SharedPreferencesAuthStore(this.prefs) {
    final encoded = prefs.getString(_storeKey);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(encoded);
        final token = decoded['token'] ?? '';
        final dynamic modelData = decoded['model'];

        // 【核心修复】：在调用 save 之前，必须先将 Map 转换为 RecordModel 对象
        // 否则 super.save 会因为类型不匹配抛出异常，导致 AuthStore 被清空
        RecordModel? model;
        if (modelData != null && modelData is Map) {
          model = RecordModel(Map<String, dynamic>.from(modelData));
        }

        save(token, model);
      } catch (e) {
        clear();
      }
    }
  }

  @override
  void save(String newToken, dynamic newRecord) {
    // 确保传入 super.save 的是正确的类型
    dynamic recordToSave = newRecord;
    if (newRecord is Map) {
      recordToSave = RecordModel(Map<String, dynamic>.from(newRecord));
    }

    super.save(newToken, recordToSave);

    prefs.setString(
        _storeKey,
        jsonEncode({
          'token': newToken,
          'model': newRecord, // 存储时仍然可以是 Map 或 RecordModel（jsonEncode 会处理）
        }));
  }

  @override
  void clear() {
    super.clear();
    prefs.remove(_storeKey);
  }
}

/// 全局共享的 SharedPreferences 实例
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

/// PocketBase 客户端 Provider
final pocketBaseProvider = Provider<PocketBase>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final authStore = SharedPreferencesAuthStore(prefs);

  // 你的服务器地址
  return PocketBase('https://pb.osglab.com', authStore: authStore);
});

class PocketBaseService {
  final PocketBase pb;
  PocketBaseService(this.pb);

  bool get isAuthenticated => pb.authStore.isValid;

  /// 获取当前用户信息。
  /// 注意：在应用启动从本地加载时，record 可能暂时是一个 Map 而非 RecordModel，
  /// 这里做了兼容处理，确保业务层能通过 RecordModel 的接口读取数据。
  RecordModel? get currentUser {
    final dynamic record = pb.authStore.record;
    if (record == null) return null;

    // 由于我们在 AuthStore.save 中做了强制转换，这里 record 理论上永远是 RecordModel
    if (record is RecordModel) return record;

    // 冗余保护逻辑，防止万一
    if (record is Map) {
      try {
        return RecordModel(Map<String, dynamic>.from(record));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String? get currentUserId => currentUser?.id;

  String? get currentAvatarUrl {
    final user = currentUser;
    if (user == null || user.getStringValue('avatar').isEmpty) return null;
    return pb.files.getUrl(user, user.getStringValue('avatar')).toString();
  }

  Future<void> logout() async {
    pb.authStore.clear();
  }

  // 可以在这里扩展 OAuth2 登录、文件上传等通用逻辑
}

final pbServiceProvider = Provider<PocketBaseService>((ref) {
  final pb = ref.watch(pocketBaseProvider);
  return PocketBaseService(pb);
});
