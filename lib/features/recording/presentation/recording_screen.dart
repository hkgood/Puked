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
  bool _isSensorFocused = false;

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
    const double spacing = 16.0;
    const double smallCardHeight = 140.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildHeader(context, i18n),
          const SizedBox(height: 8), // 统一标题和卡片间距
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(animation),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1.0)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                );
              },
              child: _isSensorFocused
                  ? Column(
                      key: const ValueKey('sensor_focused'),
                      children: [
                        // 1. 传感器展示区 (大)
                        Expanded(
                          child: _buildFocusedSensorContent(context, i18n,
                              noMargin: true),
                        ),
                        const SizedBox(height: spacing),
                        // 2. 地图缩小 (小)
                        GestureDetector(
                          key: const ValueKey('map_small'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isSensorFocused = false),
                          child: SizedBox(
                            height: smallCardHeight,
                            child: _buildMapSection(recordingState,
                                isLandscape: false, noMargin: true),
                          ),
                        ),
                        const SizedBox(height: spacing),
                        _buildControlSection(context, ref, recordingState,
                            isRecording, isCalibrating, i18n,
                            noPadding: true),
                      ],
                    )
                  : Column(
                      key: const ValueKey('map_focused'),
                      children: [
                        // 1. 地图展示 (大)
                        Expanded(
                          child: _buildMapSection(recordingState,
                              isLandscape: false, noMargin: true),
                        ),
                        const SizedBox(height: spacing),
                        // 2. 传感器区域 (小)
                        _buildSensorSection(context, i18n,
                            height: smallCardHeight, noMargin: true),
                        const SizedBox(height: spacing),
                        _buildControlSection(context, ref, recordingState,
                            isRecording, isCalibrating, i18n,
                            noPadding: true),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: spacing), // 底部留白
        ],
      ),
    );
  }

  Widget _buildFocusedSensorContent(BuildContext context, dynamic i18n,
      {bool noMargin = false, bool isLandscape = false}) {
    return GestureDetector(
      key: ValueKey('focused_sensor_${isLandscape ? 'land' : 'port'}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isSensorFocused = false),
      child: Container(
        margin: noMargin
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(isLandscape ? 12 : 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: null,
          boxShadow: [
            if (isLandscape)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
          ],
        ),
        child: Consumer(
          builder: (context, ref, child) {
            final sensorDataAsync = ref.watch(sensorStreamProvider);
            return sensorDataAsync.maybeWhen(
              data: (data) {
                final gX = data.processedAccel.x / 9.80665;
                final gY = data.processedAccel.y / 9.80665;
                final gZ = (data.processedAccel.z - 9.80665) / 9.80665;

                return Column(
                  children: [
                    // 第一行：球体 + 实时 XYZ 参数
                    Row(
                      children: [
                        GForceBall(
                          acceleration: data.processedAccel,
                          gyroscope: data.gyroscope,
                          size: isLandscape
                              ? 56
                              : 64, // 进一步缩小球体 (从 64/72 降到 56/64)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildGValueRow(
                                  "X (LAT)", gX, const Color(0xFFE57373)),
                              const SizedBox(height: 2),
                              _buildGValueRow(
                                  "Y (LONG)", gY, const Color(0xFF81C784)),
                              const SizedBox(height: 2),
                              _buildGValueRow(
                                  "Z (VERT)", gZ, const Color(0xFF64B5F6)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 8 : 12),
                    // 第二、三行：波形图
                    Expanded(
                      flex: 6, // 再次增加图表权重 (从 5 提升到 6)
                      child: _SensorWaveformSection(
                        data: data,
                        i18n: i18n,
                        showAxes: true,
                        isLandscape: isLandscape,
                      ),
                    ),
                  ],
                );
              },
              orElse: () => const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGValueRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 0.5)),
        Text("${value >= 0 ? '+' : ''}${value.toStringAsFixed(3)}G",
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, WidgetRef ref,
      RecordingState recordingState, dynamic i18n) {
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;
    const double spacing = 16.0;

    // 计算地图中心偏移量
    final screenWidth = MediaQuery.sizeOf(context).width;
    const double mapShift = 168.0;

    return Stack(
      children: [
        // 1. 背景地图层
        Positioned(
          left: -mapShift * 2,
          top: 0,
          bottom: 0,
          width: screenWidth + mapShift * 2,
          child: _buildMapSection(recordingState, isLandscape: true),
        ),

        // 2. GPS 调试面板 (独立定位，不随地图移动)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              "GPS: ${recordingState.debugMessage}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 3. 前台交互层
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                spacing / 2, spacing, spacing, spacing), // 减少左侧边距一半
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, // 让子组件垂直铺满
              children: [
                // 左侧动态区域
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _isSensorFocused
                        ? _buildFocusedSensorContent(context, i18n,
                            noMargin: true, isLandscape: true)
                        : Align(
                            key: const ValueKey('landscape_hud_align'),
                            alignment: Alignment.bottomLeft,
                            child: _buildLandscapeHUD(context, i18n),
                          ),
                  ),
                ),
                const SizedBox(width: spacing),
                // 右侧面板
                _buildLandscapeControlConsole(context, ref, recordingState,
                    isRecording, isCalibrating, i18n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHUD(BuildContext context, dynamic i18n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      key: const ValueKey('landscape_hud'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isSensorFocused = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
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
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
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
        mainAxisSize: MainAxisSize.max, // 改为 max 以填充高度
        children: [
          // 顶部工具栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsScreen())),
                icon: Icon(Icons.settings_outlined, size: 20, color: onSurface),
              ),
              Text(
                'PUKED',
                style: TextStyle(
                    fontSize: 12, // 缩小字体
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: onSurface.withValues(alpha: 0.8)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HistoryScreen())),
                icon: Icon(Icons.history_outlined, size: 20, color: onSurface),
              ),
            ],
          ),

          const Divider(height: 16), // 从 24 降回 16，为按钮腾出空间

          if (isRecording) ...[
            // 统计数据
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('distance'),
                        value:
                            "${(state.currentDistance / 1000).toStringAsFixed(2)} km",
                        icon: Icons.straighten,
                        compact: true),
                  ),
                  _buildStatDivider(colorScheme, height: 16),
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('peak_g'),
                        value: "${state.maxGForce.toStringAsFixed(2)}G",
                        icon: Icons.shutter_speed,
                        compact: true),
                  ),
                  _buildStatDivider(colorScheme, height: 16),
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('neg_exp'),
                        value: "${state.events.length}",
                        icon: Icons.error_outline,
                        compact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 按钮区域
            GridView.count(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6, // 从 2.2 调回 2.6，在高度和空间之间取得平衡
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
          ] else
            Expanded(
              child: Center(
                child: Icon(Icons.rocket_launch_outlined,
                    size: 40, color: onSurface.withValues(alpha: 0.2)),
              ),
            ),

          const Spacer(), // 无论是否录制，都使用 Spacer 将主按钮推至底部，确保位置绝对一致
          _buildMainActionButton(
              context, ref, state, isRecording, isCalibrating, i18n,
              isLandscape: true),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 4), // 减小左侧边距，因为外层已有 Padding
      child: Row(
        children: [
          Expanded(
            child: Text(
              i18n.t('app_name').toUpperCase(),
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(RecordingState state,
      {bool isLandscape = false, bool noMargin = false}) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            margin: (isLandscape || noMargin)
                ? EdgeInsets.zero
                : const EdgeInsets.only(
                    bottom: 12), // 移除左右 16px 边距，由父容器 Padding 统一控制
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius:
                  isLandscape ? BorderRadius.zero : BorderRadius.circular(24),
              border: null,
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
            top: (isLandscape || noMargin) ? 12 : 16,
            left: (isLandscape || noMargin) ? 12 : 16, // 同步调整
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                "GPS: ${state.debugMessage}",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSensorSection(BuildContext context, dynamic i18n,
      {double height = 140, bool noMargin = false}) {
    return GestureDetector(
      key: const ValueKey('small_sensor_section'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _isSensorFocused = true;
        });
      },
      child: Container(
        height: height,
        margin: noMargin ? EdgeInsets.zero : EdgeInsets.zero, // 统一移除内边距
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: null,
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
                    size: height * 0.7, // 动态调整球体大小
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _SensorWaveformSection(
                      data: data,
                      i18n: i18n,
                      showAxes: false,
                    ),
                  ),
                ],
              ),
              orElse: () => const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlSection(BuildContext context, WidgetRef ref,
      RecordingState state, bool isRecording, bool isCalibrating, dynamic i18n,
      {bool noPadding = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: noPadding ? 0 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16), // 与主按钮圆角保持一致 (16)
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('distance'),
                        value:
                            "${(state.currentDistance / 1000).toStringAsFixed(2)} km",
                        icon: Icons.straighten,
                        compact: true),
                  ),
                  _buildStatDivider(colorScheme, height: 24),
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('peak_g'),
                        value: "${state.maxGForce.toStringAsFixed(2)}G",
                        icon: Icons.shutter_speed,
                        compact: true),
                  ),
                  _buildStatDivider(colorScheme, height: 24),
                  Expanded(
                    child: _RecordingStat(
                        label: i18n.t('neg_exp'),
                        value: "${state.events.length}",
                        icon: Icons.error_outline,
                        compact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 竖屏下使用更紧凑的 Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
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
            const SizedBox(height: 16),
          ],
          _buildMainActionButton(
              context, ref, state, isRecording, isCalibrating, i18n),
        ],
      ),
    );
  }

  Widget _buildStatDivider(ColorScheme colorScheme, {double height = 24}) {
    return Container(
      width: 1,
      height: height,
      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
  final bool showAxes;
  const _SensorWaveformSection({
    required this.data,
    required this.i18n,
    this.isLandscape = false,
    this.showAxes = false,
  });

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
    _accelXHistory.add(widget.data.processedAccel.x / 9.80665); // 转换为 G
    _accelYHistory.add(widget.data.processedAccel.y / 9.80665); // 转换为 G
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
            limit: 1.5, // G力视图通常在 1.5G 范围内
            showAxes: widget.showAxes,
          ),
        ),
        SizedBox(height: widget.showAxes ? 16 : 8),
        Expanded(
          child: SensorWaveform(
            data: _accelXHistory.toList(),
            color: Theme.of(context).colorScheme.secondary,
            label: widget.isLandscape ? '' : widget.i18n.t('lateral'),
            limit: 1.5,
            showAxes: widget.showAxes,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: compact ? 12 : 14,
                color: colorScheme.primary), // 移除不必要的透明度，直接使用主色
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900, // 增加字重
                    color: colorScheme.onSurface)),
          ],
        ),
        Text(label.toUpperCase(), // 统一使用大写并加亮
            style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurfaceVariant)),
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
