import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../main.dart';

/// A loading bar that replicates the CSS spark/progress animation.
/// - Grows from 0% → 100% width over 8 seconds (animFw)
/// - Two spark "tails" flicker at the leading edge every 0.3s (coli1/coli2)
/// - Color and track use the current app theme (U.primary)
/// - Glow is suppressed on light themes for visibility
class UtopiaLoader extends StatefulWidget {
  final double scale;
  final Color? color;

  const UtopiaLoader({
    super.key,
    this.scale = 1.0,
    this.color,
  });

  @override
  State<UtopiaLoader> createState() => _UtopiaLoaderState();
}

class _UtopiaLoaderState extends State<UtopiaLoader>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _sparkController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double barHeight = 2.5 * widget.scale;
    // Extra vertical space for sparks
    final double totalHeight = barHeight + (8.0 * widget.scale) * 2;

    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, __) {
        final Color resolvedColor = widget.color ?? U.primary;
        final bool isDark = theme.isDark;

        return Padding(
          // Horizontal inset so sparks at the very start/end don't clip
          padding: EdgeInsets.symmetric(horizontal: 6.0 * widget.scale),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = (constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 200.0 * widget.scale)
                  .clamp(0.0, 120.0 * widget.scale);

              return AnimatedBuilder(
                animation:
                    Listenable.merge([_progressController, _sparkController]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(maxWidth, totalHeight),
                    painter: _SparkLoaderPainter(
                      progress: _progressController.value,
                      sparkValue: _sparkController.value,
                      color: resolvedColor,
                      scale: widget.scale,
                      totalHeight: totalHeight,
                      barHeight: barHeight,
                      isDark: isDark,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SparkLoaderPainter extends CustomPainter {
  final double progress;
  final double sparkValue;
  final Color color;
  final double scale;
  final double totalHeight;
  final double barHeight;
  final bool isDark;

  _SparkLoaderPainter({
    required this.progress,
    required this.sparkValue,
    required this.color,
    required this.scale,
    required this.totalHeight,
    required this.barHeight,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double barY = (totalHeight - barHeight) / 2;
    final double barWidth = size.width * progress;
    final double radius = barHeight / 2;

    // 1. Background track — more visible on light themes
    final double trackAlpha = isDark ? 0.15 : 0.22;
    final Paint trackPaint = Paint()
      ..color = color.withValues(alpha: trackAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barY, size.width, barHeight),
        Radius.circular(radius),
      ),
      trackPaint,
    );

    if (barWidth < 1) return;

    // 2. Glow — dark themes only (light bg absorbs blur, makes it muddy)
    if (isDark) {
      final Paint glowPaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * scale);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barY, barWidth, barHeight),
          Radius.circular(radius),
        ),
        glowPaint,
      );
    }

    // 3. Solid bar — slightly higher opacity on light for contrast
    final Paint solidPaint = Paint()
      ..color = isDark ? color : color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, barY, barWidth, barHeight),
        Radius.circular(radius),
      ),
      solidPaint,
    );

    // 4. Sparks at the leading tip
    final double tipX = barWidth;
    final double sparkW = 6.0 * scale;
    final double sparkH = 0.8 * scale;
    // Sparks are more opaque on light themes to stay visible
    final double sparkBoost = isDark ? 1.0 : 1.4;

    // Spark 1 — after (coli1): rotates -45°, fades 0.7→0
    {
      final double opacity =
          (0.7 * sparkBoost * (1.0 - sparkValue)).clamp(0.0, 1.0);
      final double tx = -25.0 * scale * sparkValue;
      final double originX = tipX + 1.5 * scale;
      final double originY = barY + 5.0 * scale;

      canvas.save();
      canvas.translate(originX, originY);
      canvas.rotate(-math.pi / 4);
      canvas.translate(tx, 0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sparkW, sparkH),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }

    // Spark 2 — before (coli2): rotates +45°, fades 1→0.7
    {
      final double opacity =
          ((1.0 - 0.3 * sparkValue) * sparkBoost).clamp(0.0, 1.0);
      final double tx = -25.0 * scale * sparkValue;
      final double originX = tipX + 1.5 * scale;
      final double originY = barY - 3.0 * scale;

      canvas.save();
      canvas.translate(originX, originY);
      canvas.rotate(math.pi / 4);
      canvas.translate(tx, 0);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sparkW, sparkH),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparkLoaderPainter old) =>
      old.progress != progress ||
      old.sparkValue != sparkValue ||
      old.color != color ||
      old.scale != scale ||
      old.isDark != isDark;
}