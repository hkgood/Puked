import 'package:flutter/material.dart';
import 'package:puked/features/recording/providers/voice_recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class VoiceRecordingOverlay extends StatelessWidget {
  final VoiceRecordingState state;

  const VoiceRecordingOverlay({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
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
}
