import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puked/services/update_service.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/auth/presentation/login_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/settings_provider.dart';

// 版本信息 Provider
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context)!;
    final packageInfo = ref.watch(packageInfoProvider);

    // 进入页面时静默刷新一次用户信息，以更新验证状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.isAuthenticated) {
        ref.read(authProvider.notifier).refreshUserFromServer();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // 账号系统
          _buildSectionHeader(context, l10n.account),
          if (!auth.isAuthenticated)
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(l10n.login),
              subtitle: Text(l10n.login_to_sync),
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
              title: Text(auth.user?.getStringValue('name') ?? 'User'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n
                      .connected_as(auth.user?.getStringValue('email') ?? '')),
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
                                  content: Text(l10n.verification_success),
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
                                  content: Text(l10n.verification_sent),
                                  backgroundColor: Colors.green),
                            );
                          }
                        },
                        child: Text(
                          l10n.not_verified,
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
                    ref.read(settingsProvider.notifier).clearVehicleSettings(),
                  ]);
                },
                child: Text(l10n.logout,
                    style: const TextStyle(color: Colors.red)),
              ),
            ),

          const Divider(),

          // 账号关联的智驾设置
          if (auth.isAuthenticated) ...[
            _buildSectionHeader(context, l10n.brand),
            ListTile(
              leading: settings.brand != null
                  ? Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SvgPicture.asset(
                        'assets/logos/${settings.brand}.svg',
                        colorFilter:
                            Theme.of(context).brightness == Brightness.dark
                                ? const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn)
                                : null,
                      ),
                    )
                  : const Icon(Icons.directions_car_filled_outlined, size: 32),
              title: Text(
                settings.brand ?? l10n.brand,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                    ? l10n.model_hint
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
          _buildSectionHeader(context, l10n.theme),
          ListTile(
            title: Text(l10n.themeAuto),
            trailing: settings.themeMode == ThemeMode.system
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.system),
          ),
          ListTile(
            title: Text(l10n.themeLight),
            trailing: settings.themeMode == ThemeMode.light
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.light),
          ),
          ListTile(
            title: Text(l10n.themeDark),
            trailing: settings.themeMode == ThemeMode.dark
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setThemeMode(ThemeMode.dark),
          ),

          const Divider(),

          // 语言设置
          _buildSectionHeader(context, l10n.language),
          ListTile(
            title: Text(l10n.chinese),
            trailing: settings.locale?.languageCode == 'zh'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setLocale(const Locale('zh')),
          ),
          ListTile(
            title: Text(l10n.english),
            trailing: settings.locale?.languageCode == 'en'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => ref
                .read(settingsProvider.notifier)
                .setLocale(const Locale('en')),
          ),

          const Divider(),

          // 自动打标敏感度
          _buildSectionHeader(context, l10n.sensitivity),
          _buildSensitivityTile(
            context,
            ref,
            l10n.sensitivityLow,
            l10n.sensitivityLowDesc,
            SensitivityLevel.low,
            settings.sensitivity,
          ),
          _buildSensitivityTile(
            context,
            ref,
            l10n.sensitivityMedium,
            l10n.sensitivityMediumDesc,
            SensitivityLevel.medium,
            settings.sensitivity,
          ),
          _buildSensitivityTile(
            context,
            ref,
            l10n.sensitivityHigh,
            l10n.sensitivityHighDesc,
            SensitivityLevel.high,
            settings.sensitivity,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.sensitivityTip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontFamily: 'PingFang SC',
                  ),
            ),
          ),

          const Divider(),

          // 关于与更新
          _buildSectionHeader(context, l10n.about),
          ListTile(
            title: Text(
              l10n.current_version,
              style: const TextStyle(fontFamily: 'PingFang SC'),
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
              error: (_, __) => const Text('Unknown'),
            ),
          ),
          ListTile(
            title: Text(
              l10n.check_update,
              style: const TextStyle(fontFamily: 'PingFang SC'),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              UpdateService.checkUpdate(context, showNoUpdate: true);
            },
          ),
          const SizedBox(height: 32),
        ],
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
        style: const TextStyle(fontFamily: 'PingFang SC'),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'PingFang SC',
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
}
