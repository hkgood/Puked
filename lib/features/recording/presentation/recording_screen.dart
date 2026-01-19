import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/widgets/g_force_ball.dart';
import 'package:puked/common/widgets/sensor_waveform.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/history/presentation/history_screen.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/settings/presentation/settings_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/models/trip_event.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/update_service.dart';
import 'package:puked/services/pocketbase_service.dart'; // 新增
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:collection';
import 'dart:ui';
import 'dart:async';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _isSensorFocused = false;
  bool _showEventPopup = false;
  bool _showVoiceTutorial = false;
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    // 启动时检查更新：延迟3秒，确保进入首页后环境已完全准备好
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Theme.of(context).platform == TargetPlatform.android) {
        UpdateService.checkUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final isCalibrating = recordingState.isCalibrating;
    final l10n = AppLocalizations.of(context)!;

    // 动态计算地图中心偏移量，确保中心点处于“可见区域”的几何中心
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // 1. 顶部遮挡：安全区 + 边距(8) + HUD高度(约40)
    double topOverlay = topPadding + 8 + 40;
    if (recordingState.isRecording) {
      // 加上里程统计胶囊的高度(40)和间距(8)
      topOverlay += 8 + 40;
    }

    // 2. 底部遮挡：安全区 + 主按钮(56) + 传感器卡片(130/420) + 各级间距(12)
    double bottomOverlay =
        bottomPadding + 12 + 56 + 12 + (_isSensorFocused ? 420 : 130);
    if (recordingState.isRecording) {
      // 加上手动事件按钮行的高度(约85)和额外间距(12)
      bottomOverlay += 12 + 85;
    }

    // 3. 计算偏移：(顶部遮挡 - 底部遮挡) / 2
    // 如果底部遮挡多，Offset 为负，地图中心会上移
    final Offset centerOffset = Offset(0, (topOverlay - bottomOverlay) / 2);

    // 监听警告信息并弹出对话框
    ref.listen<String?>(
      recordingProvider.select((s) => s.alertMessage),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(l10n.calibration_failed),
                ],
              ),
              content: Text(next),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(recordingProvider.notifier).clearAlert();
                    Navigator.pop(context);
                  },
                  child: Text(l10n.ok),
                ),
              ],
            ),
          );
        }
      },
    );

    return Stack(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // 基础布局层
                OrientationBuilder(
                  builder: (context, orientation) {
                    if (orientation == Orientation.portrait) {
                      return Stack(
                        children: [
                          // 背景地图
                          Positioned.fill(
                            child: _buildMapSection(recordingState,
                                isLandscape: false,
                                noMargin: true,
                                isBackground: true,
                                centerOffset: centerOffset), // 传入偏移量
                          ),
                          // 顶部阴影遮罩
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 200,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.5),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildPortraitLayout(
                              context, ref, recordingState, l10n),
                        ],
                      );
                    } else {
                      return _buildLandscapeLayout(
                          context, ref, recordingState, l10n);
                    }
                  },
                ),

                // 校准遮罩层
                if (isCalibrating) _buildCalibrationOverlay(context, l10n),

                // 语音录制状态遮罩
                if (recordingState.isVoiceRecording)
                  _buildVoiceRecordingOverlay(context, recordingState),
              ],
            ),
          ),
        ),
        if (_showVoiceTutorial) _buildVoiceTutorialOverlay(context, l10n),
      ],
    );
  }

  Widget _buildVoiceRecordingOverlay(
      BuildContext context, RecordingState state) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(l10n.recording_voice,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                state.currentTranscription ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context, WidgetRef ref,
      RecordingState recordingState, AppLocalizations l10n) {
    final isRecording = recordingState.isRecording;
    final isCalibrating = recordingState.isCalibrating;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部栏：GPS 信号 & 算法按钮 (保持在顶部)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildGpsStatusTag(recordingState, l10n),
                          _buildAlgorithmToggle(context, recordingState),
                        ],
                      ),
                      // 中央优雅的 APP 名字展示
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'PUKED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8.0,
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black)
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isRecording) ...[
                    const SizedBox(height: 8),
                    _buildStatsCapsule(context, recordingState, l10n),
                  ],
                ],
              ),
            ),

            // 占位符：将后续内容推到底部，但如果弹窗开启，它需要靠上
            if (!_showEventPopup) const Spacer(),

            // 2. 中间内容区：传感器或历史浮窗 (靠下对齐)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: _showEventPopup
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    alignment: _showEventPopup
                        ? Alignment.topCenter
                        : Alignment.bottomCenter,
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                          parent: animation, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                );
              },
              child: _showEventPopup
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // 动态计算最大高度，避免覆盖传感器区域（假设传感器高度130+间距）
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: _buildEventHistoryPopup(
                            context, recordingState, l10n),
                      ),
                    )
                  : Container(
                      key: ValueKey('sensor_container_${_isSensorFocused}'),
                      height: _isSensorFocused ? 420 : 130,
                      child: _isSensorFocused
                          ? _buildFocusedSensorContent(context, l10n,
                              noMargin: true)
                          : _buildSensorSection(context, l10n,
                              height: 130, noMargin: true),
                    ),
            ),

            if (_showEventPopup) const Spacer(), // 弹窗开启时，下方留白

            const SizedBox(height: 12), // 减少间距 (16->12)

            // 3. 底部控制区 (手动按钮 + 开始/结束)
            if (isRecording) ...[
              _buildManualActionRow(context, ref, l10n),
              const SizedBox(height: 12), // 减少间距 (16->12)
            ],
            _buildMainActionButton(
                context, ref, recordingState, isRecording, isCalibrating, l10n),
            const SizedBox(height: 12), // 减少底部间距 (16->12)
          ],
        ),
      ),
    );
  }

  // Apple 风格：算法切换小 Tag
  Widget _buildAlgorithmToggle(BuildContext context, RecordingState state) {
    return Consumer(builder: (context, ref, child) {
      final l10n = AppLocalizations.of(context)!;
      final auth = ref.watch(authProvider);
      // 语音打标功能：仅对通过认证的 Pro 用户开放
      if (!auth.isPro) return const SizedBox.shrink();

      return GestureDetector(
        onTap: () async {
          final notifier = ref.read(recordingProvider.notifier);
          final wasEnabled = state.isVoiceRecordingEnabled;

          notifier.toggleVoiceRecordingEnabled();
          HapticFeedback.lightImpact();

          // 如果是从关到开，且从未显示过指引，则弹出遮罩
          if (!wasEnabled) {
            final prefs = await SharedPreferences.getInstance();
            final shown = prefs.getBool('voice_tutorial_shown') ?? false;
            if (!shown) {
              setState(() => _showVoiceTutorial = true);
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 32,
              constraints: const BoxConstraints(minWidth: 80),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              child: Stack(
                children: [
                  // 1. 背景进度条 (只有下载中才显示)
                  if (state.isDownloading)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: state.downloadProgress.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF007AFF).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  // 2. 状态背景色 (下载完成且开启时显示)
                  if (!state.isDownloading && state.isVoiceRecordingEnabled)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CD964).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  // 3. 文字和图标
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            state.isDownloading
                                ? Icons.downloading
                                : (state.isVoiceError
                                    ? Icons.error_outline
                                    : (state.isVoiceRecordingEnabled
                                        ? Icons.mic
                                        : Icons.mic_off)),
                            color: state.isVoiceError
                                ? Colors.redAccent
                                : Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isDownloading
                                ? "${(state.downloadProgress * 100).toInt()}%"
                                : (state.isVoiceError
                                    ? l10n.fail
                                    : (state.isVoiceRecordingEnabled
                                        ? l10n.pro_on
                                        : l10n.pro_off)),
                            style: TextStyle(
                                color: state.isVoiceError
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // Apple 风格：数据统计胶囊 (里程、G、负体验)
  Widget _buildStatsCapsule(
      BuildContext context, RecordingState state, AppLocalizations l10n) {
    final i18n = ref.watch(i18nProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _showEventPopup = !_showEventPopup;
              if (_showEventPopup) {
                _isSensorFocused = false;
              }
            });
            _resetPopupTimer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                      context,
                      (state.currentSpeed * 3.6).toStringAsFixed(0),
                      l10n.speed.toUpperCase(),
                      unit: i18n.t('speed_unit', args: ['']).trim()),
                ),
                _buildStatDivider(height: 28),
                Expanded(
                  child: _buildStatItem(
                      context,
                      (state.currentDistance / 1000).toStringAsFixed(1),
                      l10n.distance.toUpperCase(),
                      unit: i18n.t('user_mileage_unit')),
                ),
                _buildStatDivider(height: 28),
                Expanded(
                  child: _buildStatItem(
                      context,
                      state.currentGForce.toStringAsFixed(2),
                      l10n.realtime_g.toUpperCase(),
                      unit: "G"),
                ),
                _buildStatDivider(height: 28),
                Expanded(
                  child: _buildStatItem(context, "${state.events.length}",
                      l10n.neg_exp.toUpperCase(),
                      unit: l10n.pts_unit, isNegative: state.events.isNotEmpty),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label,
      {String? unit, bool isNegative = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black54;
    final unitColor =
        isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black38;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isNegative ? const Color(0xFFFF3B30) : textColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: unitColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider({double height = 16}) {
    return Container(
      width: 0.5,
      height: height,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  // 辅助方法：构建横屏下的分割线
  Widget _buildLandscapeStatDivider(ColorScheme colorScheme,
      {double height = 24}) {
    return Container(
      width: 1,
      height: height,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  // Apple 风格：五联排手动触发按钮
  Widget _buildManualActionRow(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ManualActionButton(
                  label: l10n.rapid_decel,
                  icon: Icons.trending_down,
                  color: const Color(0xFFFF3B30),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidDeceleration),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.rapid_accel,
                  icon: Icons.trending_up,
                  color: const Color(0xFF4CD964),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidAcceleration),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.jerk,
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF5856D6),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.jerk),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.bump,
                  icon: Icons.vibration,
                  color: const Color(0xFF007AFF),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.bump),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.wobble,
                  icon: Icons.swap_calls_rounded,
                  color: const Color(0xFFFF9500),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.wobble),
                  isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventHistoryPopup(
      BuildContext context, RecordingState state, AppLocalizations l10n) {
    final recentEvents = state.events.reversed.toList(); // 获取所有并支持滚动
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _resetPopupTimer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 滚动列表
                Flexible(
                  child: recentEvents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              l10n.no_records,
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: recentEvents
                                .map((e) => _buildEventItem(e, l10n))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(RecordedEvent event, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr =
        "${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}";

    // 通过反射/映射获取 event type 翻译，直接使用 event.type (保持驼峰)
    final i18n = ref.read(i18nProvider);
    final translatedType = i18n.t(event.type);

    // 判断是否为 Pro 事件
    final bool isProEvent =
        event.source == 'PRO' || event.type.startsWith('pro');
    final String? displayNote = event.voiceText ?? event.notes;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(_getEventIcon(event.type),
                color: isDark ? Colors.white : Colors.black87, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(translatedType,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (isProEvent && displayNote != null && displayNote.isNotEmpty)
                  Text(displayNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500))
                else
                  Text(timeStr,
                      style: TextStyle(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                          fontSize: 11)),
              ],
            ),
          ),
          // 数据切换：Pro 事件显示时间，普通事件显示 G 值
          Text(
              isProEvent
                  ? timeStr
                  : l10n.g_unit((event.gForce ?? 0.0).toStringAsFixed(2)),
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'rapidDeceleration':
        return Icons.trending_down;
      case 'rapidAcceleration':
        return Icons.trending_up;
      case 'jerk':
        return Icons.bolt_rounded;
      case 'bump':
        return Icons.vibration;
      case 'wobble':
        return Icons.swap_calls_rounded;
      case 'proDisengagement':
        return Icons.pan_tool;
      case 'proViolation':
        return Icons.gavel;
      case 'proExperience':
        return Icons.sentiment_dissatisfied;
      case 'manual':
        return Icons.stars;
      default:
        return Icons.error_outline;
    }
  }

  void _resetPopupTimer() {
    _popupTimer?.cancel();
    _popupTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showEventPopup = false);
    });
  }

  Widget _buildTutorialStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 语音功能指引遮罩
  Widget _buildVoiceTutorialOverlay(
      BuildContext context, AppLocalizations l10n) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () async {
          setState(() => _showVoiceTutorial = false);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('voice_tutorial_shown', true);
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_none_rounded, color: Colors.white, size: 64),
              const SizedBox(height: 24),
              Text(
                l10n.voice_tutorial_title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              _buildTutorialStep(l10n.voice_tutorial_step1),
              _buildTutorialStep(l10n.voice_tutorial_step2),
              _buildTutorialStep(l10n.voice_tutorial_step3),
              _buildTutorialStep(l10n.voice_tutorial_step4),
              const SizedBox(height: 60),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  l10n.got_it,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusedSensorContent(BuildContext context, AppLocalizations l10n,
      {bool noMargin = false, bool isLandscape = false}) {
    return GestureDetector(
      key: ValueKey('focused_sensor_${isLandscape ? 'land' : 'port'}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isSensorFocused = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            margin: noMargin
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(isLandscape ? 12 : 16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 0.5),
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
                              size: isLandscape ? 56 : 64,
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
                          flex: 6,
                          child: _SensorWaveformSection(
                            data: data,
                            l10n: l10n,
                            showAxes: true,
                            isLandscape: isLandscape,
                          ),
                        ),
                      ],
                    );
                  },
                  orElse: () =>
                      const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
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
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()], // 强制等宽数字
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context, WidgetRef ref,
      RecordingState recordingState, AppLocalizations l10n) {
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
          child: _buildGpsStatusTag(recordingState, l10n),
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
                        ? _buildFocusedSensorContent(context, l10n,
                            noMargin: true, isLandscape: true)
                        : Align(
                            key: const ValueKey('landscape_hud_align'),
                            alignment: Alignment.bottomLeft,
                            child: _buildLandscapeHUD(context, l10n),
                          ),
                  ),
                ),
                const SizedBox(width: spacing),
                // 右侧面板
                _buildLandscapeControlConsole(context, ref, recordingState,
                    isRecording, isCalibrating, l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHUD(BuildContext context, AppLocalizations l10n) {
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
                        data: data, l10n: l10n, isLandscape: true),
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
      AppLocalizations l10n) {
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
                    fontWeight: FontWeight.bold,
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
                        label: l10n.speed,
                        value: l10n.speed_unit(
                            (state.currentSpeed * 3.6).toStringAsFixed(0)),
                        icon: Icons.speed,
                        compact: true),
                  ),
                  _buildStatDivider(height: 16),
                  Expanded(
                    child: _RecordingStat(
                        label: l10n.distance,
                        value: l10n.distance_unit(
                            (state.currentDistance / 1000).toStringAsFixed(2)),
                        icon: Icons.straighten,
                        compact: true),
                  ),
                  _buildStatDivider(height: 16),
                  Expanded(
                    child: _RecordingStat(
                        label: isRecording ? l10n.realtime_g : l10n.peak_g,
                        value: l10n.g_unit((isRecording
                                ? state.currentGForce
                                : state.maxGForce)
                            .toStringAsFixed(2)),
                        icon: Icons.shutter_speed,
                        compact: true),
                  ),
                  _buildStatDivider(height: 16),
                  Expanded(
                    child: _RecordingStat(
                        label: l10n.neg_exp,
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
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.0,
              children: [
                _TagButton(
                  label: l10n.jerk,
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF5856D6),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.jerk),
                  compact: true,
                ),
                _TagButton(
                  label: l10n.bump,
                  icon: Icons.vibration,
                  color: const Color(0xFF007AFF),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.bump),
                  compact: true,
                ),
                _TagButton(
                  label: l10n.rapid_decel,
                  icon: Icons.trending_down,
                  color: const Color(0xFFFF3B30),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidDeceleration),
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
              context, ref, state, isRecording, isCalibrating, l10n,
              isLandscape: true),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(
      BuildContext context,
      WidgetRef ref,
      RecordingState state,
      bool isRecording,
      bool isCalibrating,
      AppLocalizations l10n,
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
          elevation: isLandscape ? 0 : 8,
          shadowColor: isRecording
              ? const Color(0xFFFF3B30).withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
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
                  await ref.read(recordingProvider.notifier).startRecording();
                }
              },
        child: Text(
          isRecording ? l10n.stop_trip : l10n.start_trip,
          style: TextStyle(
              fontSize: isLandscape ? 16 : 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider({double height = 24}) {
    return Container(
      width: 1,
      height: height,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildMapSection(RecordingState state,
      {bool isLandscape = false,
      bool noMargin = false,
      bool isBackground = false,
      Offset centerOffset = Offset.zero}) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Container(
            margin: (isLandscape || noMargin)
                ? EdgeInsets.zero
                : const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isBackground
                  ? Colors.black
                  : Theme.of(context).cardTheme.color,
              borderRadius: (isLandscape || isBackground)
                  ? BorderRadius.zero
                  : BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: (isLandscape || isBackground)
                  ? BorderRadius.zero
                  : BorderRadius.circular(24),
              child: TripMapView(
                trajectory: state.trajectory,
                events: state.events,
                currentPosition: state.currentPosition,
                centerOffset: centerOffset, // 透传偏移量
                onLongPress: () {
                  if (state.isRecording && state.isVoiceRecordingEnabled) {
                    ref.read(recordingProvider.notifier).startVoiceRecording();
                  }
                },
              ),
            ),
          ),
          // 调试面板 (仅在非背景模式下显示，背景模式由 PortraitLayout 统一管理)
          if (!isBackground)
            Positioned(
              top: (isLandscape || noMargin) ? 12 : 16,
              left: (isLandscape || noMargin) ? 12 : 16, // 同步调整
              child: Consumer(builder: (context, ref, child) {
                final l10n = AppLocalizations.of(context)!;
                return _buildGpsStatusTag(state, l10n);
              }),
            ),
          // 算法切换按钮 (仅在非背景模式下显示)
          if (!isBackground && !state.isCalibrating)
            Positioned(
              top: (isLandscape || noMargin) ? 12 : 16,
              right: (isLandscape || noMargin) ? 12 : 16,
              child: _buildAlgorithmToggle(context, state),
            ),
        ],
      );
    });
  }

  Widget _buildGpsStatusTag(RecordingState state, AppLocalizations l10n) {
    final position = state.currentPosition;
    final accuracy = position?.accuracy ?? 999.0;

    Color statusColor;
    String statusText;

    if (position == null) {
      statusColor = Colors.grey;
      statusText = l10n.gps_no_signal;
    } else if (accuracy < 15) {
      statusColor = const Color(0xFF4CD964); // iOS Green
      statusText = l10n.gps_strong;
    } else if (accuracy < 50) {
      statusColor = const Color(0xFFFFCC00); // iOS Yellow
      statusText = l10n.gps_fair;
    } else {
      statusColor = const Color(0xFFFF3B30); // iOS Red
      statusText = l10n.gps_weak;
    }

    // 状态文本：优先显示传感器假死或惯导状态，其次是 GPS 状态
    String displayText;
    if (state.isSensorFrozen) {
      displayText = l10n.sensor_frozen;
      statusColor = Colors.orange;
    } else if (state.isInsActive) {
      displayText = l10n.ins_active;
      statusColor = Colors.blue;
    } else {
      displayText = "$statusText (${accuracy.toStringAsFixed(0)}m)";
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12), // 改为圆角方形
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                displayText.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorSection(BuildContext context, AppLocalizations l10n,
      {double height = 140, bool noMargin = false}) {
    return GestureDetector(
      key: const ValueKey('small_sensor_section'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _isSensorFocused = true;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: height,
            margin: noMargin ? EdgeInsets.zero : EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 0.5),
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
                        size: height * 0.65, // 动态调整球体大小
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _SensorWaveformSection(
                          data: data,
                          l10n: l10n,
                          showAxes: false,
                        ),
                      ),
                    ],
                  ),
                  orElse: () =>
                      const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationOverlay(BuildContext context, AppLocalizations l10n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(l10n.calibrating,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.calibration_tip,
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
  final AppLocalizations l10n;
  final bool isLandscape;
  final bool showAxes;
  const _SensorWaveformSection({
    required this.data,
    required this.l10n,
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
            label: widget.isLandscape ? '' : widget.l10n.longitudinal,
            limit: 1.5, // G力视图通常在 1.5G 范围内
            showAxes: widget.showAxes,
          ),
        ),
        SizedBox(height: widget.showAxes ? 16 : 8),
        Expanded(
          child: SensorWaveform(
            data: _accelXHistory.toList(),
            color: Theme.of(context).colorScheme.secondary,
            label: widget.isLandscape ? '' : widget.l10n.lateral,
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
                    fontWeight: FontWeight.bold, // 增加字重
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface)),
          ],
        ),
        Text(label.toUpperCase(), // 统一使用大写并加亮
            style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _TagButton extends StatefulWidget {
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
  State<_TagButton> createState() => _TagButtonState();
}

class _TagButtonState extends State<_TagButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
        HapticFeedback.mediumImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: widget.compact ? 44 : 54,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.color.withValues(alpha: 0.2), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  color: widget.color, size: widget.compact ? 18 : 22),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.compact ? 13 : 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isDark;

  const _ManualActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.isDark,
  });

  @override
  State<_ManualActionButton> createState() => _ManualActionButtonState();
}

class _ManualActionButtonState extends State<_ManualActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
        HapticFeedback.mediumImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    widget.color.withValues(alpha: widget.isDark ? 0.2 : 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
