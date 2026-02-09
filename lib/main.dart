import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 补全 kIsWeb 所在的包
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/main/presentation/main_screen.dart';
import 'package:puked/features/onboarding/presentation/onboarding_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/common/theme/app_theme.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/metadata_sync_service.dart';
import 'package:puked/services/media_key_service.dart'; // 新增
import 'package:puked/services/logo_cache_service.dart'; // Logo 缓存服务
import 'package:puked/services/update_service.dart'; // 更新服务
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化持久化存储
  final prefs = await SharedPreferences.getInstance();

  // 初始化 ProviderContainer
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // 初始化媒体按键监听 (蓝牙耳机)
  if (!kIsWeb) {
    final handler = await initMediaKeyHandler(container);
    container.read(mediaKeyHandlerProvider.notifier).state = handler;
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PukedApp(),
    ),
  );

  // 将耗时的初始化移到后台执行，避免阻塞 iOS 渲染
  Future.microtask(() async {
    try {
      // 清理可能卡住的下载状态
      await UpdateService.cleanupStaleDownloadState();

      await container.read(storageServiceProvider).init();

      // 启动后尝试同步元数据
      await container.read(metadataSyncServiceProvider).syncBrandsFromCloud();

      // 【新增】Logo 预加载：首次启动或版本更新时下载所有 Logo 到缓存
      final logoCache = container.read(logoCacheServiceProvider);
      if (logoCache.needsPreload) {
        debugPrint('[Main] 开始预加载 Logo 缓存...');
        await logoCache.preloadLogos(
          onProgress: (current, total, brandName) {
            debugPrint('[Main] Logo 预加载进度: $current/$total ($brandName)');
          },
        );
        debugPrint('[Main] Logo 预加载完成！');
      } else {
        debugPrint('[Main] Logo 缓存已是最新，跳过预加载');
      }

      // 主动触发一次 Arena 统计快照加载
      await container.read(arenaStatsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  });
}

class PukedApp extends ConsumerStatefulWidget {
  const PukedApp({super.key});

  @override
  ConsumerState<PukedApp> createState() => _PukedAppState();
}

class _PukedAppState extends ConsumerState<PukedApp> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Puked',
      debugShowCheckedModeBanner: false,

      // 国际化配置
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      locale: settings.locale,

      // 主题配置
      themeMode: settings.themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      home: settings.isFirstLaunch
          ? const OnboardingScreen()
          : const MainScreen(),
    );
  }
}
