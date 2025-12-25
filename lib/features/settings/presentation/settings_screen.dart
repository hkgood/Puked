import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

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
          _buildSensitivityTile(context, ref, l10n.sensitivityLow,
              SensitivityLevel.low, settings.sensitivity),
          _buildSensitivityTile(context, ref, l10n.sensitivityMedium,
              SensitivityLevel.medium, settings.sensitivity),
          _buildSensitivityTile(context, ref, l10n.sensitivityHigh,
              SensitivityLevel.high, settings.sensitivity),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.sensitivityTip,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontFamily: 'PingFang SC', // 使用系统黑体相关字体
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensitivityTile(BuildContext context, WidgetRef ref,
      String title, SensitivityLevel level, SensitivityLevel current) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'PingFang SC'),
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
