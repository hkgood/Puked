import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/services/pocketbase_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final RecordModel? user;

  AuthState({
    this.isLoading = false,
    this.error,
    this.user,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    RecordModel? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final PocketBaseService _pbService;

  AuthNotifier(this._pbService)
      : super(AuthState(user: _pbService.currentUser));

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _pbService.pb.collection('users').authWithPassword(email, password);
      state = state.copyWith(isLoading: false, user: _pbService.currentUser);
    } on ClientException catch (_) {
      // 设置一个标准化的错误 Key
      state =
          state.copyWith(isLoading: false, error: 'error_invalid_credentials');
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> register(String email, String password, String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{
        "email": email,
        "password": password,
        "passwordConfirm": password,
        "name": name,
      };
      await _pbService.pb.collection('users').create(body: body);
      // 注册成功后自动登录
      await login(email, password);
    } on ClientException catch (e) {
      String errorKey = 'register_failed';
      if (e.response['data'] != null && e.response['data'] is Map) {
        final data = e.response['data'] as Map;
        if (data.containsKey('email')) {
          errorKey = 'error_email_taken';
        } else if (data.containsKey('password')) {
          errorKey = 'error_password_too_short';
        }
      }
      state = state.copyWith(isLoading: false, error: errorKey);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _pbService.logout();
    } finally {
      // 无论登出是否发生网络错误，都必须强制重置本地状态为未登录，确保 UI 同步
      state = AuthState();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _pbService.pb.collection('users').requestPasswordReset(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> requestVerification() async {
    final email = _pbService.currentUser?.getStringValue('email');
    if (email == null || email.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _pbService.pb.collection('users').requestVerification(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  void refreshUser() {
    state = state.copyWith(user: _pbService.currentUser);
  }

  /// 从服务器拉取最新的用户信息（用于更新验证状态等）
  Future<void> refreshUserFromServer() async {
    // 如果已经登出，则不再刷新，防止竞态条件下状态回退
    if (!state.isAuthenticated) return;

    try {
      await _pbService.pb.collection('users').authRefresh();
      // 刷新后再次检查，确保在异步过程中用户没有登出
      if (state.isAuthenticated) {
        state = state.copyWith(user: _pbService.currentUser);
      }
    } catch (_) {
      // 刷新失败通常是因为网络或 Token 失效，保持现状即可
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final pbService = ref.watch(pbServiceProvider);
  return AuthNotifier(pbService);
});
