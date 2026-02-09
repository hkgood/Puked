import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/recording/providers/voice_recording_provider.dart';

class MediaKeyHandler extends BaseAudioHandler {
  final ProviderContainer container;

  MediaKeyHandler(this.container) {
    // 默认不激活媒体会话，避免干扰用户正常听歌
    deactivate();
  }

  /// 激活媒体会话：此时耳机的播放/暂停键会被 Puked 捕获
  void activate() {
    debugPrint('[MediaKeyHandler] 🚀 激活媒体会话');
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.play,
        MediaControl.pause,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: true, // 标记为播放中，Android 才会分发 MediaKey
    ));

    mediaItem.add(const MediaItem(
      id: 'puked_voice_control',
      album: 'PUKED',
      title: '语音助手就绪',
      artist: 'OSG Lab',
    ));
  }

  /// 停用媒体会话：释放按键控制权给系统（如网易云、Spotify）
  void deactivate() {
    debugPrint('[MediaKeyHandler] 💤 停用媒体会话');
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      controls: [],
    ));
  }

  @override
  Future<void> play() async {
    debugPrint('[MediaKeyHandler] >>> 收到播放按键 (Play) <<<');
    _triggerVoiceRecording();
  }

  @override
  Future<void> pause() async {
    debugPrint('[MediaKeyHandler] >>> 收到暂停按键 (Pause) <<<');
    _triggerVoiceRecording();
  }

  @override
  Future<void> stop() async {
    debugPrint('[MediaKeyHandler] >>> 收到停止按键 (Stop) <<<');
  }

  @override
  Future<void> click([MediaButton button = MediaButton.next]) async {
    debugPrint('[MediaKeyHandler] >>> 收到点击按键 (Click: $button) <<<');
    _triggerVoiceRecording();
  }

  void _triggerVoiceRecording() {
    final recordingState = container.read(recordingProvider);
    final voiceState = container.read(voiceRecordingProvider);
    final voiceNotifier = container.read(voiceRecordingProvider.notifier);

    debugPrint(
        '[MediaKeyHandler] 状态检查: isRecording=${recordingState.isRecording}, isVoiceEnabled=${voiceState.isEnabled}');

    if (recordingState.isRecording) {
      // 🎥 如果启用了视频录制，蓝牙按键也会触发视频截取
      // 注意：这里不管语音开关状态，只要在录制就可以用按键触发事件
      if (voiceState.isEnabled) {
        // 语音模式：录音
        if (voiceState.isRecording) {
          debugPrint('[MediaKeyHandler] 正在录音中，触发停止');
          voiceNotifier.stopRecording();
        } else {
          debugPrint('[MediaKeyHandler] 未在录音，触发开始');
          voiceNotifier.startRecording();
        }
      } else {
        // 非语音模式：直接触发手动标记事件（会自动截取视频）
        debugPrint('[MediaKeyHandler] 非语音模式，触发手动标记事件');
        container.read(recordingProvider.notifier).tagEvent(
              EventType.manual,
              source: 'BLUETOOTH',
            );
      }
    } else {
      debugPrint('[MediaKeyHandler] 触发跳过: 行程未开始');
    }
  }
}

/// 辅助函数：根据当前行程状态和视频/语音开关，更新媒体按键监听器的激活状态
void updateMediaKeyActivation(Ref ref) {
  final recordingState = ref.read(recordingProvider);
  final handler = ref.read(mediaKeyHandlerProvider);

  if (handler == null) return;

  // 🎥 只要在录制行程，就激活蓝牙按键（用于触发语音或视频事件）
  if (recordingState.isRecording) {
    handler.activate();
  } else {
    handler.deactivate();
  }
}

final mediaKeyHandlerProvider = StateProvider<MediaKeyHandler?>((ref) {
  return null;
});

Future<MediaKeyHandler> initMediaKeyHandler(ProviderContainer container) async {
  return await AudioService.init(
    builder: () => MediaKeyHandler(container),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.osglab.puked.media',
      androidNotificationChannelName: 'Puked Media Control',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
