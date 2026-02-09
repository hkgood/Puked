import 'package:flutter/foundation.dart';
import 'package:puked/services/user_session_manager.dart';

/// 账号隔离调试助手
///
/// 用于在开发和测试阶段验证数据是否正确隔离
class AccountIsolationDebugger {
  /// 验证显示的数据是否属于当前登录用户
  ///
  /// [dataUserId] 数据关联的用户ID
  /// [dataDescription] 数据描述（用于日志）
  /// [sessionManager] 会话管理器实例
  ///
  /// 返回：true表示数据所有权正确，false表示检测到数据混乱
  static bool validateDataOwnership({
    required String? dataUserId,
    required String dataDescription,
    required UserSessionManager sessionManager,
  }) {
    final currentUserId = sessionManager.currentUserId;
    final isValid = sessionManager.validateDataOwnership(dataUserId);

    if (!isValid) {
      debugPrint('⚠️ [ACCOUNT_ISOLATION_ERROR] Data ownership mismatch!');
      debugPrint('   Data: $dataDescription');
      debugPrint('   Current User: ${currentUserId ?? "not logged in"}');
      debugPrint('   Data User: ${dataUserId ?? "null"}');
      debugPrint('   Stack trace: ${StackTrace.current}');

      // 在开发模式下，可以选择抛出异常来快速发现问题
      if (kDebugMode) {
        // throw StateError('Data ownership validation failed: $dataDescription');
      }
    }

    return isValid;
  }

  /// 记录账号切换操作
  static void logAccountSwitch({
    required String? fromUserId,
    required String? toUserId,
    required String context,
  }) {
    debugPrint('🔄 [ACCOUNT_SWITCH]');
    debugPrint('   Context: $context');
    debugPrint('   From: ${fromUserId ?? "not logged in"}');
    debugPrint('   To: ${toUserId ?? "not logged in"}');
    debugPrint('   Time: ${DateTime.now()}');
  }

  /// 记录数据加载操作
  static void logDataLoad({
    required String dataType,
    required String? userId,
    required String source,
  }) {
    debugPrint('📥 [DATA_LOAD]');
    debugPrint('   Type: $dataType');
    debugPrint('   User: ${userId ?? "guest"}');
    debugPrint('   Source: $source');
    debugPrint('   Time: ${DateTime.now()}');
  }

  /// 记录数据清理操作
  static void logDataClear({
    required String dataType,
    required String? userId,
    required String reason,
  }) {
    debugPrint('🗑️ [DATA_CLEAR]');
    debugPrint('   Type: $dataType');
    debugPrint('   User: ${userId ?? "guest"}');
    debugPrint('   Reason: $reason');
    debugPrint('   Time: ${DateTime.now()}');
  }

  /// 生成会话诊断报告
  static String generateSessionReport(UserSessionManager sessionManager) {
    final info = sessionManager.getSessionInfo();

    final buffer = StringBuffer();
    buffer.writeln('=== Session Diagnostic Report ===');
    buffer.writeln('Current User ID: ${info['currentUserId'] ?? "none"}');
    buffer.writeln('Has Active Session: ${info['hasActiveSession']}');
    buffer.writeln('Is Switching: ${info['isSwitching']}');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('================================');

    return buffer.toString();
  }

  /// 打印会话诊断报告
  static void printSessionReport(UserSessionManager sessionManager) {
    debugPrint(generateSessionReport(sessionManager));
  }
}
