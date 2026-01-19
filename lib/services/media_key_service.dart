import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';

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
    final notifier = container.read(recordingProvider.notifier);
    final state = container.read(recordingProvider);

    debugPrint(
        '[MediaKeyHandler] 状态检查: isRecording=${state.isRecording}, isVoiceEnabled=${state.isVoiceRecordingEnabled}');

    if (state.isRecording && state.isVoiceRecordingEnabled) {
      if (state.isVoiceRecording) {
        debugPrint('[MediaKeyHandler] 正在录音中，触发停止');
        notifier.stopVoiceRecording();
      } else {
        debugPrint('[MediaKeyHandler] 未在录音，触发开始');
        notifier.startVoiceRecording();
      }
    } else {
      debugPrint('[MediaKeyHandler] 触发跳过: 行程未开始或语音开关未打开');
    }
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
