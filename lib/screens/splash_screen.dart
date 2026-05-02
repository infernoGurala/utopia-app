// ============================================================================
// UTOPIA Cinematic Splash Screen
// ============================================================================
// To wire into main.dart, replace the existing SplashScreen class with:
//   import 'screens/splash_screen.dart';
// Then use CinematicSplashScreen() wherever SplashScreen() was used.
//
// Or rename this class to SplashScreen and remove the old one from main.dart.
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The minimum display duration that external code (e.g. AuthGate) can query
/// to know how long the splash needs before the app may navigate away.
const Duration cinematicSplashDuration = Duration(milliseconds: 3000);

class CinematicSplashScreen extends StatefulWidget {
  const CinematicSplashScreen({super.key});

  @override
  State<CinematicSplashScreen> createState() => _CinematicSplashScreenState();
}

class _CinematicSplashScreenState extends State<CinematicSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ── Phase 1: Star entrance (0ms–600ms) ──
  late final Animation<double> _starScale;

  // ── Phase 2: Fireballs travel + star rotation start (600ms–1200ms) ──
  late final Animation<double> _fireballTravel;
  late final Animation<double> _starRotationPhase2;

  // ── Phase 3: Crescent draw + fireball shrink (1200ms–2200ms) ──
  late final Animation<double> _crescentDraw;
  late final Animation<double> _fireballFade;
  late final Animation<double> _starRotationPhase3;

  // ── Phase 4: Bloom impact (2200ms–2600ms) ──
  late final Animation<double> _bloomExpand;
  late final Animation<double> _bgGlowIntensity;

  // ── Phase 5: Hold + fade out (2600ms–3000ms) ──
  late final Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Phase 1: 0.0–0.2 (0ms–600ms)
    _starScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.2, curve: Curves.elasticOut),
    );

    // Phase 2: 0.2–0.4 (600ms–1200ms)
    _fireballTravel = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.4, curve: Curves.easeInOut),
    );
    _starRotationPhase2 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.4, curve: Curves.easeIn),
    );

    // Phase 3: 0.4–0.733 (1200ms–2200ms)
    _crescentDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.733, curve: Curves.easeInOut),
    );
    _fireballFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.733, curve: Curves.easeIn),
    );
    _starRotationPhase3 = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.733, curve: Curves.decelerate),
    );

    // Phase 4: 0.733–0.867 (2200ms–2600ms)
    _bloomExpand = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.733, 0.867, curve: Curves.easeOut),
    );
    _bgGlowIntensity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.867, curve: Curves.easeIn),
    );

    // Phase 5: 0.867–1.0 (2600ms–3000ms)
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.867, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _UtopiaSplashPainter(
              starScale: _starScale.value,
              fireballTravel: _fireballTravel.value,
              starRotation: _starRotationPhase2.value * 2 * math.pi +
                  _starRotationPhase3.value * 0.5 * math.pi,
              crescentDraw: _crescentDraw.value,
              fireballOpacity: (1.0 - _fireballFade.value).clamp(0.0, 1.0),
              fireballSize: 1.0 - _fireballFade.value * 0.8,
              bloomExpand: _bloomExpand.value,
              bgGlowIntensity: _bgGlowIntensity.value,
              fadeOut: _fadeOut.value,
            ),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Custom Painter — draws EVERYTHING
// ════════════════════════════════════════════════════════════════════════════

class _UtopiaSplashPainter extends CustomPainter {
  _UtopiaSplashPainter({
    required this.starScale,
    required this.fireballTravel,
    required this.starRotation,
    required this.crescentDraw,
    required this.fireballOpacity,
    required this.fireballSize,
    required this.bloomExpand,
    required this.bgGlowIntensity,
    required this.fadeOut,
  });

  final double starScale;
  final double fireballTravel;
  final double starRotation;
  final double crescentDraw;
  final double fireballOpacity;
  final double fireballSize;
  final double bloomExpand;
  final double bgGlowIntensity;
  final double fadeOut;

  // ── Logo geometry constants ──
  static const int _starPoints = 7;
  static const double _outerRadiusFraction = 0.14; // relative to screen width
  static const double _innerRadiusFraction = 0.065;
  static const double _crescentRadiusFraction = 0.18;
  static const double _crescentStrokeWidth = 4.5;

