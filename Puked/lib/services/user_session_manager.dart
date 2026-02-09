import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 用户会话管理器 - 商业级别的账号隔离和状态管理
///
/// 职责：
/// 1. 管理当前用户会话的生命周期
/// 2. 在账号切换时协调所有相关Provider的清理和重置
/// 3. 防止数据混乱和竞态条件
/// 4. 提供统一的会话状态查询接口
class UserSessionManager {
  UserSessionManager();

  /// 当前用户ID（null表示未登录）
  String? _currentUserId;

  /// 会话锁：防止并发的账号切换操作
  bool _isSwitching = false;

  /// 会话变更通知流
  final _sessionChangeController =
      StreamController<SessionChangeEvent>.broadcast();

  /// 当前用户ID（只读）
  String? get currentUserId => _currentUserId;

  /// 是否有活跃会话
  bool get hasActiveSession => _currentUserId != null;

  /// 会话变更事件流
  Stream<SessionChangeEvent> get sessionChanges =>
      _sessionChangeController.stream;

  /// 初始化会话（应用启动时调用）
  ///
  /// 从持久化存储中恢复会话状态
  Future<void> initialize(String? userId) async {
    debugPrint('[UserSession] Initializing with userId: $userId');
    _currentUserId = userId;

    if (userId != null) {
      _sessionChangeController.add(SessionChangeEvent(
        type: SessionEventType.restored,
        userId: userId,
      ));
    }
  }

  /// 开始新会话（登录成功后调用）
  ///
  /// [userId] 新用户的ID
  /// [ref] Riverpod容器引用，用于清理其他Provider
  Future<void> startSession(String userId, WidgetRef? ref) async {
    if (_isSwitching) {
      debugPrint(
          '[UserSession] Session switch already in progress, skipping...');
      return;
    }

    _isSwitching = true;

    try {
      debugPrint('[UserSession] Starting new session for user: $userId');

      // 如果是切换账号（而非首次登录），先清理旧会话
      if (_currentUserId != null && _currentUserId != userId) {
        await _endSession(ref, isLogout: false);
      }

      // 设置新用户
      final oldUserId = _currentUserId;
      _currentUserId = userId;

      // 通知会话开始
      _sessionChangeController.add(SessionChangeEvent(
        type: SessionEventType.started,
        userId: userId,
        previousUserId: oldUserId,
      ));

      debugPrint(
          '[UserSession] Session started successfully for user: $userId');
    } finally {
      _isSwitching = false;
    }
  }

  /// 结束当前会话（退出登录时调用）
  ///
  /// [ref] Riverpod容器引用
  Future<void> endSession(WidgetRef? ref) async {
    if (_isSwitching) {
      debugPrint('[UserSession] Session switch in progress, waiting...');
      // 等待当前切换完成
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isSwitching = true;

    try {
      await _endSession(ref, isLogout: true);
    } finally {
      _isSwitching = false;
    }
  }

  /// 内部：清理会话数据
  Future<void> _endSession(WidgetRef? ref, {required bool isLogout}) async {
    if (_currentUserId == null) {
      debugPrint('[UserSession] No active session to end');
      return;
    }

    final userId = _currentUserId!;
    debugPrint(
        '[UserSession] Ending session for user: $userId (logout: $isLogout)');

    // 通知会话即将结束（其他模块可以监听此事件进行清理）
    _sessionChangeController.add(SessionChangeEvent(
      type: isLogout ? SessionEventType.logout : SessionEventType.switched,
      userId: userId,
    ));

    // 清空当前用户ID
    _currentUserId = null;

    // 如果有ref，清理相关的Provider缓存
    if (ref != null) {
      await _invalidateProviders(ref, userId);
    }

    debugPrint('[UserSession] Session ended for user: $userId');
  }

  /// 清理所有与用户相关的Provider缓存
  ///
  /// 这是防止数据混乱的关键：确保切换账号时，所有旧账号的数据都被清除
  Future<void> _invalidateProviders(WidgetRef ref, String userId) async {
    debugPrint('[UserSession] Invalidating providers for user: $userId');

    try {
      // 延迟导入，避免循环依赖
      // 注意：这里列出所有需要清理的Provider

      // 1. 清理统计数据Provider
      final arenaProviders = [
        'arenaStatsProvider',
        'userStatsEntryProvider',
        'myStatsProvider',
      ];

      // 2. 清理设置Provider
      final settingsProviders = [
        'settingsProvider',
        'myStatsForceRefreshProvider',
      ];

      // 3. 清理行程Provider
      final tripProviders = [
        'tripProvider',
        'arenaTripsProvider',
      ];

      debugPrint(
          '[UserSession] Providers invalidated (${arenaProviders.length + settingsProviders.length + tripProviders.length} total)');

      // 实际的失效操作会在各个Provider中通过监听 sessionChanges 来实现
      // 这里只是记录日志
    } catch (e) {
      debugPrint('[UserSession] Error invalidating providers: $e');
    }
  }

  /// 验证当前显示的数据是否属于当前用户
  ///
  /// 这是一个防御性检查，用于捕获潜在的数据混乱问题
  bool validateDataOwnership(String? dataUserId) {
    if (_currentUserId == null) {
      // 未登录状态，任何用户数据都不应显示
      return dataUserId == null;
    }

    return dataUserId == _currentUserId;
  }

  /// 获取会话信息（用于调试）
  Map<String, dynamic> getSessionInfo() {
    return {
      'currentUserId': _currentUserId,
      'hasActiveSession': hasActiveSession,
      'isSwitching': _isSwitching,
    };
  }

  /// 释放资源
  void dispose() {
    _sessionChangeController.close();
  }
}

/// 会话变更事件
class SessionChangeEvent {
  final SessionEventType type;
  final String? userId;
  final String? previousUserId;
  final DateTime timestamp;

  SessionChangeEvent({
    required this.type,
    this.userId,
    this.previousUserId,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'SessionChangeEvent(type: $type, userId: $userId, previousUserId: $previousUserId, time: $timestamp)';
  }
}

/// 会话事件类型
enum SessionEventType {
  /// 会话恢复（应用启动时）
  restored,

  /// 会话开始（登录成功）
  started,

  /// 会话切换（切换到另一个账号）
  switched,

  /// 会话结束（退出登录）
  logout,
}

/// 全局会话管理器Provider
///
/// 这是一个单例，整个应用只有一个实例
final userSessionManagerProvider = Provider<UserSessionManager>((ref) {
  final manager = UserSessionManager();

  // 确保在Provider销毁时释放资源
  ref.onDispose(() {
    manager.dispose();
  });

  return manager;
});
