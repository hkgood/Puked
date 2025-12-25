import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/widgets/g_force_ball.dart';
import 'package:puked/common/widgets/sensor_waveform.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/features/history/presentation/history_screen.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/settings/presentation/settings_screen.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/models/trip_event.dart';
import 'dart:collection';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  final ListQueue<double> _accelXHistory = ListQueue<double>();
  final ListQueue<double> _accelYHistory = ListQueue<double>();

  @override
  Widget build(BuildContext context) {
    final sensorDataAsync = ref.watch(sensorStreamProvider);
    final recordingState = ref.watch(recordingProvider);
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;
    final i18n = ref.watch(i18nProvider);

    sensorDataAsync.whenData((data) {
      if (_accelXHistory.length >= 100) _accelXHistory.removeFirst();
      if (_accelYHistory.length >= 100) _accelYHistory.removeFirst();
      _accelXHistory.add(data.processedAccel.x);
      _accelYHistory.add(data.processedAccel.y);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // 0. 顶部导航
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        20, 10, 16, 8), // 从 4 增加回 8，平衡间距
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            i18n.t('app_name').toUpperCase(),
                            style: TextStyle(
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const SettingsScreen())),
                          icon: Icon(Icons.settings,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 22),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.1), // 白天模式下降低背景深度
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const HistoryScreen())),
                          icon: Icon(Icons.history,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 22),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.3
                                    : 0.1), // 同上
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 1. 地图展示 (自适应高度)
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      return Container(
                        margin: const EdgeInsets.fromLTRB(
                            16, 4, 16, 12), // 顶部间距从 0 增加回 4
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withOpacity(0.5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: TripMapView(
                            trajectory: recordingState.trajectory,
                            events: recordingState.events,
                            currentPosition: recordingState.currentPosition,
                          ),
                        ),
                      );
                    }),
                  ),

                  // 2. 监控区 (调整高度比例和内边距)
                  Container(
                    height: MediaQuery.of(context).size.height *
                        0.23, // 稍微压缩高度从 0.25 到 0.23
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        // G-Force Ball
                        sensorDataAsync.maybeWhen(
                          data: (data) => GForceBall(
                            acceleration: data.processedAccel,
                            gyroscope: data.gyroscope,
                            size: MediaQuery.of(context).size.width *
                                0.35, // 缩小尺寸从 0.4 到 0.35
                          ),
                          orElse: () => Container(
                              width: MediaQuery.of(context).size.width * 0.35,
                              height: MediaQuery.of(context).size.width * 0.35,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(0.1))),
                        ),
                        const SizedBox(width: 20), // 增加间距
                        // Waveforms
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SensorWaveform(
                                data: _accelYHistory.toList(),
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary, // 使用主题绿色，解决过暗问题
                                label: i18n.t('longitudinal'),
                              ),
                              const Spacer(),
                              SensorWaveform(
                                data: _accelXHistory.toList(),
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary, // 使用主题蓝色
                                label: i18n.t('lateral'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. 交互控制
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        if (isRecording) ...[
                          // 行程统计实时展示
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _RecordingStat(
                                  label: i18n.t('distance'),
                                  value:
                                      "${(recordingState.currentDistance / 1000).toStringAsFixed(2)} km",
                                  icon: Icons.straighten,
                                ),
                                _RecordingStat(
                                  label: i18n.t('peak_g'),
                                  value:
                                      "${recordingState.maxGForce.toStringAsFixed(2)}G",
                                  icon: Icons.shutter_speed,
                                ),
                                // 各类事件分类计数
                                ..._buildEventBreakdown(
                                    recordingState.events, context),
                              ],
                            ),
                          ),
                          GridView.count(
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.5,
                            children: [
                              _TagButton(
                                label: i18n.t('rapid_accel'),
                                icon: Icons.speed,
                                color: const Color(0xFFFF9500), // Apple Orange
                                onPressed: () {
                                  ref
                                      .read(recordingProvider.notifier)
                                      .tagEvent(EventType.rapidAcceleration);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(i18n.t('recorded_msg')),
                                        duration: const Duration(seconds: 1)),
                                  );
                                },
                              ),
                              _TagButton(
                                label: i18n.t('rapid_decel'),
                                icon: Icons.trending_down,
                                color: const Color(0xFFFF3B30), // Apple Red
                                onPressed: () {
                                  ref
                                      .read(recordingProvider.notifier)
                                      .tagEvent(EventType.rapidDeceleration);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(i18n.t('recorded_msg')),
                                        duration: const Duration(seconds: 1)),
                                  );
                                },
                              ),
                              _TagButton(
                                label: i18n.t('bump'),
                                icon: Icons.vibration,
                                color: const Color(0xFF5856D6), // Apple Indigo
                                onPressed: () {
                                  ref
                                      .read(recordingProvider.notifier)
                                      .tagEvent(EventType.bump);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(i18n.t('recorded_msg')),
                                        duration: const Duration(seconds: 1)),
                                  );
                                },
                              ),
                              _TagButton(
                                label: i18n.t('wobble'),
                                icon: Icons.waves,
                                color: const Color(0xFF007AFF), // Apple Blue
                                onPressed: () {
                                  ref
                                      .read(recordingProvider.notifier)
                                      .tagEvent(EventType.wobble);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(i18n.t('recorded_msg')),
                                        duration: const Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRecording
                                  ? const Color(0xFFFF3B30) // Apple Red
                                  : Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0, // 扁平化高级感
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: isCalibrating
                                ? null
                                : () {
                                    if (isRecording) {
                                      ref
                                          .read(recordingProvider.notifier)
                                          .stopRecording();
                                    } else {
                                      ref
                                          .read(recordingProvider.notifier)
                                          .startRecording();
                                    }
                                  },
                            child: Text(
                                isRecording
                                    ? i18n.t('stop_trip')
                                    : i18n.t('start_trip'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 校准遮罩层
            if (isCalibrating)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 24),
                      Text(i18n.t('calibrating'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(i18n.t('calibration_tip'),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventBreakdown(
      List<dynamic> events, BuildContext context) {
    final counts = <String, int>{};
    for (var e in events) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }

    // 定义我们关心的四种核心类型
    final types = [
      {
        'type': 'rapidAcceleration',
        'icon': Icons.speed,
        'color': const Color(0xFFFF9500)
      },
      {
        'type': 'rapidDeceleration',
        'icon': Icons.trending_down,
        'color': const Color(0xFFFF3B30)
      },
      {
        'type': 'bump',
        'icon': Icons.vibration,
        'color': const Color(0xFF5856D6)
      },
      {'type': 'wobble', 'icon': Icons.waves, 'color': const Color(0xFF007AFF)},
    ];

    return types.map((config) {
      final count = counts[config['type']] ?? 0;
      if (count == 0) return const SizedBox.shrink(); // 没发生就不显示，节省空间

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(config['icon'] as IconData,
                size: 14, color: config['color'] as Color),
            const SizedBox(height: 2),
            Text(
              "$count",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _RecordingStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RecordingStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TagButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _TagButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDarkMode ? color.withOpacity(0.12) : color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: color.withOpacity(isDarkMode ? 0.3 : 0.2), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                    color: isDarkMode
                        ? color.withOpacity(0.9)
                        : color.withAlpha(200),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
