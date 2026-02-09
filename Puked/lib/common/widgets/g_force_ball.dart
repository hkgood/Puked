import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class GForceBall extends StatefulWidget {
  final v.Vector3 acceleration;
  final v.Vector3 gyroscope;
  final double size;

  const GForceBall({
    super.key,
    required this.acceleration,
    required this.gyroscope,
    this.size = 200,
  });

  @override
  State<GForceBall> createState() => _GForceBallState();
}

class _GForceBallState extends State<GForceBall> {
  late v.Vector3 _displayAccel;
  late v.Vector3 _displayGyro;
  static const double _lerpCoeff = 0.15; // 平滑系数

  @override
  void initState() {
    super.initState();
    _displayAccel = widget.acceleration.clone();
    _displayGyro = widget.gyroscope.clone();
  }

  @override
  void didUpdateWidget(GForceBall oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 对显示数值进行平滑插值 (LERP)，消除视觉抖动
    _displayAccel =
        _displayAccel * (1.0 - _lerpCoeff) + widget.acceleration * _lerpCoeff;
    _displayGyro =
        _displayGyro * (1.0 - _lerpCoeff) + widget.gyroscope * _lerpCoeff;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: Real3DSensorPainter(
            accel: _displayAccel,
            gyro: _displayGyro,
            color: primaryColor,
            isDarkMode: isDarkMode,
          ),
        ),
      ),
    );
  }
}

class Real3DSensorPainter extends CustomPainter {
  final v.Vector3 accel;
  final v.Vector3 gyro;
  final Color color;
  final bool isDarkMode;

