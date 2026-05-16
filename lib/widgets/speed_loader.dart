import 'package:flutter/material.dart';
import 'dart:math';

class SpeedLoader extends StatefulWidget {
  final Color color;
  const SpeedLoader({super.key, this.color = Colors.black});

  @override
  State<SpeedLoader> createState() => _SpeedLoaderState();
}

class _SpeedLoaderState extends State<SpeedLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 60 seconds duration just to provide a continuous time counter without precision loss.
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Time from 0.0 to 60.0 seconds
          final double time = _controller.value * 60.0;
          return CustomPaint(
            painter: _SpeedLoaderMasterPainter(time: time, color: widget.color),
          );
        },
      ),
    );
  }
}

class _SpeedLoaderMasterPainter extends CustomPainter {
  final double time;
  final Color color;
  
  _SpeedLoaderMasterPainter({required this.time, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // --- DRAW LONG FAZERS (BACKGROUND) ---
    // LF1: duration 0.6s, delay 5s (so time + 5.0)
    _drawLongFazer(canvas, size, paint, (time + 5.0) % 0.6 / 0.6, 0.2, 500, -500);
    // LF2: duration 0.8s, delay 1s
    _drawLongFazer(canvas, size, paint, (time + 1.0) % 0.8 / 0.8, 0.4, 500, -500);
    // LF3: duration 0.6s
    _drawLongFazer(canvas, size, paint, time % 0.6 / 0.6, 0.6, 500, -250);
    // LF4: duration 0.5s, delay 3s
    _drawLongFazer(canvas, size, paint, (time + 3.0) % 0.5 / 0.5, 0.8, 500, -250);

    // --- CALCULATE SPEEDER VIBRATION ---
    final double tSpeeder = (time % 0.4) / 0.4; // 0.0 to 1.0
    double tx = 0, ty = 0, rot = 0;
    if (tSpeeder < 0.1) { tx = 2; ty = 1; rot = 0; }
    else if (tSpeeder < 0.2) { tx = -1; ty = -3; rot = -1; }
    else if (tSpeeder < 0.3) { tx = -2; ty = 0; rot = 1; }
    else if (tSpeeder < 0.4) { tx = 1; ty = 2; rot = 0; }
    else if (tSpeeder < 0.5) { tx = 1; ty = -1; rot = 1; }
    else if (tSpeeder < 0.6) { tx = -1; ty = 3; rot = -1; }
    else if (tSpeeder < 0.7) { tx = -1; ty = 1; rot = 0; }
    else if (tSpeeder < 0.8) { tx = 3; ty = 1; rot = -1; }
    else if (tSpeeder < 0.9) { tx = -2; ty = -1; rot = 1; }
    else { tx = 2; ty = 1; rot = 0; }

    canvas.save();
    // Center the speeder. Original CSS: left 50%, top 50%, margin-left -50px.
    // Our drawing is mostly extending to the right from x=0. So we center at x = cx - 50, y = cy.
    canvas.translate(cx - 50 + tx, cy + ty);
    canvas.rotate(rot * pi / 180);

    // --- DRAW EXHAUST FAZERS (LINES BEHIND CAR) ---
    // Fazer 1: 0.2s
    _drawFazer(canvas, paint, time % 0.2 / 0.2, 0, 0, -80);
    // Fazer 2: 0.4s
    _drawFazer(canvas, paint, time % 0.4 / 0.4, 3, 0, -100);
    // Fazer 3: 0.4s, delay 1s
    _drawFazer(canvas, paint, (time + 1.0) % 0.4 / 0.4, 1, 0, -50);
    // Fazer 4: 1.0s, delay 1s
    _drawFazer(canvas, paint, (time + 1.0) % 1.0 / 1.0, 4, 0, -150);

    // --- DRAW SPEEDER CAR BODY ---
    // 1. Exhaust block
    final exhaustRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(60, -19, 35, 5),
      topLeft: const Radius.circular(2),
      topRight: const Radius.circular(10),
      bottomLeft: Radius.zero,
      bottomRight: const Radius.circular(1),
    );
    canvas.drawRRect(exhaustRect, paint);

    // 2. Base Triangle
    final basePath = Path()
      ..moveTo(0, 6)
      ..lineTo(100, 0)
      ..lineTo(100, 12)
      ..close();
    canvas.drawPath(basePath, paint);

    // 3. Circle (base span:before)
    canvas.drawCircle(const Offset(99, -5), 11, paint);

    // 4. Back Triangle (base span:after)
    final backPath = Path()
      ..moveTo(43, -16)
      ..lineTo(98, -16)
      ..lineTo(98, 0)
      ..close();
    canvas.drawPath(backPath, paint);

    // 5. Face
    canvas.save();
    canvas.translate(115, -9); // Center of face
    canvas.rotate(-40 * pi / 180);
    final faceRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(-10, -6, 20, 12),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.zero,
      bottomRight: Radius.zero,
    );
    canvas.drawRRect(faceRect, paint);

    // 6. Face:after
    canvas.translate(0, 7);
    canvas.rotate(40 * pi / 180);
    final faceAfterRect = RRect.fromRectAndCorners(
      const Rect.fromLTWH(-6, -6, 12, 12),
      topLeft: Radius.zero,
      topRight: Radius.zero,
      bottomLeft: const Radius.circular(2),
      bottomRight: Radius.zero,
    );
    canvas.drawRRect(faceAfterRect, paint);
    canvas.restore(); // restore face

    canvas.restore(); // restore speeder transform
  }

  void _drawFazer(Canvas canvas, Paint paint, double t, double yOffset, double startLeft, double endLeft) {
    // startLeft and endLeft are relative to the exhaust block which is at x=60, y=-19.
    final left = startLeft + (endLeft - startLeft) * t;
    final opacity = 1.0 - t;
    paint.color = color.withOpacity(opacity.clamp(0.0, 1.0));
    canvas.drawRect(Rect.fromLTWH(60 + left, -19 + yOffset, 30, 1), paint);
    paint.color = color; // reset
  }

  void _drawLongFazer(Canvas canvas, Size size, Paint paint, double t, double topPercent, double startLeft, double endLeft) {
    final left = startLeft + (endLeft - startLeft) * t;
    final opacity = 1.0 - t;
    paint.color = color.withOpacity(opacity.clamp(0.0, 1.0));
    canvas.drawRect(Rect.fromLTWH(left, size.height * topPercent, 50, 2), paint);
    paint.color = color; // reset
  }

  @override
  bool shouldRepaint(covariant _SpeedLoaderMasterPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.color != color;
  }
}
