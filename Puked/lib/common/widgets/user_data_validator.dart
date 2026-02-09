import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/services/user_session_manager.dart';
import 'package:puked/services/account_isolation_debugger.dart';

/// 用户数据验证包装器
///
/// 用于确保显示的数据属于当前登录用户
/// 如果检测到数据不匹配，会显示占位符或错误提示，而非错误的数据
class UserDataValidator extends ConsumerWidget {
  /// 数据所属的用户ID
  final String? dataUserId;

  /// 数据描述（用于调试）
  final String dataDescription;

  /// 正常情况下显示的内容
  final Widget child;

  /// 数据不匹配时的占位符（可选）
  final Widget? placeholder;

  /// 是否在数据不匹配时静默处理（不显示错误）
  final bool silentOnMismatch;

  const UserDataValidator({
    super.key,
    required this.dataUserId,
    required this.dataDescription,
    required this.child,
    this.placeholder,
    this.silentOnMismatch = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionManager = ref.watch(userSessionManagerProvider);

    // 验证数据所有权
    final isValid = AccountIsolationDebugger.validateDataOwnership(
      dataUserId: dataUserId,
      dataDescription: dataDescription,
      sessionManager: sessionManager,
    );

    if (!isValid) {
      if (silentOnMismatch) {
        // 静默处理：显示占位符或空白
        return placeholder ?? const SizedBox.shrink();
      } else {
        // 显示错误提示
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Data validation failed',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Expected user: ${sessionManager.currentUserId}\nData user: $dataUserId',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    }

    return child;
  }
}

/// 带数据验证的FutureBuilder
///
/// 在显示异步数据前验证数据所有权
class ValidatedFutureBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final String? Function(T data) getUserId;
  final String dataDescription;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loading;
  final Widget? error;

  const ValidatedFutureBuilder({
    super.key,
    required this.future,
    required this.getUserId,
    required this.dataDescription,
    required this.builder,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return error ?? Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data as T;
        final dataUserId = getUserId(data);

        return Consumer(
          builder: (context, ref, _) {
            return UserDataValidator(
              dataUserId: dataUserId,
              dataDescription: dataDescription,
              child: builder(context, data),
            );
          },
        );
      },
    );
  }
}