  Real3DSensorPainter({
    required this.accel,
    required this.gyro,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 建立基础 3D 转换矩阵
    final sphereMatrix = v.Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(gyro.x * 0.2)
      ..rotateY(gyro.y * 0.2)
      ..rotateZ(gyro.z * 0.2);

    // 2. 绘制球体背景和网格 (继续增加透明度，使其更加隐约)
    final bgPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    _draw3DSphereGrid(canvas, center, radius, sphereMatrix, bgPaint);

    // 3. 绘制始终展示的固定 XYZ 轴 (随球体旋转)
    _drawFixedAxes(canvas, center, radius, sphereMatrix);

    // 4. 计算并绘制受力分量 (G值)
    double gX = accel.x / 9.80665;
    double gY = -accel.y / 9.80665;
    double gZ = (accel.z - 9.80665) / 9.80665;

    const colorX = Color(0xFFFF453A); // Apple Red
    const colorY = Color(0xFF32D74B); // Apple Green
    const colorZ = Color(0xFF0A84FF); // Apple Blue

    // 绘制受力分量 (动态变化的线，加粗)
    _drawForceComponent(
        canvas, center, radius, sphereMatrix, v.Vector3(gX, 0, 0), colorX);
    _drawForceComponent(
        canvas, center, radius, sphereMatrix, v.Vector3(0, gY, 0), colorY);
    _drawForceComponent(
        canvas, center, radius, sphereMatrix, v.Vector3(0, 0, gZ), colorZ);

    // 5. 绘制核心指示球和合力丝带
    v.Vector3 forceVec = v.Vector3(gX, gY, gZ);
    double forceMagnitude = forceVec.length;

    canvas.drawCircle(center, 2, Paint()..color = color.withValues(alpha: 0.5));

    if (forceMagnitude > 0.01) {
      v.Vector3 ballPos3D = v.Vector3(gX * radius, gY * radius, gZ * radius);
      if (ballPos3D.length > radius * 0.95) {
        ballPos3D.normalize();
        ballPos3D.scale(radius * 0.95);
      }

      v.Vector4 projectedPos = sphereMatrix
          .transform(v.Vector4(ballPos3D.x, ballPos3D.y, ballPos3D.z, 1.0));
      double w = projectedPos.w == 0 ? 1.0 : projectedPos.w;
      Offset ballPos2D =
          center + Offset(projectedPos.x / w, projectedPos.y / w);

      // 合力丝带 (加粗)
      final vectorPaint = Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromPoints(center, ballPos2D))
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, ballPos2D, vectorPaint);

      double depthScale = (projectedPos.z / w + radius) / (2 * radius);
      depthScale = depthScale.clamp(0.6, 1.4);

      final ballPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Colors.white, color, color.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(
            center: ballPos2D, radius: radius * 0.1 * depthScale));
      canvas.drawCircle(ballPos2D, radius * 0.1 * depthScale, ballPaint);
    }

    // 6. 外部刻度环 (显著加粗)
    final ringPaint = Paint()
      ..color =
          isDarkMode ? Colors.white24 : Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, ringPaint);

    final dashPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    _drawDashCircle(canvas, center, radius * 0.5, dashPaint);
  }

  void _drawForceComponent(Canvas canvas, Offset center, double radius,
      v.Matrix4 matrix, v.Vector3 vec, Color color) {
    if (vec.length < 0.01) return;
    v.Vector3 endPoint3D =
        v.Vector3(vec.x * radius, vec.y * radius, vec.z * radius);
    v.Vector4 p = matrix
        .transform(v.Vector4(endPoint3D.x, endPoint3D.y, endPoint3D.z, 1.0));
    double w = p.w == 0 ? 1.0 : p.w;
    Offset endPoint2D = center + Offset(p.x / w, p.y / w);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.8) // 动态受力线颜色深一些
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, endPoint2D, linePaint);
    canvas.drawCircle(endPoint2D, 4, Paint()..color = color);
  }

  void _draw3DSphereGrid(Canvas canvas, Offset center, double radius,
      v.Matrix4 matrix, Paint paint) {
    const int segments = 8;
    for (int i = 1; i < segments; i++) {
      double lat = (i / segments) * pi;
      _draw3DCircle(canvas, center, radius, matrix, paint, lat, true);
    }
    for (int i = 0; i < segments; i++) {
      double lon = (i / segments) * 2 * pi;
      _draw3DCircle(canvas, center, radius, matrix, paint, lon, false);
    }
  }

  void _draw3DCircle(Canvas canvas, Offset center, double radius,
      v.Matrix4 matrix, Paint paint, double angle, bool isLat) {
    const int pointsCount = 24;
    final path = Path();
    bool first = true;
    for (int i = 0; i <= pointsCount; i++) {
      double t = (i / pointsCount) * 2 * pi;
      double x, y, z;
      if (isLat) {
        x = radius * sin(angle) * cos(t);
        y = radius * cos(angle);
        z = radius * sin(angle) * sin(t);
      } else {
        x = radius * cos(angle) * sin(t);
        y = radius * cos(t);
        z = radius * sin(angle) * sin(t);
      }
      v.Vector4 p = matrix.transform(v.Vector4(x, y, z, 1.0));
      double w = p.w == 0 ? 1.0 : p.w;
      Offset pos = center + Offset(p.x / w, p.y / w);
      if (first) {
        path.moveTo(pos.dx, pos.dy);
        first = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    const int dashCount = 40;
    const double dashAngle = (2 * pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
            i * dashAngle, dashAngle, false, paint);
      }
    }
  }

  void _drawFixedAxes(
      Canvas canvas, Offset center, double radius, v.Matrix4 matrix) {
    final paintX = Paint()
      ..color = const Color(0xFFFF453A).withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    final paintY = Paint()
      ..color = const Color(0xFF32D74B).withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    final paintZ = Paint()
      ..color = const Color(0xFF0A84FF).withValues(alpha: 0.25)
      ..strokeWidth = 1.5;

    // X 轴 (横向)
    _draw3DLine(canvas, center, matrix, v.Vector3(-radius, 0, 0),
        v.Vector3(radius, 0, 0), paintX);
    // Y 轴 (纵向)
    _draw3DLine(canvas, center, matrix, v.Vector3(0, -radius, 0),
        v.Vector3(0, radius, 0), paintY);
    // Z 轴 (垂向)
    _draw3DLine(canvas, center, matrix, v.Vector3(0, 0, -radius),
        v.Vector3(0, 0, radius), paintZ);
  }

  void _draw3DLine(Canvas canvas, Offset center, v.Matrix4 matrix,
      v.Vector3 start, v.Vector3 end, Paint paint) {
    v.Vector4 pStart =
        matrix.transform(v.Vector4(start.x, start.y, start.z, 1.0));
    v.Vector4 pEnd = matrix.transform(v.Vector4(end.x, end.y, end.z, 1.0));

    double wS = pStart.w == 0 ? 1.0 : pStart.w;
    double wE = pEnd.w == 0 ? 1.0 : pEnd.w;

    Offset start2D = center + Offset(pStart.x / wS, pStart.y / wS);
    Offset end2D = center + Offset(pEnd.x / wE, pEnd.y / wE);

    canvas.drawLine(start2D, end2D, paint);
  }

  @override
  bool shouldRepaint(covariant Real3DSensorPainter oldDelegate) =>
      oldDelegate.accel != accel || oldDelegate.gyro != gyro;
}
