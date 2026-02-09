import 'dart:ui';
import 'package:flutter/material.dart';

class RecordingStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool compact;

  const RecordingStat({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 12 : 14, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontFamily: 'monospace',
                    color: colorScheme.onSurface)),
          ],
        ),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
