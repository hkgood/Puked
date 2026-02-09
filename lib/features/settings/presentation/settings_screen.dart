import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:puked/services/update_service.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/auth/presentation/login_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/services/algorithm_config_service.dart';
import 'package:puked/features/settings/presentation/algorithm_config_screen.dart';
import 'package:puked/features/settings/presentation/privacy_policy_screen.dart';
import 'package:puked/features/auth/presentation/delete_account_screen.dart';
import 'package:puked/features/recording/providers/vehicle_provider.dart';
import 'package:puked/features/settings/presentation/widgets/my_data_card.dart';
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:puked/features/settings/presentation/voice_recording_info_screen.dart';
import '../providers/settings_provider.dart';

// 版本信息 Provider
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 🔥 只在第一次进入页面时刷新，避免重复触发
    if (!_hasInitialized) {
      _hasInitialized = true;

      // 延迟执行，确保Widget树已构建完成
      Future.microtask(() {
        if (!mounted) return;

        final auth = ref.read(authProvider);
        if (auth.isAuthenticated) {
          // 静默刷新用户信息（如果需要）
          ref.read(authProvider.notifier).refreshUserFromServer();

          // 检查统计数据是否需要初始化
          final stats = ref.read(arenaStatsProvider);
          if (!stats.hasValue && !stats.isLoading) {
            ref.read(arenaStatsProvider.notifier).refresh(force: false);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    final i18n = ref.watch(i18nProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final algoConfig = ref.watch(algorithmConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('settings')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // 确保内容不足时也能触发下拉刷新
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. 账号与车辆卡片
              _buildCard(
                context,
                title: null, // 第一张卡片不显示标题
                children: [
                  // 账号部分
                  if (!auth.isAuthenticated)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(i18n.t('login')),
                      subtitle: Text(i18n.t('login_to_sync')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAuthPage(context),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: GestureDetector(
                        onTap: () => _handleUpdateAvatar(context, ref),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer, // 添加背景色
                              // 核心修复：使用 CachedNetworkImageProvider 缓存头像
                              backgroundImage: ref
                                          .watch(pbServiceProvider)
                                          .currentAvatarUrl !=
                                      null
                                  ? CachedNetworkImageProvider(ref
                                      .watch(pbServiceProvider)
                                      .currentAvatarUrl!)
                                  : null,
                              child: ref
                                          .watch(pbServiceProvider)
                                          .currentAvatarUrl ==
                                      null
                                  ? Icon(
                                      Icons.person, // 换成实心图标
                                      size: 28,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    )
                                  : null,
                            ),
                            if (ref.watch(pbServiceProvider).currentAvatarUrl ==
                                null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(auth.user?.getStringValue('name') ??
                              i18n.t('user')),
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
                          if (auth.isKOL) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                                  await ref
                                      .read(authProvider.notifier)
                                      .refreshUserFromServer();
                                  if (ref
                                          .read(authProvider)
                                          .user
                                          ?.getBoolValue('verified') ==
                                      true) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              i18n.t('verification_success')),
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

                  // 车辆部分 (如果是已认证用户)
                  if (auth.isAuthenticated) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: BrandLogo(
                        brandName: settings.brandRef ?? settings.brand ?? '',
                        showBackground: true,
                      ),
                      title: Row(
                        children: [
                          Text(
                            (settings.brand != null &&
                                    settings.brand!.length == 15 &&
                                    !settings.brand!.contains(' '))
                                ? ref.watch(brandNameProvider(settings.brand!))
                                : (settings.brand ??
                                    ref.watch(brandNameProvider(
                                        settings.brandRef ?? ''))),
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
                                  ref.watch(versionNameProvider(
                                      settings.softwareVersionRef ??
                                          settings.softwareVersion ??
                                          '')),
                                ].join(' • ').isEmpty ||
                                [
                                  if (settings.carModel != null &&
                                      settings.carModel!.isNotEmpty)
                                    settings.carModel,
                                  ref.watch(versionNameProvider(
                                      settings.softwareVersionRef ??
                                          settings.softwareVersion ??
                                          '')),
                                ].join(' • ').contains('...')
                            ? i18n.t('model_hint')
                            : [
                                if (settings.carModel != null &&
                                    settings.carModel!.isNotEmpty)
                                  settings.carModel,
                                ref.watch(versionNameProvider(
                                    settings.softwareVersionRef ??
                                        settings.softwareVersion ??
                                        '')),
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
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // 2. 我的数据卡片
              if (auth.isAuthenticated) ...[
                const MyDataCard(),
                const SizedBox(height: 16),
              ],

              // 3. 偏好设置卡片
              _buildCard(
                context,
                title: i18n.t('preferences'),
                children: [
                  // 主题设置
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.t('theme'),
                        style: const TextStyle(fontSize: 14)),
                    trailing: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabToggleItem(
                            context,
                            label: i18n.t('themeAuto'),
                            isSelected: settings.themeMode == ThemeMode.system,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setThemeMode(ThemeMode.system),
                          ),
                          _buildTabToggleItem(
                            context,
                            label: i18n.t('themeLight'),
                            isSelected: settings.themeMode == ThemeMode.light,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setThemeMode(ThemeMode.light),
                          ),
                          _buildTabToggleItem(
                            context,
                            label: i18n.t('themeDark'),
                            isSelected: settings.themeMode == ThemeMode.dark,
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setThemeMode(ThemeMode.dark),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 语言设置
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.t('language'),
                        style: const TextStyle(fontSize: 14)),
                    trailing: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabToggleItem(
                            context,
                            label: i18n.t('chinese'),
                            isSelected: settings.locale?.languageCode == 'zh',
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setLocale(const Locale('zh')),
                          ),
                          _buildTabToggleItem(
                            context,
                            label: i18n.t('english'),
                            isSelected: settings.locale?.languageCode == 'en',
                            onTap: () => ref
                                .read(settingsProvider.notifier)
                                .setLocale(const Locale('en')),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 负体验音效
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.t('event_sound'),
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      i18n.t('event_sound_desc'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _SquareSwitch(
                      value: settings.isEventSoundEnabled,
                      onChanged: (value) => ref
                          .read(settingsProvider.notifier)
                          .setEventSoundEnabled(value),
                    ),
                  ),

                  // 记录负体验视频
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.t('video_recording'),
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      i18n.t('video_recording_desc'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: _SquareSwitch(
                      value: settings.isVideoRecordingEnabled,
                      onChanged: (value) => ref
                          .read(settingsProvider.notifier)
                          .setVideoRecordingEnabled(value),
                    ),
                  ),

                  // 高帧率数据记录 (仅限 KOL 用户)
                  if (ref.watch(pbServiceProvider).isKOL)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i18n.t('high_frame_rate'),
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        i18n.t('high_frame_rate_desc'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: _SquareSwitch(
                        value: settings.isHighFrameRateEnabled,
                        onChanged: (value) => ref
                            .read(settingsProvider.notifier)
                            .setHighFrameRateEnabled(value),
                      ),
                    ),
                  // 语音记录说明 (仅对通过认证的 Pro 用户开放)
                  if (ref.watch(authProvider).isPro)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i18n.t('voice_recording'),
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        i18n.t('voice_recording_desc'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const VoiceRecordingInfoScreen(),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. 关于与支持卡片
              _buildCard(
                context,
                title: i18n.t('about'),
                children: [
                  _buildAboutTile(
                    context,
                    title: i18n.t('current_version'),
                    trailing: packageInfo.when(
                      data: (info) => Text('v${info.version}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                      loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => Text(i18n.t('unknown')),
                    ),
                  ),
                  _buildAboutTile(
                    context,
                    title: i18n.t('algorithm_version'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('v${algoConfig.version}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const Icon(Icons.chevron_right,
                            color: Colors.grey, size: 18),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AlgorithmConfigScreen()),
                    ),
                  ),
                  if (Theme.of(context).platform == TargetPlatform.android)
                    _buildAboutTile(
                      context,
                      title: i18n.t('check_update'),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 18),
                      onTap: () => UpdateService.checkUpdate(context,
                          showNoUpdate: true),
                    ),
                  _buildAboutTile(
                    context,
                    title: i18n.t('privacy_policy'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen()),
                    ),
                  ),
                  _buildAboutTile(
                    context,
                    title: i18n.t('delete_account'),
                    trailing: const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DeleteAccountScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {String? title, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: _headerStyle(context)),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggleItem(BuildContext context,
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label, // 移除 .toUpperCase()
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold, // 适当降低加粗，避免太拥挤
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      );

  Widget _buildAboutTile(
    BuildContext context, {
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            trailing,
          ],
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

  Future<void> _handleUpdateAvatar(BuildContext context, WidgetRef ref) async {
    final i18n = ref.read(i18nProvider); // 定义 i18n
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final toolbarColor = isDark
        ? const Color(0xFF1A1A1A)
        : Theme.of(context).colorScheme.primary;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      // 核心优化：限制最大尺寸和压缩质量（头像256x256即可满足显示需求）
      maxWidth: 256,
      maxHeight: 256,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: i18n.t('crop_avatar'),
          toolbarColor: toolbarColor,
          statusBarColor: toolbarColor,
          backgroundColor: backgroundColor,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: isDark
              ? const Color(0xFF1A1A1A)
              : Theme.of(context).colorScheme.primary,
          dimmedLayerColor: isDark ? Colors.black.withValues(alpha: 0.8) : null,
          cropFrameColor: isDark
              ? const Color(0xFF1A1A1A)
              : Theme.of(context).colorScheme.primary,
          cropGridColor: Colors.white.withValues(alpha: 0.5),
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: i18n.t('crop_avatar'),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          hidesNavigationBar: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    try {
      await ref
          .read(authProvider.notifier)
          .updateAvatar(File(croppedFile.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('avatar_updated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${i18n.t('update_avatar_failed')}: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

class _SquareSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SquareSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
