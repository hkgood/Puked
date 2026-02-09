import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/features/recording/presentation/vehicle_info_screen.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class MainActionButton extends ConsumerStatefulWidget {
  final bool isLandscape;

  const MainActionButton({
    super.key,
    this.isLandscape = false,
  });

  @override
  ConsumerState<MainActionButton> createState() => _MainActionButtonState();
}

class _MainActionButtonState extends ConsumerState<MainActionButton>
    with SingleTickerProviderStateMixin {
  // 动画控制器，用于长按进度动画
  late AnimationController _longPressController;
  // 是否正在长按
  bool _isLongPressing = false;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器，时长0.8秒
    _longPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // 监听动画完成事件
    _longPressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isLongPressing) {
        // 动画完成且仍在长按状态，触发停止录制
        _handleStopRecording();
      }
    });
  }

  @override
  void dispose() {
    _longPressController.dispose();
    super.dispose();
  }

  // 处理停止录制逻辑
  Future<void> _handleStopRecording() async {
    final state = ref.read(recordingProvider);
    final tripId = state.currentTrip?.id;

    await ref.read(recordingProvider.notifier).stopRecording();

    if (tripId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleInfoScreen(tripId: tripId),
        ),
      );
    }

    // 重置状态
    setState(() {
      _isLongPressing = false;
    });
    _longPressController.reset();
  }

  // 处理长按开始
  void _handleLongPressStart() {
    setState(() {
      _isLongPressing = true;
    });
    _longPressController.forward();
  }

  // 处理长按结束或取消
  void _handleLongPressEnd() {
    if (_isLongPressing) {
      setState(() {
        _isLongPressing = false;
      });
      _longPressController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingProvider);
    final l10n = AppLocalizations.of(context)!;
    final isRecording = state.isRecording;
    final isCalibrating = state.isCalibrating;

    // 如果正在录制，使用 GestureDetector 实现长按效果
    if (isRecording) {
      return SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onLongPressStart:
              isCalibrating ? null : (_) => _handleLongPressStart(),
          onLongPressEnd: (_) => _handleLongPressEnd(),
          onLongPressCancel: _handleLongPressEnd,
          child: Stack(
            children: [
              // 底层按钮（保持正常红色背景）
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    vertical: widget.isLandscape ? 14 : 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: widget.isLandscape
                      ? null
                      : [
                          BoxShadow(
                            color:
                                const Color(0xFFFF3B30).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.stop_trip,
                  style: TextStyle(
                    fontSize: widget.isLandscape ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // 长按进度条遮罩层（略深的红色从左到右填充）
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _longPressController,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _longPressController.value,
                          heightFactor: 1.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              // 略深的红色作为进度条
                              color: Color(0xFFCC2E24),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // 顶层文字（确保文字始终在最上层）
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      l10n.stop_trip,
                      style: TextStyle(
                        fontSize: widget.isLandscape ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 如果未录制，保持原有的点击逻辑
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: widget.isLandscape ? 14 : 18),
          elevation: widget.isLandscape ? 0 : 8,
          shadowColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isCalibrating
            ? null
            : () async {
                await ref.read(recordingProvider.notifier).startRecording();
              },
        child: Text(
          l10n.start_trip,
          style: TextStyle(
              fontSize: widget.isLandscape ? 16 : 18,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
