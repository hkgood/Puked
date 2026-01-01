import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/main/presentation/main_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/common/theme/app_theme.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/metadata_sync_service.dart';
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PukedApp(),
    ),
  );

  // 将耗时的初始化移到后台执行，避免阻塞 iOS 渲染
  Future.microtask(() async {
    try {
      await container.read(storageServiceProvider).init();
      // 启动后尝试同步元数据
      await container.read(metadataSyncServiceProvider).syncBrandsFromCloud();
      // 主动触发一次 Arena 数据加载
      await container.read(arenaCloudTripsProvider.notifier).refresh();
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

      home: const MainScreen(),
    );
  }
}
