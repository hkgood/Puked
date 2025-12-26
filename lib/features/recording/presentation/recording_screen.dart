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
import 'package:puked/services/update_service.dart';
import 'dart:collection';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  @override
  void initState() {
    super.initState();
    // 启动时检查更新：延迟3秒，确保进入首页后环境已完全准备好
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateService.checkUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final isCalibrating = recordingState.isCalibrating;
    final i18n = ref.watch(i18nProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 防止键盘弹出引起布局变化
        body: Stack(
          children: [
            // 基础布局层
            OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.portrait) {
                  return SafeArea(
                    child: _buildPortraitLayout(
                        context, ref, recordingState, i18n),
                  );
                } else {
                  // 横屏下自定义 SafeArea 处理，保证全屏地图感
                  return _buildLandscapeLayout(
                      context, ref, recordingState, i18n);
                }
              },
            ),

            // 校准遮罩层
            if (isCalibrating) _buildCalibrationOverlay(context, i18n),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, WidgetRef ref,
      RecordingState recordingState, dynamic i18n) {
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;

    return Column(
      children: [
        _buildHeader(context, i18n),
        // 1. 地图展示 (高度动态平衡)
        Expanded(
          flex: 4,
          child: _buildMapSection(recordingState),
        ),
        // 2. 下方内容区 (固定高度优先)
        Container(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSensorSection(context, i18n),
              const SizedBox(height: 12),
              _buildControlSection(context, ref, recordingState, isRecording,
                  isCalibrating, i18n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, WidgetRef ref,
      RecordingState recordingState, dynamic i18n) {
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;

    return Stack(
      children: [
        // 1. 全屏沉浸式地图
        Positioned.fill(
          child: _buildMapSection(recordingState, isLandscape: true),
        ),

        // 2. 悬浮仪表盘 (左下角)
        Positioned(
          left: 16,
          bottom: 16,
          child: _buildLandscapeHUD(context, i18n),
        ),

        // 3. 悬浮控制中心 (右侧)
        Positioned(
          top: 16,
          right: 16,
          bottom: 16,
          child: _buildLandscapeControlConsole(
              context, ref, recordingState, isRecording, isCalibrating, i18n),
        ),
      ],
    );
  }

  Widget _buildLandscapeHUD(BuildContext context, dynamic i18n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // 动态适配白天/黑夜模式的 HUD 背景
        color: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final sensorDataAsync = ref.watch(sensorStreamProvider);
          return sensorDataAsync.maybeWhen(
            data: (data) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GForceBall(
                  acceleration: data.processedAccel,
                  gyroscope: data.gyroscope,
                  size: 64,
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 150,
                  height: 80,
                  child: _SensorWaveformSection(
                      data: data, i18n: i18n, isLandscape: true),
                ),
              ],
            ),
            orElse: () => const SizedBox(width: 234, height: 80),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeControlConsole(
      BuildContext context,
      WidgetRef ref,
      RecordingState state,
      bool isRecording,
      bool isCalibrating,
      dynamic i18n) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 在黑夜模式下使用更细腻的半透明度
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12))
        ],
      ),
      child: Column(
        children: [
          // 顶部小工具栏 (修复颜色可见性)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen())),
                icon: Icon(Icons.settings_outlined, size: 22, color: onSurface),
              ),
              Text(
                i18n.t('app_name').toUpperCase(),
                style: TextStyle(
                    fontSize: 14, // 从 11 增大到 14
                    letterSpacing: 2.0, // 增加字间距提升高级感
                    fontWeight: FontWeight.w900,
                    color: onSurface.withValues(alpha: 0.8)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryScreen())),
                icon: Icon(Icons.history_outlined, size: 22, color: onSurface),
              ),
            ],
          ),

          const Divider(height: 24),

          if (isRecording) ...[
            // 统计数据 (显式颜色)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildQuickStat(i18n.t('distance'),
                      "${(state.currentDistance / 1000).toStringAsFixed(2)}km",
                      color: onSurface),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                Expanded(
                  child: _buildQuickStat(i18n.t('peak_g'),
                      "${state.maxGForce.toStringAsFixed(2)}G",
                      color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
                children: [
                  _TagButton(
                    label: i18n.t('rapid_accel'),
                    icon: Icons.speed,
                    color: const Color(0xFFFF9500),
                    onPressed: () => ref
                        .read(recordingProvider.notifier)
                        .tagEvent(EventType.rapidAcceleration),
                    compact: true,
                  ),
                  _TagButton(
                    label: i18n.t('rapid_decel'),
                    icon: Icons.trending_down,
                    color: const Color(0xFFFF3B30),
                    onPressed: () => ref
                        .read(recordingProvider.notifier)
                        .tagEvent(EventType.rapidDeceleration),
                    compact: true,
                  ),
                  _TagButton(
                    label: i18n.t('bump'),
                    icon: Icons.vibration,
                    color: const Color(0xFF5856D6),
                    onPressed: () => ref
                        .read(recordingProvider.notifier)
                        .tagEvent(EventType.bump),
                    compact: true,
                  ),
                  _TagButton(
                    label: i18n.t('wobble'),
                    icon: Icons.waves,
                    color: const Color(0xFF007AFF),
                    onPressed: () => ref
                        .read(recordingProvider.notifier)
                        .tagEvent(EventType.wobble),
                    compact: true,
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
                child: Center(
                    child: Icon(Icons.rocket_launch_outlined,
                        size: 56, color: onSurface.withValues(alpha: 0.2)))),

          const SizedBox(height: 16),
          _buildMainActionButton(
              context, ref, state, isRecording, isCalibrating, i18n,
              isLandscape: true),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5)),
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMainActionButton(BuildContext context, WidgetRef ref,
      RecordingState state, bool isRecording, bool isCalibrating, dynamic i18n,
      {bool isLandscape = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isRecording
              ? const Color(0xFFFF3B30)
              : Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 14 : 18),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isCalibrating
            ? null
            : () async {
                if (isRecording) {
                  final tripId = state.currentTrip?.id;
                  await ref.read(recordingProvider.notifier).stopRecording();
                  if (tripId != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleInfoScreen(tripId: tripId),
                      ),
                    );
                  }
                } else {
                  ref.read(recordingProvider.notifier).startRecording();
                }
              },
        child: Text(
          isRecording ? i18n.t('stop_trip') : i18n.t('start_trip'),
          style: TextStyle(
              fontSize: isLandscape ? 16 : 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic i18n) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              i18n.t('app_name').toUpperCase(),
              style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsScreen())),
            icon: Icon(Icons.settings_outlined, color: onSurface),
          ),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => const HistoryScreen())),
            icon: Icon(Icons.history_outlined, color: onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(RecordingState state, {bool isLandscape = false}) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            margin: isLandscape
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.1),
              borderRadius:
                  isLandscape ? BorderRadius.zero : BorderRadius.circular(24),
              border: isLandscape
                  ? null
                  : Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5)),
            ),
            child: ClipRRect(
              borderRadius:
                  isLandscape ? BorderRadius.zero : BorderRadius.circular(24),
              child: TripMapView(
                trajectory: state.trajectory,
                events: state.events,
                currentPosition: state.currentPosition,
              ),
            ),
          ),
          // 调试面板 (在横屏下更小)
          Positioned(
            top: 12,
            left: isLandscape ? 12 : 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("GPS: ${state.debugMessage}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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
      height: 140, // 竖屏下也给固定高度，确保布局可预测
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
          final sensorDataAsync = ref.watch(sensorStreamProvider);
          return sensorDataAsync.maybeWhen(
            data: (data) => Row(
              children: [
                GForceBall(
                  acceleration: data.processedAccel,
                  gyroscope: data.gyroscope,
                  size: 100, // 竖屏可以稍大
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RecordingStat(
                    label: i18n.t('distance'),
                    value:
                        "${(state.currentDistance / 1000).toStringAsFixed(2)} km",
                    icon: Icons.straighten,
                    compact: true),
                _RecordingStat(
                    label: i18n.t('peak_g'),
                    value: "${state.maxGForce.toStringAsFixed(2)}G",
                    icon: Icons.shutter_speed,
                    compact: true),
              ],
            ),
            const SizedBox(height: 12),
            // 竖屏下使用更紧凑的 Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
              children: [
                _TagButton(
                  label: i18n.t('rapid_accel'),
                  icon: Icons.speed,
                  color: const Color(0xFFFF9500),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidAcceleration),
                  compact: true,
                ),
                _TagButton(
                  label: i18n.t('rapid_decel'),
                  icon: Icons.trending_down,
                  color: const Color(0xFFFF3B30),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidDeceleration),
                  compact: true,
                ),
                _TagButton(
                  label: i18n.t('bump'),
                  icon: Icons.vibration,
                  color: const Color(0xFF5856D6),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.bump),
                  compact: true,
                ),
                _TagButton(
                  label: i18n.t('wobble'),
                  icon: Icons.waves,
                  color: const Color(0xFF007AFF),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.wobble),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildMainActionButton(
              context, ref, state, isRecording, isCalibrating, i18n),
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
}

// 内部私有组件：波形图部分，独立管理历史记录以避免主页面刷新
class _SensorWaveformSection extends StatefulWidget {
  final dynamic data;
  final dynamic i18n;
  final bool isLandscape;
  const _SensorWaveformSection(
      {required this.data, required this.i18n, this.isLandscape = false});

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
        Expanded(
          child: SensorWaveform(
            data: _accelYHistory.toList(),
            color: Theme.of(context).colorScheme.primary,
            label: widget.isLandscape ? '' : widget.i18n.t('longitudinal'),
          ),
        ),
        if (!widget.isLandscape) const SizedBox(height: 8),
        Expanded(
          child: SensorWaveform(
            data: _accelXHistory.toList(),
            color: Theme.of(context).colorScheme.secondary,
            label: widget.isLandscape ? '' : widget.i18n.t('lateral'),
          ),
        ),
      ],
    );
  }
}

class _RecordingStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool compact;
  const _RecordingStat({
    required this.label,
    required this.value,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: compact ? 12 : 14,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: compact ? 16 : 18, fontWeight: FontWeight.w800)),
          ],
        ),
        Text(label,
            style: TextStyle(
                fontSize: compact ? 10 : 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _TagButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool compact;
  const _TagButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: compact ? 44 : 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: compact ? 18 : 22),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : 15)),
            ],
          ),
        ),
      ),
    );
  }
}
