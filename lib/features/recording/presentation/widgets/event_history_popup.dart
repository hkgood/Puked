import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/config/constants.dart';
import 'package:puked/common/config/enums.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/models/db_models.dart';

class EventHistoryPopup extends ConsumerWidget {
  final VoidCallback onDismiss;
  final VoidCallback onResetTimer;

  const EventHistoryPopup({
    super.key,
    required this.onDismiss,
    required this.onResetTimer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingProvider);
    final recentEvents = state.events.reversed.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onResetTimer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppConstants.heavyBlurSigma,
              sigmaY: AppConstants.heavyBlurSigma),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius:
                  BorderRadius.circular(AppConstants.smallBorderRadius),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: recentEvents.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              l10n.no_records,
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: recentEvents
                                .map((e) => _EventItem(event: e))
                                .toList(),
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

class _EventItem extends ConsumerWidget {
  final RecordedEvent event;

  const _EventItem({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final timeStr =
        "${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}";

    final i18n = ref.read(i18nProvider);
    final translatedType = i18n.t(event.type);

    final bool isProEvent =
        event.source == 'PRO' || event.type.startsWith('pro');
    final String? displayNote = event.voiceText ?? event.notes;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(_getEventIcon(event.type),
                color: isDark ? Colors.white : Colors.black87, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(translatedType,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (isProEvent && displayNote != null && displayNote.isNotEmpty)
                  Text(displayNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500))
                else
                  Text(timeStr,
                      style: TextStyle(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.5),
                          fontSize: 11)),
              ],
            ),
          ),
          Text(
              isProEvent
                  ? timeStr
                  : l10n.g_unit((event.gForce ?? 0.0).toStringAsFixed(2)),
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'rapidDeceleration':
        return Icons.trending_down;
      case 'rapidAcceleration':
        return Icons.trending_up;
      case 'jerk':
        return Icons.bolt_rounded;
      case 'bump':
        return Icons.vibration;
      case 'wobble':
        return Icons.swap_calls_rounded;
      case 'proDisengagement':
        return Icons.pan_tool;
      case 'proViolation':
        return Icons.gavel;
      case 'proExperience':
        return Icons.sentiment_dissatisfied;
      case 'manual':
        return Icons.stars;
      default:
        return Icons.error_outline;
    }
  }
}
