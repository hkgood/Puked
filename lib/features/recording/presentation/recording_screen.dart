import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/widgets/g_force_ball.dart';
import 'package:puked/common/widgets/sensor_waveform.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/features/history/presentation/history_screen.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/settings/presentation/settings_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/models/trip_event.dart';
import 'dart:collection';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 【关键优化】只监听 recordingProvider，它的更新频率较低 (1~2s)
    final recordingState = ref.watch(recordingProvider);
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;
    final i18n = ref.watch(i18nProvider);

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
                  // 顶部导航 (略...)
                  _buildHeader(context, i18n),

                  // 1. 地图展示 (现在它只会在 recordingState 改变时刷新)
                  Expanded(
                    child: _buildMapSection(recordingState),
                  ),

                  // 2. 高频监控区 (使用 Consumer 局部订阅 sensorStreamProvider)
                  _buildSensorSection(context, i18n),

                  const SizedBox(height: 16),

                  // 3. 交互控制
                  _buildControlSection(context, ref, recordingState,
                      isRecording, isCalibrating, i18n),
                ],
              ),
            ),

            // 校准遮罩层
            if (isCalibrating) _buildCalibrationOverlay(context, i18n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic i18n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              i18n.t('app_name').toUpperCase(),
              style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: onSurface, // 显式指定颜色
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsScreen())),
            icon: Icon(Icons.settings, size: 22, color: onSurface), // 显式指定颜色
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const HistoryScreen())),
            icon: Icon(Icons.history, size: 22, color: onSurface), // 显式指定颜色
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(RecordingState state) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: TripMapView(
                trajectory: state.trajectory,
                events: state.events,
                currentPosition: state.currentPosition,
              ),
            ),
          ),
          // 调试面板
          Positioned(
            top: 12,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("GPS Updates: ${state.locationUpdateCount}",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                  Text("Msg: ${state.debugMessage}",
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSensorSection(BuildContext context, dynamic i18n) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.23,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          // 【核心优化】高频订阅被限制在这里，只影响这一个小小的 Row
          final sensorDataAsync = ref.watch(sensorStreamProvider);
          return sensorDataAsync.maybeWhen(
            data: (data) => Row(
              children: [
                GForceBall(
                  acceleration: data.processedAccel,
                  gyroscope: data.gyroscope,
                  size: MediaQuery.of(context).size.width * 0.35,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _SensorWaveformSection(data: data, i18n: i18n),
                ),
              ],
            ),
            orElse: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildControlSection(
      BuildContext context,
      WidgetRef ref,
      RecordingState state,
      bool isRecording,
      bool isCalibrating,
      dynamic i18n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          if (isRecording) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('distance'),
                        value:
                            "${(state.currentDistance / 1000).toStringAsFixed(2)} km",
                        icon: Icons.straighten),
                  ),
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('peak_g'),
                        value: "${state.maxGForce.toStringAsFixed(2)}G",
                        icon: Icons.shutter_speed),
                  ),
                  ..._buildEventBreakdown(state.events, context),
                ],
              ),
            ),
            _TagButtonsGrid(ref: ref, i18n: i18n),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording
                    ? const Color(0xFFFF3B30)
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: isCalibrating
                  ? null
                  : () async {
                      if (isRecording) {
                        final tripId = state.currentTrip?.id;
                        await ref
                            .read(recordingProvider.notifier)
                            .stopRecording();
                        if (tripId != null && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VehicleInfoScreen(tripId: tripId),
                            ),
                          );
                        }
                      } else {
                        ref.read(recordingProvider.notifier).startRecording();
                      }
                    },
              child: Text(
                  isRecording ? i18n.t('stop_trip') : i18n.t('start_trip'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationOverlay(BuildContext context, dynamic i18n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
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
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
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
      if (count == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Icon(config['icon'] as IconData,
                size: 14, color: config['color'] as Color),
            const SizedBox(height: 2),
            Text("$count",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );
    }).toList();
  }
}

// 内部私有组件：波形图部分，独立管理历史记录以避免主页面刷新
class _SensorWaveformSection extends StatefulWidget {
  final dynamic data;
  final dynamic i18n;
  const _SensorWaveformSection({required this.data, required this.i18n});

  @override
  State<_SensorWaveformSection> createState() => _SensorWaveformSectionState();
}

class _SensorWaveformSectionState extends State<_SensorWaveformSection> {
  final ListQueue<double> _accelXHistory = ListQueue<double>();
  final ListQueue<double> _accelYHistory = ListQueue<double>();

  @override
  void didUpdateWidget(_SensorWaveformSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_accelXHistory.length >= 100) _accelXHistory.removeFirst();
    if (_accelYHistory.length >= 100) _accelYHistory.removeFirst();
    _accelXHistory.add(widget.data.processedAccel.x);
    _accelYHistory.add(widget.data.processedAccel.y);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SensorWaveform(
          data: _accelYHistory.toList(),
          color: Theme.of(context).colorScheme.primary,
          label: widget.i18n.t('longitudinal'),
        ),
        const Spacer(),
        SensorWaveform(
          data: _accelXHistory.toList(),
          color: Theme.of(context).colorScheme.secondary,
          label: widget.i18n.t('lateral'),
        ),
      ],
    );
  }
}

class _TagButtonsGrid extends StatelessWidget {
  final WidgetRef ref;
  final dynamic i18n;
  const _TagButtonsGrid({required this.ref, required this.i18n});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: [
        _TagButton(
          label: i18n.t('rapid_accel'),
          icon: Icons.speed,
          color: const Color(0xFFFF9500),
          onPressed: () => ref
              .read(recordingProvider.notifier)
              .tagEvent(EventType.rapidAcceleration),
        ),
        _TagButton(
          label: i18n.t('rapid_decel'),
          icon: Icons.trending_down,
          color: const Color(0xFFFF3B30),
          onPressed: () => ref
              .read(recordingProvider.notifier)
              .tagEvent(EventType.rapidDeceleration),
        ),
        _TagButton(
          label: i18n.t('bump'),
          icon: Icons.vibration,
          color: const Color(0xFF5856D6),
          onPressed: () =>
              ref.read(recordingProvider.notifier).tagEvent(EventType.bump),
        ),
        _TagButton(
          label: i18n.t('wobble'),
          icon: Icons.waves,
          color: const Color(0xFF007AFF),
          onPressed: () =>
              ref.read(recordingProvider.notifier).tagEvent(EventType.wobble),
        ),
      ],
    );
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
