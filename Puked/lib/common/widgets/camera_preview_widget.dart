import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/services/video_recording_service.dart';

import 'package:puked/common/utils/i18n.dart';

/// 摄像头预览 Widget
///
/// 显示实时摄像头画面，替换地图背景
/// 支持点击触发语音录制功能
class CameraPreviewWidget extends ConsumerStatefulWidget {
  /// 点击回调（用于触发语音录制）
  final VoidCallback? onTap;

  /// 长按回调（用于触发语音录制）
  final VoidCallback? onLongPress;

  const CameraPreviewWidget({
    super.key,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<CameraPreviewWidget> createState() =>
      _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends ConsumerState<CameraPreviewWidget> {
  int? _textureId;
  bool _isLoading = true;
  String? _errorKey; // 改为存储 key 而不是直接的消息

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    final service = ref.read(videoRecordingServiceProvider);

    // ✅ 步骤 1: 检查摄像头权限（现在不依赖初始化，可以直接调用）
    final hasPermission = await service.checkCameraPermission();
    if (!hasPermission) {
      // 请求权限
      final granted = await service.requestCameraPermission();
      if (!granted) {
        // 用户拒绝权限
        if (mounted) {
          setState(() {
            _errorKey = 'camera_permission_needed';
            _isLoading = false;
          });
        }
        return;
      }
    }

    // ✅ 步骤 2: 初始化视频服务（此时已确认有权限）
    final initialized = await service.initialize();
    if (!initialized) {
      if (mounted) {
        setState(() {
          _errorKey = 'camera_init_failed';
          _isLoading = false;
        });
      }
      return;
    }

    // ✅ 步骤 3: 获取预览纹理ID
    final textureId = await service.getPreviewTextureId();

    // 🎥 Texture 预览功能需要原生开发完成
    // 在原生完成之前，显示一个占位界面而不是错误
    if (textureId == null) {
      debugPrint(
          '[CameraPreview] Texture not implemented yet, showing placeholder');
      if (mounted) {
        setState(() {
          _textureId = null; // 设为 null，显示占位界面
          _isLoading = false;
          _errorKey = null; // 不显示错误，这是预期行为
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _textureId = textureId;
        _isLoading = false;
        _errorKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);

    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                i18n.t('camera_starting'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorKey != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                i18n.t(_errorKey!),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorKey = null;
                  });
                  _initializePreview();
                },
                child: Text(i18n.t('retry'),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_textureId == null) {
      // 🎥 原生 Texture 预览尚未实现，显示占位界面
      return GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  i18n.t('camera_preview_placeholder'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  i18n.t('camera_preview_hint'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 显示摄像头预览
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16, // iOS 摄像头竖屏模式 (9:16)
            child: Texture(
              textureId: _textureId!,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 资源清理由 VideoRecordingService 统一管理
    super.dispose();
  }
}
