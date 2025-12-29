import 'package:flutter/material.dart';

class SensorWaveform extends StatelessWidget {
  final List<double> data;
  final Color color;
  final String label;
  final double limit;
  final bool showAxes;

  const SensorWaveform({
    super.key,
    required this.data,
    required this.color,
    this.label = '',
    this.limit = 10.0,
    this.showAxes = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                      color: isDarkMode
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.9)
                          : colorScheme.onSurface.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                if (showAxes && data.isNotEmpty)
                  Text(
                    "${data.last.toStringAsFixed(2)}G",
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
        // 使用 Expanded 代替固定高度 SizedBox，让波形图自适应容器
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color:
                  showAxes ? color.withValues(alpha: 0.03) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: WaveformPainter(
                data: data,
                color: color,
                limit: limit,
                showAxes: showAxes,
                gridColor: colorScheme.outlineVariant,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double limit;
  final Color gridColor;
  final bool showAxes;
  final bool isDarkMode;

  WaveformPainter({
    required this.data,
    required this.color,
    required this.limit,
    required this.gridColor,
    required this.showAxes,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final scaleY = size.height / (limit * 2);

    // 1. 绘制背景参考线
    if (showAxes) {
      _drawDetailedAxes(canvas, size, centerY, scaleY);
    } else {
      _drawSimpleAxes(canvas, size, centerY);
    }

    if (data.isEmpty) return;

    // 2. 绘制数据曲线
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = showAxes ? 3.0 : 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = showAxes ? 5.0 : 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final stepX = size.width / 100;

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double y = (centerY - (data[i] * scaleY)).clamp(0, size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  void _drawSimpleAxes(Canvas canvas, Size size, double centerY) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    canvas.drawLine(
        Offset(0, centerY * 0.5), Offset(size.width, centerY * 0.5), gridPaint);
    canvas.drawLine(
        Offset(0, centerY * 1.5), Offset(size.width, centerY * 1.5), gridPaint);

    final centerGridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, centerY), Offset(size.width, centerY), centerGridPaint);
  }

  void _drawDetailedAxes(
      Canvas canvas, Size size, double centerY, double scaleY) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 绘制 0.5G 和 1.0G 的刻度线
    final levels = [1.0, 0.5, 0.0, -0.5, -1.0];
    for (var level in levels) {
      double y = centerY - (level * scaleY);

      // 线条
      final currentPaint = Paint()
        ..color = level == 0
            ? gridColor.withValues(alpha: 0.3)
            : gridColor.withValues(alpha: 0.1)
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        currentPaint,
      );

      // 文字标签
      if (size.width > 100) {
        textPainter.text = TextSpan(
          text: "${level > 0 ? '+' : ''}${level.toStringAsFixed(1)}G",
          style: TextStyle(
            color: gridColor.withValues(alpha: 0.6),
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        );
        textPainter.layout();
        textPainter.paint(
            canvas,
            Offset(size.width - textPainter.width - 4,
                y - textPainter.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
