import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/recording/presentation/recording_screen.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 ProviderContainer
  final container = ProviderContainer();
  await container.read(storageServiceProvider).init();
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PickyPassengerApp(),
    ),
  );
}

class PickyPassengerApp extends ConsumerWidget {
  const PickyPassengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // 通用的黑体字体回退序列
    const fontFallback = [
      'PingFang SC',
      'Heiti SC',
      'Microsoft YaHei',
      'Source Han Sans SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ];

    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'PingFang SC', 
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
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7), // Apple System Gray 6
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF248A3D), // 更深邃的高级绿
          onPrimary: Colors.white,
          secondary: const Color(0xFF007AFF), // Apple Blue
          surface: Colors.white,
          onSurface: const Color(0xFF1C1C1E),
          surfaceVariant: const Color(0xFFE5E5EA), // Apple System Gray 4
          onSurfaceVariant: const Color(0xFF636366), // Apple System Gray
          outlineVariant: const Color(0xFFD1D1D6), // Apple System Gray 3
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      
      // 黑夜模式 (Apple Level Design)
      darkTheme: baseTheme.copyWith(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light, // 强制状态栏文字为白色
        ),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF32D74B), // Apple System Green Dark
          onPrimary: Colors.black,
          secondary: const Color(0xFF0A84FF), // Apple Blue Dark
          surface: const Color(0xFF1C1C1E), // Apple System Gray 6 Dark
          onSurface: const Color(0xFFF2F2F7),
          surfaceVariant: const Color(0xFF2C2C2E), // Apple System Gray 4 Dark
          onSurfaceVariant: const Color(0xFF8E8E93), // Apple System Gray
          outlineVariant: const Color(0xFF3A3A3C), // Apple System Gray 3 Dark
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      
      home: const RecordingScreen(),
    );
  }
}
