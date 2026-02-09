import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/features/recording/providers/voice_recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class AlgorithmToggle extends ConsumerWidget {
  final VoidCallback onShowTutorial;

  const AlgorithmToggle({
    super.key,
    required this.onShowTutorial,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceRecordingProvider);
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);

    // 语音打标功能：仅对通过认证的 Pro 用户开放
    if (!auth.isPro) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        final voiceNotifier = ref.read(voiceRecordingProvider.notifier);
        final wasEnabled = voiceState.isEnabled;

        voiceNotifier.toggleEnabled();
        HapticFeedback.lightImpact();

        // 如果是从关到开，且从未显示过指引，则弹出遮罩
        if (!wasEnabled) {
          final prefs = await SharedPreferences.getInstance();
          final shown = prefs.getBool('voice_tutorial_shown') ?? false;
          if (!shown) {
            onShowTutorial();
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
                if (voiceState.isDownloading)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: voiceState.downloadProgress.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                // 2. 状态背景色 (下载完成且开启时显示)
                if (!voiceState.isDownloading && voiceState.isEnabled)
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
                          voiceState.isDownloading
                              ? Icons.downloading
                              : (voiceState.isError
                                  ? Icons.error_outline
                                  : (voiceState.isEnabled
                                      ? Icons.mic
                                      : Icons.mic_off)),
                          color: voiceState.isError
                              ? Colors.redAccent
                              : Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          voiceState.isDownloading
                              ? "${(voiceState.downloadProgress * 100).toInt()}%"
                              : (voiceState.isError
                                  ? l10n.fail
                                  : (voiceState.isEnabled
                                      ? l10n.pro_on
                                      : l10n.pro_off)),
                          style: TextStyle(
                              color: voiceState.isError
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
  }
}
