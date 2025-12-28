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
        save(decoded['token'] ?? '', decoded['model']);
      } catch (e) {
        // 解码失败则清空
        clear();
      }
    }
  }

  @override
  void save(String newToken, dynamic newRecord) {
    super.save(newToken, newRecord);
    prefs.setString(
        _storeKey,
        jsonEncode({
          'token': newToken,
          'model': newRecord,
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
  RecordModel? get currentUser => pb.authStore.record is RecordModel
      ? pb.authStore.record as RecordModel
      : null;

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
