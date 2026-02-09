import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/user_session_manager.dart';
import 'package:http/http.dart' as http;

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
  bool get isSuperUser => user?.getBoolValue('is_superuser') == true;

  // KOL 判定
  bool get isKOL => user?.getBoolValue('KOL') == true;

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
  final Ref _ref;
  bool _isLoggingOut = false;

  AuthNotifier(this._pbService, this._ref)
      : super(AuthState(
          user: _pbService.currentUser,
          isTokenValid: _pbService.isAuthenticated,
        )) {
    // 启动时如果 Token 有效，静默刷新用户信息以确保 UI 数据最新
    if (state.isTokenValid && _pbService.currentUserId != null) {
      // 初始化会话管理器
      _ref
          .read(userSessionManagerProvider)
          .initialize(_pbService.currentUserId);
      refreshUserFromServer();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _pbService.pb.collection('users').authWithPassword(email, password);

      final newUserId = _pbService.currentUserId;

      // 更新状态
      state = state.copyWith(
        isLoading: false,
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );

      // 🔥 关键：通知会话管理器用户已登录
      if (newUserId != null) {
        await _ref
            .read(userSessionManagerProvider)
            .startSession(newUserId, null);
      }
    } on ClientException catch (_) {
      // 设置一个标准化的错误 Key
      state = state.copyWith(
        isLoading: false,
        error: 'error_invalid_credentials',
        isTokenValid: false,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isTokenValid: false,
      );
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
        } else if (data.isNotEmpty) {
          errorKey = 'error_${data.keys.first}';
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
    if (_isLoggingOut) {
      return;
    }

    _isLoggingOut = true;

    try {
      // 🔥 关键步骤1：先通知会话管理器结束会话（这会触发所有Provider清理）
      await _ref.read(userSessionManagerProvider).endSession(null);

      // 步骤2：清除PocketBase的认证状态
      await _pbService.logout();

      // 步骤3：重置本地状态为未登录
      state = AuthState(isTokenValid: false);
    } catch (e) {
      // 即使出错，也要确保状态被重置
      state = AuthState(isTokenValid: false);
    } finally {
      // 短暂延迟后重置锁，确保所有清理操作完成
      Future.delayed(const Duration(milliseconds: 500), () {
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

  Future<void> updateAvatar(File imageFile) async {
    final userId = _pbService.currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final multipartFile = await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
      );

      await _pbService.pb.collection('users').update(
        userId,
        files: [multipartFile],
      );

      // 刷新用户信息以获取新的头像 URL
      await refreshUserFromServer();
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
    // 防御性检查1: 如果正在退出登录，立即返回
    if (_isLoggingOut) {
      return;
    }

    // 防御性检查2: 如果未登录，立即返回
    if (!_pbService.isAuthenticated) {
      if (state.isTokenValid) {
        state = state.copyWith(isTokenValid: false);
      }
      return;
    }

    // 防御性检查3: 验证当前用户ID与会话管理器一致
    final currentUserId = _pbService.currentUserId;
    final sessionUserId = _ref.read(userSessionManagerProvider).currentUserId;

    if (currentUserId != sessionUserId) {
      return;
    }

    try {
      await _pbService.pb.collection('users').authRefresh();

      // 再次检查：防止在请求期间用户点击了退出登录
      if (_isLoggingOut) {
        return;
      }

      // 最终检查：确保刷新回来的用户ID仍然匹配
      final refreshedUserId = _pbService.currentUserId;
      if (refreshedUserId != sessionUserId) {
        return;
      }

      // 刷新成功后，同步最新的用户信息
      state = state.copyWith(
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    } on ClientException catch (e) {
      // 如果服务器返回 401 或 404，说明账号可能已被删除或 Token 已彻底失效
      if (e.statusCode == 401 || e.statusCode == 404) {
        logout();
        return;
      }

      // 再次检查
      if (_isLoggingOut) return;

      // 刷新失败（如网络问题）时，只要本地 Token 还没过期，就保持登录状态
      // 这样用户在离线状态下仍然可以看到自己的账号信息
      state = state.copyWith(
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    } catch (e) {
      // 再次检查
      if (_isLoggingOut) return;

      state = state.copyWith(
        user: _pbService.currentUser,
        isTokenValid: _pbService.isAuthenticated,
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final pbService = ref.watch(pbServiceProvider);
  return AuthNotifier(pbService, ref);
});
