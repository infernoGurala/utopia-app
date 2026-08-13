import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A native Flutter recreation of the famous "Wheel and Hamster" CSS animation by Nawsome.
/// Displays an orange and tan hamster running inside a rotating metal wheel.
class HamsterLoader extends StatefulWidget {
  final double size;

  const HamsterLoader({
    super.key,
    this.size = 140.0,
  });

  @override
  State<HamsterLoader> createState() => _HamsterLoaderState();
}

class _HamsterLoaderState extends State<HamsterLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _HamsterWheelPainter(progress: t),
          );
        },
      ),
    );
  }
}

class _HamsterWheelPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _HamsterWheelPainter({required this.progress});

  // Keyframe helper (sine oscillation over 8 sub-steps: 0, 12.5%, 25%, ...)
  double _oscillate(double val1, double val2) {
    // 4 full cycles over 1 second (12.5% step interval)
    final cycle = math.sin(progress * math.pi * 8);
    final norm = (cycle + 1) / 2;
    return val1 + (val2 - val1) * norm;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 168.0; // 12em base = 168px
    canvas.save();
    canvas.scale(scale, scale);

    // ── 1. Wheel Outer Rim ──
    final rimPaint = Paint()
      ..color = const Color(0xFF999999)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0;

    final center = const Offset(84, 84);
    canvas.drawCircle(center, 80.5, rimPaint);

    // ── 2. Rotating Spokes & Center Hub ──
    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Rotate counter-clockwise (-1 turn over 1s)
    canvas.rotate(-progress * 2 * math.pi);

    final spokePaint = Paint()
      ..color = const Color(0xFFA6A6A6)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Cross spoke bar
    canvas.drawLine(const Offset(-80, 0), const Offset(80, 0), spokePaint);

    // Center hub cap
    final hubPaint = Paint()..color = const Color(0xFF999999);
    canvas.drawCircle(Offset.zero, 7.5, hubPaint);
    final hubInnerPaint = Paint()..color = const Color(0xFF666666);
    canvas.drawCircle(Offset.zero, 3.5, hubInnerPaint);

    canvas.restore();

    // ── 3. Hamster Character ──
    canvas.save();

    // Hamster root wobble (ease in out sine over 1s)
    final hamsterBounce = math.sin(progress * math.pi * 2);
    final hamsterAngle = (4.0 * (hamsterBounce + 1) / 2) * math.pi / 180;
    canvas.translate(center.dx - 11.2, center.dy + 25.9);
    canvas.rotate(hamsterAngle);

    // Palette
    const orangeFur = Color(0xFFF48618);
    const lightFur = Color(0xFFFDF1D7);
    const highlightFur = Color(0xFFFCE3B4);
    const pinkEarNose = Color(0xFFFCBAC3);
    const darkShade = Color(0xFFD6720D);

    // Animated limb angles
    final frAngle = _oscillate(50, -30) * math.pi / 180;
    final flAngle = _oscillate(-30, 50) * math.pi / 180;
    final brAngle = _oscillate(-60, 20) * math.pi / 180;
    final blAngle = _oscillate(20, -60) * math.pi / 180;
    final headAngle = _oscillate(0, 8) * math.pi / 180;
    final earAngle = _oscillate(0, 12) * math.pi / 180;
    final bodyAngle = _oscillate(0, -2) * math.pi / 180;
    final tailAngle = _oscillate(30, 10) * math.pi / 180;

    // ── Back Limbs (behind body) ──
    _drawLimb(canvas, const Offset(39.2, 14), brAngle, highlightFur, darkShade, isBack: true);
    _drawLimb(canvas, const Offset(7, 28), frAngle, highlightFur, darkShade, isBack: false);

    // ── Body ──
    canvas.save();
    canvas.translate(28, 3.5);
    canvas.rotate(bodyAngle);

    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 63, 42),
      const Radius.circular(21),
    );

    final bodyPaint = Paint()..color = lightFur;
    canvas.drawRRect(bodyRect, bodyPaint);

    // Orange back patch on body
    final backFurPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(20, -5, 45, 0, 63, 10)
      ..cubicTo(55, 30, 25, 30, 0, 20)
      ..close();
    final backFurPaint = Paint()..color = orangeFur;
    canvas.drawPath(backFurPath, backFurPaint);

    // Tail
    canvas.save();
    canvas.translate(63, 21);
    canvas.rotate(tailAngle);
    final tailPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, -3.5, 14, 7),
        const Radius.circular(3.5),
      ));
    final tailPaint = Paint()..color = pinkEarNose;
    canvas.drawPath(tailPath, tailPaint);
    canvas.restore();

    canvas.restore();

    // ── Head ──
    canvas.save();
    canvas.translate(-28, 0);
    canvas.rotate(headAngle);

    final headPath = Path()
      ..moveTo(0, 15)
      ..cubicTo(0, 0, 20, 0, 38.5, 5)
      ..cubicTo(38.5, 25, 20, 35, 0, 15)
      ..close();
    final headPaint = Paint()..color = orangeFur;
    canvas.drawPath(headPath, headPaint);

    // Light muzzle / jaw
    final jawPath = Path()
      ..moveTo(0, 15)
      ..cubicTo(5, 25, 25, 32, 38.5, 25)
      ..cubicTo(25, 25, 10, 20, 0, 15)
      ..close();
    final jawPaint = Paint()..color = lightFur;
    canvas.drawPath(jawPath, jawPaint);

    // Ear
    canvas.save();
    canvas.translate(28, -3.5);
    canvas.rotate(earAngle);
    final earOuterPaint = Paint()..color = darkShade;
    canvas.drawCircle(Offset.zero, 5.25, earOuterPaint);
    final earInnerPaint = Paint()..color = pinkEarNose;
    canvas.drawCircle(Offset.zero, 3.5, earInnerPaint);
    canvas.restore();

    // Eye (with blinking)
    double eyeScaleY = 1.0;
    if (progress >= 0.93 && progress <= 0.97) {
      eyeScaleY = 0.1;
    }
    canvas.save();
    canvas.translate(17.5, 5.25);
    canvas.scale(1.0, eyeScaleY);
    final eyePaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset.zero, 3.5, eyePaint);
    final eyeShine = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(-1, -1), 1.0, eyeShine);
    canvas.restore();

    // Nose
    final nosePaint = Paint()..color = pinkEarNose;
    canvas.drawOval(
      Rect.fromLTWH(0, 10.5, 3.5, 4.2),
      nosePaint,
    );

    canvas.restore(); // Head end

    // ── Front Limbs (in front of body) ──
    _drawLimb(canvas, const Offset(39.2, 14), blAngle, lightFur, pinkEarNose, isBack: true);
    _drawLimb(canvas, const Offset(7, 28), flAngle, lightFur, pinkEarNose, isBack: false);

    canvas.restore(); // Hamster root end
    canvas.restore(); // Main scale end
  }

  void _drawLimb(
    Canvas canvas,
    Offset origin,
    double angle,
    Color mainColor,
    Color pawColor, {
    required bool isBack,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);

    final width = isBack ? 21.0 : 14.0;
    final height = isBack ? 35.0 : 21.0;

    final legPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(7),
      ));

    final legPaint = Paint()..color = mainColor;
    canvas.drawPath(legPath, legPaint);

    final pawPaint = Paint()..color = pawColor;
    canvas.drawRect(
      Rect.fromLTWH(0, height * 0.75, width, height * 0.25),
      pawPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HamsterWheelPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
