import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:puked/services/update_service.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
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