  // ── Colors ──
  static const Color _bgColor = Color(0xFF0A0A12);
  static const Color _starColor = Colors.white;
  static const Color _crescentColor = Colors.white;
  static const Color _violetGlow = Color(0xFF7B6FD0);
  static const Color _fireballCore = Color(0xFFFFE0A0);
  static const Color _fireballGlow = Color(0xFF7B6FD0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = math.min(size.width, size.height);
    final outerR = unit * _outerRadiusFraction;
    final innerR = unit * _innerRadiusFraction;
    final crescentR = unit * _crescentRadiusFraction;

    // ── 1. Background glow (violet radial gradient) ──
    _drawBackgroundGlow(canvas, size, center, unit);

    // ── 2. Bloom impact ring (Phase 4) ──
    if (bloomExpand > 0) {
      _drawBloom(canvas, center, unit);
    }

    // ── 3. Fireballs (Phases 2 & 3) ──
    if (fireballTravel > 0 && fireballOpacity > 0) {
      _drawFireballs(canvas, size, center, crescentR);
    }

    // ── 4. Star (Phase 1 onward) ──
    if (starScale > 0) {
      _drawStar(canvas, center, outerR, innerR);
    }

    // ── 5. Crescent (Phase 3 onward) ──
    if (crescentDraw > 0) {
      _drawCrescent(canvas, center, crescentR);
    }

    // ── 6. Fade-to-black overlay (Phase 5) ──
    if (fadeOut > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = _bgColor.withValues(alpha: fadeOut),
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Background violet glow
  // ────────────────────────────────────────────────────────────────────────
  void _drawBackgroundGlow(
      Canvas canvas, Size size, Offset center, double unit) {
    final glowRadius = unit * 0.5 * bgGlowIntensity;
    if (glowRadius <= 0) return;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        glowRadius,
        [
          _violetGlow.withValues(alpha: 0.35 * bgGlowIntensity),
          _violetGlow.withValues(alpha: 0.08 * bgGlowIntensity),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Bloom impact (expanding ring of light)
  // ────────────────────────────────────────────────────────────────────────
  void _drawBloom(Canvas canvas, Offset center, double unit) {
    final maxRadius = unit * 0.4;
    final radius = maxRadius * bloomExpand;
    final opacity = (1.0 - bloomExpand).clamp(0.0, 1.0);

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius.clamp(1.0, double.infinity),
        [
          Colors.white.withValues(alpha: 0.6 * opacity),
          _violetGlow.withValues(alpha: 0.3 * opacity),
          Colors.transparent,
        ],
        [0.0, 0.4, 1.0],
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawCircle(center, radius, paint);
  }

  // ────────────────────────────────────────────────────────────────────────
  // 7-pointed star with dark center cutout
  // ────────────────────────────────────────────────────────────────────────
  void _drawStar(
      Canvas canvas, Offset center, double outerR, double innerR) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(starScale, starScale);
    canvas.rotate(starRotation);

    final starPath = _buildStarPath(outerR, innerR);

    // Glow layer
    final glowPaint = Paint()
      ..color = _starColor.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawPath(starPath, glowPaint);

    // White fill
    final fillPaint = Paint()
      ..color = _starColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(starPath, fillPaint);

    // Dark center cutout (teardrop / circle)
    final cutoutRadius = innerR * 0.75;
    final cutoutPaint = Paint()
      ..color = _bgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, cutoutRadius, cutoutPaint);

    // Stroke outline for definition
    final strokePaint = Paint()
      ..color = _starColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(starPath, strokePaint);

    canvas.restore();
  }

  Path _buildStarPath(double outerR, double innerR) {
    final path = Path();
    final angleStep = math.pi / _starPoints; // half-step between outer/inner

    for (int i = 0; i < _starPoints * 2; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final r = i.isEven ? outerR : innerR;
      final x = r * math.cos(angle);
      final y = r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  // ────────────────────────────────────────────────────────────────────────
  // Crescent arc drawn progressively via PathMetric
  // ────────────────────────────────────────────────────────────────────────
  void _drawCrescent(Canvas canvas, Offset center, double radius) {
    // Build the full crescent path — a wide arc (~300°) that creates the
    // crescent moon shape encircling the star (with a gap on the right).
    final crescentPath = Path();

    // Crescent as an arc from roughly 110° to 410° (i.e. 300° sweep)
    // This matches the reference: the gap is on the lower-right.
    const startAngle = 130 * math.pi / 180; // 130°
    const sweepAngle = 280 * math.pi / 180; // 280° sweep

    crescentPath.addArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
    );

    // Measure and extract partial path
    final metrics = crescentPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final drawLength = metric.length * crescentDraw;
    final extractedPath = metric.extractPath(0, drawLength);

    // Glow layer
    final glowPaint = Paint()
      ..color = _crescentColor.withValues(alpha: 0.5 * crescentDraw)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _crescentStrokeWidth + 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(extractedPath, glowPaint);

    // Solid crescent stroke
    final paint = Paint()
      ..color = _crescentColor.withValues(alpha: crescentDraw)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _crescentStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(extractedPath, paint);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Fireballs with comet trails
  // ────────────────────────────────────────────────────────────────────────
  void _drawFireballs(
      Canvas canvas, Size size, Offset center, double crescentR) {
    // Two fireballs: top-left → center, bottom-right → center
    _drawSingleFireball(
      canvas,
      start: Offset(size.width * 0.05, size.height * 0.08),
      control1: Offset(size.width * 0.15, size.height * 0.35),
      control2: Offset(center.dx - crescentR * 0.8, center.dy - crescentR * 0.5),
      end: Offset(center.dx - crescentR * 0.3, center.dy - crescentR * 0.3),
    );
    _drawSingleFireball(
      canvas,
      start: Offset(size.width * 0.95, size.height * 0.92),
      control1: Offset(size.width * 0.85, size.height * 0.65),
      control2: Offset(center.dx + crescentR * 0.8, center.dy + crescentR * 0.5),
      end: Offset(center.dx + crescentR * 0.3, center.dy + crescentR * 0.3),
    );
  }

  void _drawSingleFireball(
    Canvas canvas, {
    required Offset start,
    required Offset control1,
    required Offset control2,
    required Offset end,
  }) {
    if (fireballTravel <= 0) return;

    // Build cubic bezier path
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx, control1.dy,
        control2.dx, control2.dy,
        end.dx, end.dy,
      );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    // Current position along the path
    final currentLength = metric.length * fireballTravel;
    final tangent = metric.getTangentForOffset(currentLength);
    if (tangent == null) return;
    final pos = tangent.position;

    // Draw comet trail (series of fading dots behind)
    const trailCount = 14;
    for (int i = trailCount; i >= 0; i--) {
      final trailT = currentLength - (i * metric.length * 0.015);
      if (trailT < 0) continue;
      final trailTangent = metric.getTangentForOffset(trailT);
      if (trailTangent == null) continue;

      final trailAlpha = (1.0 - i / trailCount) * fireballOpacity * 0.6;
      final trailRadius = (8.0 * fireballSize) * (1.0 - i / trailCount) * 0.5;

      final trailPaint = Paint()
        ..color = _fireballCore.withValues(alpha: trailAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(trailTangent.position, trailRadius, trailPaint);
    }

    // Draw the fireball head: outer violet glow
    final outerGlow = Paint()
      ..color = _fireballGlow.withValues(alpha: 0.5 * fireballOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(pos, 14 * fireballSize, outerGlow);

    // Inner warm-white core
    final core = Paint()
      ..color = _fireballCore.withValues(alpha: fireballOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(pos, 8 * fireballSize, core);

    // Bright white center
    final bright = Paint()
      ..color = Colors.white.withValues(alpha: fireballOpacity * 0.9);
    canvas.drawCircle(pos, 3 * fireballSize, bright);
  }

  @override
  bool shouldRepaint(_UtopiaSplashPainter old) {
    return old.starScale != starScale ||
        old.fireballTravel != fireballTravel ||
        old.starRotation != starRotation ||
        old.crescentDraw != crescentDraw ||
        old.fireballOpacity != fireballOpacity ||
        old.fireballSize != fireballSize ||
        old.bloomExpand != bloomExpand ||
        old.bgGlowIntensity != bgGlowIntensity ||
        old.fadeOut != fadeOut;
  }
}
