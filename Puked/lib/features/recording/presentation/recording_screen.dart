import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/config/constants.dart';
import 'package:puked/common/widgets/trip_map_view.dart';
import 'package:puked/common/widgets/camera_preview_widget.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/recording/providers/voice_recording_provider.dart';
import 'package:puked/features/settings/providers/settings_provider.dart';
import 'package:puked/features/recording/presentation/widgets/gps_status_tag.dart';
import 'package:puked/features/recording/presentation/widgets/algorithm_toggle.dart';
import 'package:puked/features/recording/presentation/widgets/stats_capsule.dart';
import 'package:puked/features/recording/presentation/widgets/manual_action_row.dart';
import 'package:puked/features/recording/presentation/widgets/main_action_button.dart';
import 'package:puked/features/recording/presentation/widgets/voice_recording_overlay.dart';
import 'package:puked/features/recording/presentation/widgets/calibration_overlay.dart';
import 'package:puked/features/recording/presentation/widgets/voice_tutorial_overlay.dart';
import 'package:puked/features/recording/presentation/widgets/tag_button.dart';
import 'package:puked/features/recording/presentation/widgets/recording_stat.dart';
import 'package:puked/features/recording/presentation/widgets/event_history_popup.dart';
import 'package:puked/features/recording/presentation/widgets/focused_sensor_content.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/features/settings/presentation/settings_screen.dart';
import 'package:puked/features/history/presentation/history_screen.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/common/widgets/g_force_ball.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/models/db_models.dart';
import 'package:puked/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Theme.of(context).platform == TargetPlatform.android) {
        UpdateService.checkUpdate(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingProvider);
    final voiceState = ref.watch(voiceRecordingProvider);
    final isCalibrating = recordingState.isCalibrating;

    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    double topOverlay = topPadding + 8 + 40;
    if (recordingState.isRecording) topOverlay += 8 + 40;

    double bottomOverlay =
        bottomPadding + 12 + 56 + 12 + (_isSensorFocused ? 420 : 130);
    if (recordingState.isRecording) bottomOverlay += 12 + 85;

    final Offset centerOffset = Offset(0, (topOverlay - bottomOverlay) / 2);

    ref.listen<String?>(
      recordingProvider.select((s) => s.alertMessage),
      (previous, next) {
        if (next != null && next.isNotEmpty) {
          final l10n = AppLocalizations.of(context)!;
          final i18n = I18n(l10n);

          debugPrint('[Recording] Received alert message: $next');

          // 清理错误key：移除可能存在的 "Exception: " 前缀（防御性编程）
          String cleanKey = next.trim();
          if (cleanKey.toLowerCase().startsWith('exception:')) {
            cleanKey = cleanKey.substring(cleanKey.indexOf(':') + 1).trim();
            debugPrint('[Recording] Cleaned to: $cleanKey');
          }

          // 根据错误key翻译成对应语言的错误消息
          String errorMessage;
          try {
            errorMessage = i18n.t(cleanKey);
            debugPrint('[Recording] Translated message: $errorMessage');

            // 如果翻译返回的还是原始key，说明没有找到翻译
            if (errorMessage == cleanKey) {
              debugPrint(
                  '[Recording] Translation returned same key, using fallback');
              // 使用通用错误描述
              errorMessage = l10n.calibration_failed_desc;
            }
          } catch (e) {
            // 如果翻译失败，使用通用错误描述
            debugPrint(
                '[Recording] Translation error for key: $cleanKey, error: $e');
            errorMessage = l10n.calibration_failed_desc;
          }

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
              content: Text(errorMessage),
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
                OrientationBuilder(
                  builder: (context, orientation) {
                    if (orientation == Orientation.portrait) {
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: _buildMapSection(recordingState,
                                isLandscape: false,
                                noMargin: true,
                                isBackground: true,
                                centerOffset: centerOffset),
                          ),
                          _buildTopShadow(),
                          _buildPortraitLayout(context, ref, recordingState),
                        ],
                      );
                    } else {
                      return _buildLandscapeLayout(
                          context, ref, recordingState);
                    }
                  },
                ),
                if (isCalibrating) const CalibrationOverlay(),
                if (voiceState.isRecording)
                  VoiceRecordingOverlay(state: voiceState),
              ],
            ),
          ),
        ),
        if (_showVoiceTutorial)
          VoiceTutorialOverlay(
            onDismiss: () => setState(() => _showVoiceTutorial = false),
          ),
      ],
    );
  }

  Widget _buildTopShadow() {
    return Positioned(
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
    );
  }

  Widget _buildPortraitLayout(
      BuildContext context, WidgetRef ref, RecordingState recordingState) {
    final isRecording = recordingState.isRecording;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          GpsStatusTag(state: recordingState),
                          AlgorithmToggle(
                            onShowTutorial: () =>
                                setState(() => _showVoiceTutorial = true),
                          ),
                        ],
                      ),
                      _buildLogo(context),
                    ],
                  ),
                  if (isRecording) ...[
                    const SizedBox(height: 8),
                    StatsCapsule(
                      onTap: () {
                        setState(() {
                          _showEventPopup = !_showEventPopup;
                          if (_showEventPopup) _isSensorFocused = false;
                        });
                        _resetPopupTimer();
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (!_showEventPopup) const Spacer(),
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
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: EventHistoryPopup(
                          onDismiss: () =>
                              setState(() => _showEventPopup = false),
                          onResetTimer: _resetPopupTimer,
                        ),
                      ),
                    )
                  : Container(
                      key: ValueKey('sensor_container_${_isSensorFocused}'),
                      height: _isSensorFocused ? 420 : 130,
                      child: _isSensorFocused
                          ? FocusedSensorContent(
                              noMargin: true,
                              onTap: () =>
                                  setState(() => _isSensorFocused = false),
                            )
                          : _buildSensorSection(context,
                              height: 130, noMargin: true),
                    ),
            ),
            if (_showEventPopup) const Spacer(),
            const SizedBox(height: 12),
            if (isRecording) ...[
              const ManualActionRow(),
              const SizedBox(height: 12),
            ],
            const MainActionButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'PUKED',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 8.0,
          color: isDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  void _resetPopupTimer() {
    _popupTimer?.cancel();
    _popupTimer = Timer(AppConstants.uiPopupDuration, () {
      if (mounted) setState(() => _showEventPopup = false);
    });
  }

  Widget _buildMapSection(RecordingState state,
      {bool isLandscape = false,
      bool noMargin = false,
      bool isBackground = false,
      Offset centerOffset = Offset.zero}) {
    return LayoutBuilder(builder: (context, constraints) {
      // 检查是否启用视频录制
      final settings = ref.watch(settingsProvider);
      final isVideoEnabled = settings.isVideoRecordingEnabled;

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
                  : BorderRadius.circular(AppConstants.defaultBorderRadius),
            ),
            child: ClipRRect(
              borderRadius: (isLandscape || isBackground)
                  ? BorderRadius.zero
                  : BorderRadius.circular(AppConstants.defaultBorderRadius),
              child: Consumer(builder: (context, ref, child) {
                final voiceState = ref.watch(voiceRecordingProvider);

                // 如果启用视频录制，显示摄像头预览；否则显示地图
                if (isVideoEnabled) {
                  return CameraPreviewWidget(
                    onLongPress: () {
                      if (state.isRecording && voiceState.isEnabled) {
                        ref
                            .read(voiceRecordingProvider.notifier)
                            .startRecording();
                      }
                    },
                  );
                } else {
                  return TripMapView(
                    trajectory: state.trajectory,
                    events: state.events,
                    currentPosition: state.currentPosition,
                    centerOffset: centerOffset,
                    onLongPress: () {
                      if (state.isRecording && voiceState.isEnabled) {
                        ref
                            .read(voiceRecordingProvider.notifier)
                            .startRecording();
                      }
                    },
                  );
                }
              }),
            ),
          ),
          if (!isBackground)
            Positioned(
              top: (isLandscape || noMargin) ? 12 : 16,
              left: (isLandscape || noMargin) ? 12 : 16,
              child: GpsStatusTag(state: state),
            ),
          if (!isBackground && !state.isCalibrating)
            Positioned(
              top: (isLandscape || noMargin) ? 12 : 16,
              right: (isLandscape || noMargin) ? 12 : 16,
              child: AlgorithmToggle(
                onShowTutorial: () => setState(() => _showVoiceTutorial = true),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildSensorSection(BuildContext context,
      {double height = 140, bool noMargin = false}) {
    return GestureDetector(
      key: const ValueKey('small_sensor_section'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isSensorFocused = true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppConstants.glassBlurSigma,
              sigmaY: AppConstants.glassBlurSigma),
          child: Container(
            height: height,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white)
                  .withValues(alpha: 0.5),
              borderRadius:
                  BorderRadius.circular(AppConstants.defaultBorderRadius),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 0.5),
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final sensorDataAsync = ref.watch(sensorStreamProvider);
                final l10n = AppLocalizations.of(context)!;
                return sensorDataAsync.maybeWhen(
                  data: (data) => Row(
                    children: [
                      GForceBall(
                        acceleration: data.processedAccel,
                        gyroscope: data.gyroscope,
                        size: height * 0.65,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: SensorWaveformSection(
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

  Widget _buildLandscapeLayout(
      BuildContext context, WidgetRef ref, RecordingState recordingState) {
    const double spacing = 16.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const double mapShift = 168.0;

    return Stack(
      children: [
        Positioned(
          left: -mapShift * 2,
          top: 0,
          bottom: 0,
          width: screenWidth + mapShift * 2,
          child: _buildMapSection(recordingState, isLandscape: true),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: GpsStatusTag(state: recordingState),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                spacing / 2, spacing, spacing, spacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                        ? FocusedSensorContent(
                            noMargin: true,
                            isLandscape: true,
                            onTap: () =>
                                setState(() => _isSensorFocused = false),
                          )
                        : Align(
                            key: const ValueKey('landscape_hud_align'),
                            alignment: Alignment.bottomLeft,
                            child: _buildLandscapeHUD(context),
                          ),
                  ),
                ),
                const SizedBox(width: spacing),
                _buildLandscapeControlConsole(context, ref, recordingState),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeHUD(BuildContext context) {
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
            final l10n = AppLocalizations.of(context)!;
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
                    child: SensorWaveformSection(
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
      BuildContext context, WidgetRef ref, RecordingState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final isRecording = state.isRecording;
    final l10n = AppLocalizations.of(context)!;

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
        mainAxisSize: MainAxisSize.max,
        children: [
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
                    fontSize: 12,
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
          const Divider(height: 16),
          if (isRecording) ...[
            _buildLandscapeStats(state, l10n, colorScheme),
            const SizedBox(height: 12),
            _buildLandscapeActions(l10n),
          ] else
            Expanded(
              child: Center(
                child: Icon(Icons.rocket_launch_outlined,
                    size: 40, color: onSurface.withValues(alpha: 0.2)),
              ),
            ),
          const Spacer(),
          const MainActionButton(isLandscape: true),
        ],
      ),
    );
  }

  Widget _buildLandscapeStats(
      RecordingState state, AppLocalizations l10n, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
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
            child: RecordingStat(
                label: l10n.speed,
                value: l10n.speed_unit(
                    (state.currentSpeed * AppConstants.msToKmh)
                        .toStringAsFixed(0)),
                icon: Icons.speed,
                compact: true),
          ),
          _buildStatDivider(context),
          Expanded(
            child: RecordingStat(
                label: l10n.distance,
                value: l10n.distance_unit(
                    (state.currentDistance / 1000).toStringAsFixed(2)),
                icon: Icons.straighten,
                compact: true),
          ),
          _buildStatDivider(context),
          Expanded(
            child: RecordingStat(
                label: state.isRecording ? l10n.realtime_g : l10n.peak_g,
                value: l10n.g_unit(
                    (state.isRecording ? state.currentGForce : state.maxGForce)
                        .toStringAsFixed(2)),
                icon: Icons.shutter_speed,
                compact: true),
          ),
          _buildStatDivider(context),
          Expanded(
            child: RecordingStat(
                label: l10n.neg_exp,
                value: "${state.events.length}",
                icon: Icons.error_outline,
                compact: true),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeActions(AppLocalizations l10n) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: [
        TagButton(
          label: l10n.jerk,
          icon: Icons.bolt_rounded,
          color: const Color(0xFF5856D6),
          onPressed: () =>
              ref.read(recordingProvider.notifier).tagEvent(EventType.jerk),
          compact: true,
        ),
        TagButton(
          label: l10n.bump,
          icon: Icons.vibration,
          color: const Color(0xFF007AFF),
          onPressed: () =>
              ref.read(recordingProvider.notifier).tagEvent(EventType.bump),
          compact: true,
        ),
        TagButton(
          label: l10n.rapid_decel,
          icon: Icons.trending_down,
          color: const Color(0xFFFF3B30),
          onPressed: () => ref
              .read(recordingProvider.notifier)
              .tagEvent(EventType.rapidDeceleration),
          compact: true,
        ),
      ],
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 0.5,
      height: 16,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1),
    );
  }
}
