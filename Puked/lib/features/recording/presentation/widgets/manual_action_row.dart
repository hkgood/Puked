import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class ManualActionRow extends ConsumerWidget {
  const ManualActionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ManualActionButton(
                  label: l10n.rapid_decel,
                  icon: Icons.trending_down,
                  color: const Color(0xFFFF3B30),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidDeceleration),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.rapid_accel,
                  icon: Icons.trending_up,
                  color: const Color(0xFF4CD964),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.rapidAcceleration),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.jerk,
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFF5856D6),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.jerk),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.bump,
                  icon: Icons.vibration,
                  color: const Color(0xFF007AFF),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.bump),
                  isDark: isDark),
              _ManualActionButton(
                  label: l10n.wobble,
                  icon: Icons.swap_calls_rounded,
                  color: const Color(0xFFFF9500),
                  onPressed: () => ref
                      .read(recordingProvider.notifier)
                      .tagEvent(EventType.wobble),
                  isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isDark;

  const _ManualActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
