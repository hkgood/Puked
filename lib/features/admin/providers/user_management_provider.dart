import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:puked/services/pocketbase_service.dart';

/// 用户数据模型
class UserData {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isVerified;
  final String auditStatus; // 'approved', 'pending', 'rejected', ''
  final bool isKOL;
  final bool isSuperUser;
  final DateTime created;
  final DateTime updated;

  UserData({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.isVerified,
    required this.auditStatus,
    required this.isKOL,
    required this.isSuperUser,
    required this.created,
    required this.updated,
  });

  /// 是否为 Pro 用户
  bool get isPro => auditStatus == 'approved';

  factory UserData.fromRecord(RecordModel record, PocketBase pb) {
    String? avatarUrl;
    final avatar = record.getStringValue('avatar');
    if (avatar.isNotEmpty) {
      avatarUrl = pb.files.getUrl(record, avatar).toString();
    }

    return UserData(
      id: record.id,
      name: record.getStringValue('name'),
      email: record.getStringValue('email'),
      avatarUrl: avatarUrl,
      isVerified: record.getBoolValue('verified'),
      auditStatus: record.getStringValue('audit_status'),
      isKOL: record.getBoolValue('KOL'),
      isSuperUser: record.getBoolValue('is_superuser'),
      created: DateTime.parse(record.created),
      updated: DateTime.parse(record.updated),
    );
  }

  UserData copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    bool? isVerified,
    String? auditStatus,
    bool? isKOL,
    bool? isSuperUser,
    DateTime? created,
    DateTime? updated,
  }) {
    return UserData(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      auditStatus: auditStatus ?? this.auditStatus,
      isKOL: isKOL ?? this.isKOL,
      isSuperUser: isSuperUser ?? this.isSuperUser,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }
}

/// 用户管理 Provider
class UserManagementNotifier extends StateNotifier<AsyncValue<List<UserData>>> {
  final PocketBaseService _pbService;

  UserManagementNotifier(this._pbService) : super(const AsyncValue.loading());

  /// 加载用户列表
  Future<void> loadUsers() async {
    state = const AsyncValue.loading();
    try {
      final pb = _pbService.pb;

      // 获取所有用户，按创建时间倒序排列
      final records = await pb.collection('users').getFullList(
            sort: '-created',
            expand: '',
          );

      final users =
          records.map((record) => UserData.fromRecord(record, pb)).toList();

      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 更新用户的 KOL 状态
  Future<void> updateUserKOLStatus(String userId, bool isKOL) async {
    try {
      final pb = _pbService.pb;

      // 更新用户的 KOL 字段
      await pb.collection('users').update(
        userId,
        body: {'KOL': isKOL},
      );

      // 重新加载用户列表
      await loadUsers();
    } catch (e) {
      rethrow;
    }
  }

  /// 搜索用户（前端过滤，已在 UI 层实现）
  List<UserData> searchUsers(String query) {
    return state.when(
      data: (users) {
        if (query.isEmpty) return users;
        final lowerQuery = query.toLowerCase();
        return users
            .where((user) =>
                user.name.toLowerCase().contains(lowerQuery) ||
                user.email.toLowerCase().contains(lowerQuery))
            .toList();
      },
      loading: () => [],
      error: (_, __) => [],
    );
  }
}

/// 用户管理 Provider
final userManagementProvider =
    StateNotifierProvider<UserManagementNotifier, AsyncValue<List<UserData>>>(
  (ref) {
    final pbService = ref.watch(pbServiceProvider);
    return UserManagementNotifier(pbService);
  },
);
