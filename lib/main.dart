import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/main/presentation/main_screen.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/services/storage/storage_service.dart';
import 'package:puked/services/metadata_sync_service.dart';
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

  await container.read(storageServiceProvider).init();

  // 异步同步云端元数据（不阻塞启动）
  container.read(metadataSyncServiceProvider).syncBrandsFromCloud();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PukedApp(),
    ),
  );
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

    // 通用的黑体字体回退序列
    const fontFallback = [
      'Heiti SC',
      'Microsoft YaHei',
      'Source Han Sans SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ];

    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamilyFallback: fontFallback,
    );

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

      // 白天模式 (Apple Level Design)
      theme: baseTheme.copyWith(
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark, // 强制状态栏文字为深色
          backgroundColor: Color(0xFFF2F2F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF1C1C1E),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7), // Apple System Gray 6
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF248A3D), // 更深邃的高级绿
          onPrimary: Colors.white,
          secondary: Color(0xFF007AFF), // Apple Blue
          surface: Colors.white,
          onSurface: Color(0xFF1C1C1E),
          surfaceContainerHighest: Color(0xFFE5E5EA), // Apple System Gray 4
          onSurfaceVariant: Color(0xFF636366), // Apple System Gray
          outlineVariant: Color(0xFFD1D1D6), // Apple System Gray 3
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFF248A3D),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFF636366));
          }),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),

      // 黑夜模式 (Apple Level Design)
      darkTheme: baseTheme.copyWith(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light, // 强制状态栏文字为白色
          backgroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFFF2F2F7),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E8231), // 调暗后的绿色 (Forest Green style)
          onPrimary: Colors.white,
          secondary: Color(0xFF0A84FF), // Apple Blue Dark
          surface: Color(0xFF1C1C1E), // Apple System Gray 6 Dark
          onSurface: Color(0xFFF2F2F7),
          surfaceContainerHighest:
              Color(0xFF2C2C2E), // Apple System Gray 4 Dark
          onSurfaceVariant: Color(0xFFE5E5EA), // 显著加亮次要文字 (Apple System Gray 4)
          outlineVariant: Color(0xFF3A3A3C), // Apple System Gray 3 Dark
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFF1E8231),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFFE5E5EA));
          }),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF2F2F7)),
          bodyMedium: TextStyle(color: Color(0xFFF2F2F7)),
          bodySmall: TextStyle(color: Color(0xFFE5E5EA)), // 次要文字使用较亮的灰色
          labelSmall:
              TextStyle(color: Color(0xFFE5E5EA), fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),

      home: const MainScreen(),
    );
  }
}
