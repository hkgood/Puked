import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puked/services/update_service.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/auth/presentation/login_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import '../providers/settings_provider.dart';

// 版本信息 Provider
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 页面构建时静默刷新用户信息，确保认证状态（如 audit_status）是最新的
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(authProvider.notifier).refreshUserFromServer();
      }
    });

    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final i18n = ref.watch(i18nProvider);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('settings')),
      ),
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8), // 统一标题和内容间距
          child: ListView(
            children: [
              // 账号系统
              _buildSectionHeader(context, i18n.t('account')),
              if (!auth.isAuthenticated)
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(i18n.t('login')),
                  subtitle: Text(i18n.t('login_to_sync')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 跳转到独立登录页面
                    _showAuthPage(context);
                  },
                )
              else
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        ref.watch(pbServiceProvider).currentAvatarUrl != null
                            ? NetworkImage(
                                ref.watch(pbServiceProvider).currentAvatarUrl!)
                            : null,
                    child: ref.watch(pbServiceProvider).currentAvatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(auth.user?.getStringValue('name') ?? i18n.t('user')),
                      if (auth.isPro) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
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
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user?.getStringValue('email') ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (auth.isSuperUser)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "SuperUser / Admin",
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (auth.user?.getBoolValue('verified') == false)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: () async {
                              // 点击时先尝试刷新状态，如果还是未验证，再提示发送邮件
                              await ref
                                  .read(authProvider.notifier)
                                  .refreshUserFromServer();

                              if (ref
                                      .read(authProvider)
                                      .user
                                      ?.getBoolValue('verified') ==
                                  true) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text(i18n.t('verification_success')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                                return;
                              }

                              await ref
                                  .read(authProvider.notifier)
                                  .requestVerification();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(i18n.t('verification_sent')),
                                      backgroundColor: Colors.green),
                                );
                              }
                            },
                            child: Text(
                              i18n.t('not_verified'),
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      // 使用 Future.wait 并行处理，提高响应速度，但要 await 确保逻辑完成
                      await Future.wait([
                        ref.read(authProvider.notifier).logout(),
                        ref
                            .read(settingsProvider.notifier)
                            .clearVehicleSettings(),
                      ]);
                    },
                    child: Text(i18n.t('logout'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),

              const Divider(),

              // 账号关联的智驾设置
              if (auth.isAuthenticated) ...[
                _buildSectionHeader(context, i18n.t('my_car')),
                ListTile(
                  leading: BrandLogo(
                    brandName: settings.brand,
                    showBackground: true,
                  ),
                  title: Row(
                    children: [
                      Text(
                        settings.brand ?? i18n.t('my_car'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildVerificationBadge(context, auth, i18n),
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (settings.carModel != null &&
                          settings.carModel!.isNotEmpty)
                        settings.carModel,
                      if (settings.softwareVersion != null &&
                          settings.softwareVersion!.isNotEmpty)
                        settings.softwareVersion,
                    ].join(' • ').isEmpty
                        ? i18n.t('model_hint')
                        : [
                            if (settings.carModel != null &&
                                settings.carModel!.isNotEmpty)
                              settings.carModel,
                            if (settings.softwareVersion != null &&
                                settings.softwareVersion!.isNotEmpty)
                              settings.softwareVersion,
                          ].join(' • '),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VehicleInfoScreen(
                          isSettingsMode: true,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
              ],

              // 主题设置
              _buildSectionHeader(context, i18n.t('theme')),
              ListTile(
                title: Text(i18n.t('theme_auto')),
                trailing: settings.themeMode == ThemeMode.system
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(ThemeMode.system),
              ),
              ListTile(
                title: Text(i18n.t('theme_light')),
                trailing: settings.themeMode == ThemeMode.light
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(ThemeMode.light),
              ),
              ListTile(
                title: Text(i18n.t('theme_dark')),
                trailing: settings.themeMode == ThemeMode.dark
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(ThemeMode.dark),
              ),

              const Divider(),

              // 语言设置
              _buildSectionHeader(context, i18n.t('language')),
              ListTile(
                title: Text(i18n.t('chinese')),
                trailing: settings.locale?.languageCode == 'zh'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setLocale(const Locale('zh')),
              ),
              ListTile(
                title: Text(i18n.t('english')),
                trailing: settings.locale?.languageCode == 'en'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .setLocale(const Locale('en')),
              ),

              const Divider(),

              // 自动打标敏感度
              _buildSectionHeader(context, i18n.t('sensitivity')),
              _buildSensitivityTile(
                context,
                ref,
                i18n.t('sensitivity_low'),
                'Accel > 3.0m/s², Brake > 3.5m/s²', // Subtitles can stay as descriptions
                SensitivityLevel.low,
                settings.sensitivity,
              ),
              _buildSensitivityTile(
                context,
                ref,
                i18n.t('sensitivity_medium'),
                'Accel > 2.4m/s², Brake > 2.8m/s²',
                SensitivityLevel.medium,
                settings.sensitivity,
              ),
              _buildSensitivityTile(
                context,
                ref,
                i18n.t('sensitivity_high'),
                'Accel > 1.8m/s², Brake > 2.1m/s²',
                SensitivityLevel.high,
                settings.sensitivity,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  i18n.t('sensitivity_tip'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),

              const Divider(),

              // 关于与更新
              _buildSectionHeader(context, i18n.t('about')),
              ListTile(
                title: Text(
                  i18n.t('current_version'),
                  style: const TextStyle(),
                ),
                trailing: packageInfo.when(
                  data: (info) => Text(
                    'v${info.version}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Text(i18n.t('unknown')),
                ),
              ),
              ListTile(
                title: Text(
                  i18n.t('check_update'),
                  style: const TextStyle(),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  UpdateService.checkUpdate(context, showNoUpdate: true);
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuthPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildSensitivityTile(
      BuildContext context,
      WidgetRef ref,
      String title,
      String subtitle,
      SensitivityLevel level,
      SensitivityLevel current) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
        ),
      ),
      trailing: current == level
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () => ref.read(settingsProvider.notifier).setSensitivity(level),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildVerificationBadge(
      BuildContext context, AuthState auth, dynamic i18n) {
    final status = auth.user?.getStringValue('audit_status') ?? '';

    Color bgColor;
    String text;

    switch (status) {
      case 'approved':
        bgColor = Colors.green.shade600;
        text = i18n.t('approved');
        break;
      case 'pending':
        bgColor = Colors.orange.shade600;
        text = i18n.t('pending');
        break;
      case 'rejected':
        bgColor = Colors.red.shade600;
        text = i18n.t('rejected');
        break;
      default:
        bgColor = Colors.grey.shade500;
        text = i18n.t('unverified');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
