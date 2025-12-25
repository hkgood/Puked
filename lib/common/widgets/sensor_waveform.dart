import 'package:flutter/material.dart';

class SensorWaveform extends StatelessWidget {
  final List<double> data;
  final Color color;
  final String label;
  final double limit;

  const SensorWaveform({
    super.key,
    required this.data,
    required this.color,
    required this.label,
    this.limit = 10.0, // 默认显示范围 +/- 10 m/s^2
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
              color: isDarkMode
                  ? Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 2),
        SizedBox(
          height: 48, // 减小高度从 60 到 48
          width: double.infinity,
          child: CustomPaint(
            painter: WaveformPainter(
              data: data,
              color: color,
              limit: limit,
              gridColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.2),
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

  WaveformPainter({
    required this.data,
    required this.color,
    required this.limit,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 // 稍微加粗
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 增加一个微弱的发光层
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final path = Path();
    final stepX = size.width / 100;
    final centerY = size.height / 2;
    final scaleY = size.height / (limit * 2);

    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double y = centerY - (data[i] * scaleY);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 绘制背景参考线 (更精致的虚线感)
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // 绘制多条水平参考线增加细节感
    canvas.drawLine(
        Offset(0, centerY * 0.5), Offset(size.width, centerY * 0.5), gridPaint);
    canvas.drawLine(
        Offset(0, centerY * 1.5), Offset(size.width, centerY * 1.5), gridPaint);

    // 主中心线稍微重一点
    final centerGridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, centerY), Offset(size.width, centerY), centerGridPaint);

    canvas.drawPath(path, shadowPaint); // 先画发光
    canvas.drawPath(path, paint); // 再画主体
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
