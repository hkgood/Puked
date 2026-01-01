import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/services/pocketbase_service.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final RecordModel? user;
  final bool isTokenValid;

  AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.isTokenValid = false,
  });

  // 登录状态的核心判定：Token 是否存在且有效
  bool get isAuthenticated => isTokenValid;

  // Pro 权限判定
  bool get isPro => user?.getStringValue('audit_status') == 'approved';

  // 超级用户判定
  bool get isSuperUser =>
      user?.getStringValue('email') == 'rocky.hk@gmail.com' ||
      user?.getStringValue('email') == 'rocky2@example.com'; // 方便你测试，也可以只留一个

  AuthState copyWith({
    bool? isLoading,
    String? error,
    RecordModel? user,
    bool? isTokenValid,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
      isTokenValid: isTokenValid ?? this.isTokenValid,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final PocketBaseService _pbService;
  bool _isLoggingOut = false;

  AuthNotifier(this._pbService)
      : super(AuthState(
          user: _pbService.currentUser,
          isTokenValid: _pbService.isAuthenticated,
        )) {
    // 启动时如果 Token 有效，静默刷新用户信息以确保 UI 数据最新
    if (state.isTokenValid) {
      refreshUserFromServer();
    }
  }

  Future<void> login(String email, String password) async {
    print('AuthNotifier: login called for $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _pbService.pb.collection('users').authWithPassword(email, password);
      print('AuthNotifier: login success');
      state = state.copyWith(
        isLoading: false,
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    } on ClientException catch (e) {
      print('AuthNotifier: login ClientException: ${e.response}');
      // 设置一个标准化的错误 Key
      state = state.copyWith(
        isLoading: false,
        error: 'error_invalid_credentials',
        isTokenValid: false,
      );
      rethrow;
    } catch (e) {
      print('AuthNotifier: login unknown error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isTokenValid: false,
      );
      rethrow;
    }
  }

  Future<void> register(String email, String password, String name) async {
    print('AuthNotifier: register called. Email: $email, Name: $name');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = <String, dynamic>{
        "email": email,
        "password": password,
        "passwordConfirm": password,
        "name": name,
      };
      print('AuthNotifier: Creating user with body: $body');
      final record = await _pbService.pb.collection('users').create(body: body);
      print('AuthNotifier: User created successfully. ID: ${record.id}');

      // 注册成功后自动登录
      print('AuthNotifier: Attempting auto-login after register');
      await login(email, password);
    } on ClientException catch (e) {
      print('AuthNotifier: register ClientException: ${e.response}');
      String errorKey = 'register_failed';
      if (e.response['data'] != null && e.response['data'] is Map) {
        final data = e.response['data'] as Map;
        print('AuthNotifier: Validation Errors: $data');
        if (data.containsKey('email')) {
          errorKey = 'error_email_taken';
        } else if (data.containsKey('password')) {
          errorKey = 'error_password_too_short';
        } else if (data.isNotEmpty) {
          // 如果有其他错误（如 username），至少在 log 里打印出来
          errorKey = 'error_${data.keys.first}';
          print(
              'AuthNotifier: Unhandled validation error for field: ${data.keys.first}');
        }
      }
      state = state.copyWith(isLoading: false, error: errorKey);
      rethrow;
    } catch (e) {
      print('AuthNotifier: register unknown error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> logout() async {
    _isLoggingOut = true;
    try {
      await _pbService.logout();
    } finally {
      // 无论登出是否发生网络错误，都必须强制重置本地状态为未登录，确保 UI 同步
      state = AuthState(isTokenValid: false);

      // 延迟重置锁，确保在此期间所有残留的异步刷新请求都已处理完毕或被拦截
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
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
    state = state.copyWith(
      user: _pbService.currentUser,
      isTokenValid: _pbService.isAuthenticated,
    );
  }

  /// 从服务器拉取最新的用户信息（用于更新验证状态等）
  Future<void> refreshUserFromServer() async {
    // 如果正在退出登录，或者本来就未登录，则不执行刷新
    if (_isLoggingOut || !_pbService.isAuthenticated) {
      if (state.isTokenValid && !_pbService.isAuthenticated) {
        state = state.copyWith(isTokenValid: false);
      }
      return;
    }

    try {
      await _pbService.pb.collection('users').authRefresh();

      // 再次检查，防止在请求期间用户点击了退出登录
      if (_isLoggingOut) return;

      // 刷新成功后，再次同步最新的用户信息
      state = state.copyWith(
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    } catch (_) {
      // 再次检查
      if (_isLoggingOut) return;

      // 刷新失败（如网络问题）时，只要本地 Token 还没过期，就保持登录状态
      // 这样用户在离线状态下仍然可以看到自己的账号信息
      state = state.copyWith(
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final pbService = ref.watch(pbServiceProvider);
  return AuthNotifier(pbService);
});
