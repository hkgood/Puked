import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/presentation/recording_screen.dart';
import 'package:puked/features/history/presentation/history_screen.dart';
import 'package:puked/features/settings/presentation/settings_screen.dart';
import 'package:puked/features/arena/presentation/arena_screen.dart';
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:puked/common/utils/i18n.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const RecordingScreen(),
    const ArenaScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);

    return OrientationBuilder(
      builder: (context, orientation) {
        // 当在首页且是横屏时，自动切换到行程记录界面。
        // "首页" 指 _selectedIndex == 0 (RecordingScreen)
        if (orientation == Orientation.landscape && _selectedIndex == 0) {
          return const RecordingScreen();
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar:
              _selectedIndex == 0 && orientation == Orientation.landscape
                  ? null // 横屏下首页不显示 TabBar
                  : NavigationBar(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                        // 每次点击 Arena 标签时，主动触发云端数据刷新
                        if (index == 1) {
                          ref.read(arenaCloudTripsProvider.notifier).refresh();
                        }
                      },
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.radio_button_checked),
                          label: i18n.t('start_trip'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.leaderboard),
                          label: i18n.t('arena'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.history),
                          label: i18n.t('history'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings),
                          label: i18n.t('settings'),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
