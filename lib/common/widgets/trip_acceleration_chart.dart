import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:puked/models/db_models.dart';

class TripAccelerationChart extends StatelessWidget {
  final List<TrajectoryPoint> trajectory;
  final String label;
  final Color color;
  final bool isLongitudinal; // true for Longitudinal, false for Lateral

  const TripAccelerationChart({
    super.key,
    required this.trajectory,
    required this.label,
    required this.color,
    required this.isLongitudinal,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = trajectory.length >= 2;
    List<double> processedData = [];

    if (hasData) {
      final data = _calculateAcceleration();
      if (data.isNotEmpty) {
        processedData = _downsample(data, 150);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          height: 120,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainer
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.1),
            ),
          ),
          child: Stack(
            children: [
              // 始终显示背景网格
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(
                    isDark: isDark,
                  ),
                ),
              ),
              if (processedData.isEmpty)
                _buildEmptyState(context)
              else
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AccelerationPainter(
                      data: processedData,
                      color: color,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        "NO RECORDED DATA",
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  List<double> _calculateAcceleration() {
    final List<double> results = [];
    if (trajectory.length < 2) return results;

    for (int i = 1; i < trajectory.length; i++) {
      final p1 = trajectory[i - 1];
      final p2 = trajectory[i];

      final dt = p2.timestamp.difference(p1.timestamp).inMilliseconds / 1000.0;
      if (dt <= 0) continue;

      if (isLongitudinal) {
        // 纵向加速度: delta(v) / delta(t)
        final dv = p2.speed - p1.speed;
        double acc = dv / dt;
        acc = acc.clamp(-10.0, 10.0);
        results.add(acc);
      } else {
        // 横向加速度估算: v * omega
        final heading1 = _calculateHeading(p1, p2);

        if (i < trajectory.length - 1) {
          final p3 = trajectory[i + 1];
          final heading2 = _calculateHeading(p2, p3);

          double dTheta = heading2 - heading1;
          if (dTheta > pi) dTheta -= 2 * pi;
          if (dTheta < -pi) dTheta += 2 * pi;

          final avgSpeed = (p1.speed + p2.speed) / 2.0;
          double latAcc = avgSpeed * (dTheta / dt);

          latAcc = latAcc.clamp(-5.0, 5.0);
          results.add(latAcc);
        } else {
          if (results.isNotEmpty) results.add(results.last);
        }
      }
    }

    if (results.length == 1) results.add(results.first);
    return results;
  }

  double _calculateHeading(TrajectoryPoint p1, TrajectoryPoint p2) {
    final lat1 = p1.lat * pi / 180.0;
    final lon1 = p1.lng * pi / 180.0;
    final lat2 = p2.lat * pi / 180.0;
    final lon2 = p2.lng * pi / 180.0;

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return atan2(y, x);
  }

  List<double> _downsample(List<double> data, int targetPoints) {
    if (data.length <= targetPoints) return data;

    final List<double> sampled = [];
    final double step = data.length / targetPoints;

    for (int i = 0; i < targetPoints; i++) {
      final index = (i * step).floor();
      sampled.add(data[index]);
    }
    return sampled;
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        gridPaint
          ..color =
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1));

    final double spacing = size.height / 6;
    canvas.drawLine(Offset(0, centerY - spacing),
        Offset(size.width, centerY - spacing), gridPaint);
    canvas.drawLine(Offset(0, centerY + spacing),
        Offset(size.width, centerY + spacing), gridPaint);
    canvas.drawLine(Offset(0, centerY - spacing * 2),
        Offset(size.width, centerY - spacing * 2), gridPaint);
    canvas.drawLine(Offset(0, centerY + spacing * 2),
        Offset(size.width, centerY + spacing * 2), gridPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccelerationPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;

  _AccelerationPainter({
    required this.data,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double centerY = size.height / 2;
    double maxVal = data.map((e) => e.abs()).reduce(max);
    if (maxVal < 2.0) maxVal = 2.0;
    final double scaleY = (size.height / 2) / (maxVal * 1.2);
    final double stepX = size.width / (data.length - 1);

    _drawAreaGradient(canvas, size, centerY, stepX, scaleY);
    _drawSmoothLine(canvas, size, centerY, stepX, scaleY);
  }

  void _drawAreaGradient(
      Canvas canvas, Size size, double centerY, double stepX, double scaleY) {
    final path = Path();
    path.moveTo(0, centerY);

    for (int i = 0; i < data.length; i++) {
      path.lineTo(i * stepX, centerY - data[i] * scaleY);
    }
    path.lineTo((data.length - 1) * stepX, centerY);
    path.close();

    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height),
      [
        color.withValues(alpha: 0.3),
        color.withValues(alpha: 0.01),
        color.withValues(alpha: 0.3),
      ],
      [0.0, 0.5, 1.0],
    );

    canvas.drawPath(path, Paint()..shader = gradient);
  }

  void _drawSmoothLine(
      Canvas canvas, Size size, double centerY, double stepX, double scaleY) {
    final path = Path();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    if (data.length < 3) {
      path.moveTo(0, centerY - data[0] * scaleY);
      for (int i = 1; i < data.length; i++) {
        path.lineTo(i * stepX, centerY - data[i] * scaleY);
      }
    } else {
      path.moveTo(0, centerY - data[0] * scaleY);
      for (int i = 0; i < data.length - 1; i++) {
        final x1 = i * stepX;
        final y1 = centerY - data[i] * scaleY;
        final x2 = (i + 1) * stepX;
        final y2 = centerY - data[i + 1] * scaleY;

        final controlX = (x1 + x2) / 2;
        path.cubicTo(controlX, y1, controlX, y2, x2, y2);
      }
    }

    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AccelerationPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
