import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/common/utils/i18n.dart';
import '../providers/user_management_provider.dart';

/// 用户管理页面 - 仅限 SuperUser 访问
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 页面加载时获取用户列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final i18n = ref.watch(i18nProvider);
    final userManagementState = ref.watch(userManagementProvider);

    // 权限检查：仅 SuperUser 可访问
    if (!auth.isSuperUser) {
      return Scaffold(
        appBar: AppBar(
          title: Text(i18n.t('user_management')),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                i18n.t('access_denied'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                i18n.t('superuser_only'),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('user_management')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildSearchBar(i18n),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(userManagementProvider.notifier).loadUsers();
        },
        child: userManagementState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(userManagementProvider.notifier).loadUsers();
                  },
                  child: Text(i18n.t('retry')),
                ),
              ],
            ),
          ),
          data: (users) {
            // 过滤用户列表
            final filteredUsers = users.where((user) {
              if (_searchQuery.isEmpty) return true;
              final name = user.name.toLowerCase();
              final email = user.email.toLowerCase();
              return name.contains(_searchQuery) ||
                  email.contains(_searchQuery);
            }).toList();

            if (filteredUsers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? i18n.t('no_users_found')
                          : i18n.t('no_search_results'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredUsers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return _buildUserCard(context, user, i18n);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(dynamic i18n) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: i18n.t('search_users'),
          prefixIcon: Icon(Icons.search,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserData user, dynamic i18n) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showUserDetailSheet(context, user, i18n),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 用户头像
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  image: user.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(user.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.avatarUrl == null
                    ? Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ..._buildUserBadges(context, user),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip(
                          context,
                          _getAuditStatusText(user.auditStatus, i18n),
                          _getAuditStatusColor(user.auditStatus),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.verified,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUserBadges(BuildContext context, UserData user) {
    List<Widget> badges = [];

    if (user.isPro) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFFA500),
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          'PRO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      badges.add(const SizedBox(width: 4));
    }

    if (user.isKOL) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          'Expert',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
      badges.add(const SizedBox(width: 4));
    }

    if (user.isSuperUser) {
      badges.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text(
          'Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ));
    }

    return badges;
  }

  Widget _buildStatusChip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _getAuditStatusText(String status, dynamic i18n) {
    switch (status) {
      case 'approved':
        return i18n.t('approved');
      case 'pending':
        return i18n.t('pending');
      case 'rejected':
        return i18n.t('rejected');
      default:
        return i18n.t('unverified');
    }
  }

  Color _getAuditStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showUserDetailSheet(BuildContext context, UserData user, dynamic i18n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => UserDetailSheet(user: user),
    );
  }
}

/// 用户详情编辑弹窗
class UserDetailSheet extends ConsumerStatefulWidget {
  final UserData user;

  const UserDetailSheet({super.key, required this.user});

  @override
  ConsumerState<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends ConsumerState<UserDetailSheet> {
  late bool _isKOL;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _isKOL = widget.user.isKOL;
  }

  Future<void> _updateKOLStatus() async {
    setState(() => _isUpdating = true);

    try {
      await ref
          .read(userManagementProvider.notifier)
          .updateUserKOLStatus(widget.user.id, _isKOL);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(i18nProvider).t('update_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ref.read(i18nProvider).t('update_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final auth = ref.watch(authProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖动指示器
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 用户头像和基本信息
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      image: widget.user.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.user.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.user.avatarUrl == null
                        ? Icon(
                            Icons.person,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            size: 40,
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.email,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildInfoSection(i18n, 'user_info', [
                      _buildInfoRow(i18n, 'user_id', widget.user.id),
                      _buildInfoRow(
                          i18n,
                          'email_verified',
                          widget.user.isVerified
                              ? i18n.t('yes')
                              : i18n.t('no')),
                      _buildInfoRow(i18n, 'audit_status',
                          _getAuditStatusText(widget.user.auditStatus, i18n)),
                      _buildInfoRow(i18n, 'pro_status',
                          widget.user.isPro ? i18n.t('yes') : i18n.t('no')),
                      _buildInfoRow(
                          i18n,
                          'superuser_status',
                          widget.user.isSuperUser
                              ? i18n.t('yes')
                              : i18n.t('no')),
                    ]),

                    const SizedBox(height: 24),

                    // KOL 权限设置 - 仅 SuperUser 可见
                    if (auth.isSuperUser) ...[
                      _buildInfoSection(i18n, 'permissions', [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            i18n.t('kol_permission'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              i18n.t('kol_permission_desc'),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          trailing: Switch(
                            value: _isKOL,
                            onChanged: _isUpdating
                                ? null
                                : (value) {
                                    setState(() => _isKOL = value);
                                  },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),

              // 底部按钮
              if (auth.isSuperUser && _isKOL != widget.user.isKOL) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : _updateKOLStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            i18n.t('save_changes'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(dynamic i18n, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          i18n.t(title),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(dynamic i18n, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            i18n.t(label),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getAuditStatusText(String status, dynamic i18n) {
    switch (status) {
      case 'approved':
        return i18n.t('approved');
      case 'pending':
        return i18n.t('pending');
      case 'rejected':
        return i18n.t('rejected');
      default:
        return i18n.t('unverified');
    }
  }
}
