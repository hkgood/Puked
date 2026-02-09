import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class GpsStatusTag extends StatelessWidget {
  final RecordingState state;

  const GpsStatusTag({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final position = state.currentPosition;
    final accuracy = position?.accuracy ?? 999.0;

    Color statusColor;
    String statusText;

    if (position == null) {
      statusColor = Colors.grey;
      statusText = l10n.gps_no_signal;
    } else if (accuracy < 15) {
      statusColor = const Color(0xFF4CD964); // iOS Green
      statusText = l10n.gps_strong;
    } else if (accuracy < 50) {
      statusColor = const Color(0xFFFFCC00); // iOS Yellow
      statusText = l10n.gps_fair;
    } else {
      statusColor = const Color(0xFFFF3B30); // iOS Red
      statusText = l10n.gps_weak;
    }

    // 状态文本：优先显示传感器假死或惯导状态，其次是 GPS 状态
    String displayText;
    if (state.isSensorFrozen) {
      displayText = l10n.sensor_frozen;
      statusColor = Colors.orange;
    } else if (state.isInsActive) {
      displayText = l10n.ins_active;
      statusColor = Colors.blue;
    } else {
      displayText = "$statusText (${accuracy.toStringAsFixed(0)}m)";
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                displayText.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
