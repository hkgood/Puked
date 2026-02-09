import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/features/recording/providers/recording_provider.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class StatsCapsule extends ConsumerWidget {
  final VoidCallback onTap;

  const StatsCapsule({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingProvider);
    final l10n = AppLocalizations.of(context)!;
    final i18n = ref.watch(i18nProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                      context,
                      (state.currentSpeed * 3.6).toStringAsFixed(0),
                      l10n.speed.toUpperCase(),
                      unit: i18n.t('speed_unit', args: ['']).trim()),
                ),
                _buildVerticalDivider(context),
                Expanded(
                  child: _buildStatItem(
                      context,
                      (state.currentDistance / 1000.0).toStringAsFixed(1),
                      l10n.distance.toUpperCase(),
                      unit: i18n.t('distance_unit', args: ['']).trim()),
                ),
                _buildVerticalDivider(context),
                Expanded(
                  child: _buildStatItem(context,
                      state.currentGForce.toStringAsFixed(2), 'G-FORCE',
                      unit: 'G'),
                ),
                _buildVerticalDivider(context),
                Expanded(
                  child: _buildStatItem(context, state.events.length.toString(),
                      l10n.neg_exp.toUpperCase(),
                      unit: l10n.pts_unit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label,
      {String? unit}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final unitColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black54;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black45;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: unitColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    return Container(
      width: 0.5,
      height: 20,
      color: dividerColor,
    );
  }
}
