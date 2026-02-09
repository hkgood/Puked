import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
import 'package:puked/services/sherpa_onnx_service.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/services/media_key_service.dart';
import 'package:flutter/foundation.dart';

class VoiceRecordingState {
  final bool isEnabled;
  final bool isRecording;
  final String? currentTranscription;
  final String? voiceStatus;
  final double downloadProgress;
  final bool isDownloading;
  final bool isError;

  VoiceRecordingState({
    this.isEnabled = false,
    this.isRecording = false,
    this.currentTranscription,
    this.voiceStatus,
    this.downloadProgress = 0.0,
    this.isDownloading = false,
    this.isError = false,
  });

  VoiceRecordingState copyWith({
    bool? isEnabled,
    bool? isRecording,
    String? currentTranscription,
    String? voiceStatus,
    double? downloadProgress,
    bool? isDownloading,
    bool? isError,
  }) {
    return VoiceRecordingState(
      isEnabled: isEnabled ?? this.isEnabled,
      isRecording: isRecording ?? this.isRecording,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      voiceStatus: voiceStatus ?? this.voiceStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isDownloading: isDownloading ?? this.isDownloading,
      isError: isError ?? this.isError,
    );
  }
}

class VoiceRecordingNotifier extends StateNotifier<VoiceRecordingState> {
  final Ref _ref;
  StreamSubscription<String>? _statusSub;

  SherpaOnnxService get _sherpa => _ref.read(sherpaOnnxServiceProvider);

  VoiceRecordingNotifier(this._ref) : super(VoiceRecordingState()) {
    _initVoiceService();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (e) {
      debugPrint('[VoiceRecordingNotifier] AudioSession init failed: $e');
    }
  }

  void _initVoiceService() {
    try {
      _initAudioSession();

      _statusSub = _sherpa.statusStream.listen((status) {
        if (status.startsWith("PROGRESS:")) {
          final progress = double.parse(status.split(":")[1]) / 100.0;
          state = state.copyWith(
            downloadProgress: progress,
            isDownloading: true,
            isError: false,
          );
        } else if (status == "START_DOWNLOAD") {
          state = state.copyWith(
            isDownloading: true,
            downloadProgress: 0,
            isError: false,
          );
        } else if (status == "DOWNLOAD_COMPLETE") {
          state = state.copyWith(
            isDownloading: true,
            downloadProgress: 1.0,
            isError: false,
          );
        } else if (status == "ENGINE_READY") {
          state = state.copyWith(
            isDownloading: false,
            downloadProgress: 1.0,
            voiceStatus: null,
            isError: false,
          );
        } else if (status == "DOWNLOAD_FAILED" || status == "INIT_FAILED") {
          state = state.copyWith(
            isDownloading: false,
            voiceStatus:
                _ref.read(i18nProvider).t('voice_engine_config_failed'),
            isError: true,
          );
          _clearStatusAfterDelay();
        }
        debugPrint('[VoiceRecordingNotifier] Sherpa status: $status');
      }, onError: (e) {
        debugPrint('[VoiceRecordingNotifier] Sherpa status stream error: $e');
      });
    } catch (e) {
      debugPrint('[VoiceRecordingNotifier] Voice service listener failed: $e');
    }
  }

  void _clearStatusAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && state.isError) {
        state = state.copyWith(voiceStatus: null);
      }
    });
  }

  void toggleEnabled() {
    final newState = !state.isEnabled;
    state = state.copyWith(isEnabled: newState);
    debugPrint('[VoiceRecordingNotifier] Voice recording enabled: $newState');

    if (newState && !_sherpa.isInitialized) {
      _sherpa.init();
    }

    updateMediaKeyActivation(_ref);
  }

  Future<void> startRecording() async {
    if (!state.isEnabled || state.isRecording) return;

    if (!_sherpa.isInitialized) {
      final msg = _ref.read(i18nProvider).t('voice_engine_not_ready');
      state = state.copyWith(voiceStatus: msg);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && state.voiceStatus == msg) {
          state = state.copyWith(voiceStatus: null);
        }
      });
      return;
    }

    state = state.copyWith(isRecording: true, currentTranscription: "");
    HapticFeedback.vibrate();

    await _sherpa.startListening(
      onResult: (text) {
        state = state.copyWith(currentTranscription: text);
      },
      onFinalResult: (category, text) {
        if (!state.isRecording) return;

        if (text.isNotEmpty) {
          _handleVoiceEvent(category, text);
        }
        state = state.copyWith(isRecording: false);
      },
    );
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    await _sherpa.stopListening();
    state = state.copyWith(isRecording: false);
  }

  void _handleVoiceEvent(String category, String text) async {
    EventType type;
    switch (category) {
      case 'proDisengagement':
        type = EventType.proDisengagement;
        break;
      case 'proViolation':
        type = EventType.proViolation;
        break;
      case 'proExperience':
        type = EventType.proExperience;
        break;
      default:
        type = EventType.manual;
    }

    // 触发主记录器的事件标记
    await _ref.read(recordingProvider.notifier).tagEvent(
          type,
          source: 'PRO',
          notes: text,
          voiceText: text,
        );

    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}

final voiceRecordingProvider =
    StateNotifierProvider<VoiceRecordingNotifier, VoiceRecordingState>((ref) {
  return VoiceRecordingNotifier(ref);
});
