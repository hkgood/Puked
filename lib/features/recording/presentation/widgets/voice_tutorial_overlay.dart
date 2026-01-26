import 'package:flutter/material.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceTutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const VoiceTutorialOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () async {
          onDismiss();
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

  Widget _buildTutorialStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF4CD964), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
