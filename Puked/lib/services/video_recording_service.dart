import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 视频录制服务 Provider
final videoRecordingServiceProvider = Provider<VideoRecordingService>((ref) {
  return VideoRecordingService();
});

/// 视频录制服务
///
/// 通过 Platform Channel 与原生代码通信，实现：
/// - 10秒循环缓冲录制（无音频）
/// - 事件触发时保存前5秒视频
/// - 摄像头预览显示
class VideoRecordingService {
  static const MethodChannel _channel =
      MethodChannel('com.puked/video_recording');
  // 预览通道（未来用于更新预览）
  // ignore: unused_field
  static const EventChannel _previewChannel =
      EventChannel('com.puked/camera_preview');

  /// 是否正在录制
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// 初始化视频录制服务
  ///
  /// 返回: 是否初始化成功
  Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to initialize: ${e.message}');
      return false;
    }
  }

  /// 检查摄像头权限
  ///
  /// 返回: 是否已授权
  Future<bool> checkCameraPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkCameraPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to check permission: ${e.message}');
      return false;
    }
  }

  /// 请求摄像头权限
  ///
  /// 返回: 是否授权成功
  Future<bool> requestCameraPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestCameraPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to request permission: ${e.message}');
      return false;
    }
  }

  /// 开始循环录制
  ///
  /// [resolution]: 分辨率 (默认 "1080p")
  /// [fps]: 帧率 (默认 60)
  /// [bufferDuration]: 循环缓冲时长（秒，默认 10）
  ///
  /// 返回: 是否启动成功
  Future<bool> startRecording({
    String resolution = '1080p',
    int fps = 60,
    int bufferDuration = 10,
  }) async {
    if (_isRecording) {
      debugPrint('[VideoRecording] Already recording');
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>('startRecording', {
        'resolution': resolution,
        'fps': fps,
        'bufferDuration': bufferDuration,
        'enableAudio': false, // 不录制音频（避免与语音识别冲突）
      });

      _isRecording = result ?? false;
      return _isRecording;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to start recording: ${e.message}');
      return false;
    }
  }

  /// 停止循环录制
  ///
  /// 返回: 是否停止成功
  Future<bool> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[VideoRecording] Not recording');
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>('stopRecording');
      _isRecording = false;
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to stop recording: ${e.message}');
      return false;
    }
  }

  /// 捕获事件视频（保存前5秒）
  ///
  /// [eventId]: 事件ID
  /// [duration]: 保存时长（秒，默认 5）
  ///
  /// 返回: 保存的视频文件路径，失败返回 null
  Future<String?> captureEventVideo({
    required String eventId,
    int duration = 5,
  }) async {
    if (!_isRecording) {
      debugPrint('[VideoRecording] Cannot capture: not recording');
      return null;
    }

    try {
      final result = await _channel.invokeMethod<String>('captureEvent', {
        'eventId': eventId,
        'duration': duration,
      });

      if (result != null && result.isNotEmpty) {
        debugPrint('[VideoRecording] Saved event video: $result');
      }

      return result;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to capture event: ${e.message}');
      return null;
    }
  }

  /// 获取预览纹理ID（用于显示摄像头预览）
  ///
  /// 返回: 纹理ID，失败返回 null
  Future<int?> getPreviewTextureId() async {
    try {
      final result = await _channel.invokeMethod<int>('getPreviewTextureId');
      return result;
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to get texture ID: ${e.message}');
      return null;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }

    try {
      await _channel.invokeMethod('dispose');
    } on PlatformException catch (e) {
      debugPrint('[VideoRecording] Failed to dispose: ${e.message}');
    }
  }
}
