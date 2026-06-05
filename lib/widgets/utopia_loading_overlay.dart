import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class UtopiaLoadingOverlay extends StatefulWidget {
  final String message;

  const UtopiaLoadingOverlay({
    super.key,
    this.message = 'Saving changes...',
  });

  @override
  State<UtopiaLoadingOverlay> createState() => _UtopiaLoadingOverlayState();
}

class _UtopiaLoadingOverlayState extends State<UtopiaLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;

    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Stack(
          children: [
            // ── Premium Soft Blurred Backdrop ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ),

            // ── Minimalist Glassmorphism Loading Pill ──
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF16161A).withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Rotating Gradient Arc Spinner ──
                    RotationTransition(
                      turns: _rotationController,
                      child: CustomPaint(
                        size: const Size(36, 36),
                        painter: _GradientSpinnerPainter(
                          color: U.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Sleek Status Text with Pulse ──
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.6, end: 1.0)
                          .animate(_pulseController),
                      child: Text(
                        widget.message,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientSpinnerPainter extends CustomPainter {
  final Color color;

  _GradientSpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      math.pi * 1.7, // 306 degrees arc
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
