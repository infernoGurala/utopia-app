import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/delve_theme.dart';

/// Paints geometric flower-specific overlays behind content.
/// Each FlowerType has a unique set of shapes and movement patterns
/// that evoke the character of the real flower.
class BotanicalPainter extends CustomPainter {
  final Color blobColor;
  final Color inkColor;
  final Color accentColor;
  final int seed;
  final FlowerType flowerType;
  final double animationValue; // 0.0 → 1.0 loop for subtle motion

  BotanicalPainter({
    required this.blobColor,
    required this.inkColor,
    required this.accentColor,
    required this.seed,
    required this.flowerType,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (flowerType) {
      case FlowerType.wisteria:
        _paintWisteria(canvas, size);
        break;
      case FlowerType.bauhinia:
        _paintBauhinia(canvas, size);
        break;
      case FlowerType.sakura:
        _paintSakura(canvas, size);
        break;
      case FlowerType.maple:
        _paintMaple(canvas, size);
        break;
    }
  }

  // ──────────────────────────────────────────────
  //  WISTERIA — graceful cascading S-curve vines with flower clusters
  //  Character: elegant drooping tendrils, organic curves, teardrop chains
  // ──────────────────────────────────────────────
  void _paintWisteria(Canvas canvas, Size size) {
    final rand = Random(seed);

    // Large soft gradient blobs — ethereal purple glow
    _drawGlowBlobs(canvas, size, rand, count: 4, maxRadius: 220);

    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Draw 4–5 graceful hanging vine strands from top corners and edges
    final strands = 4 + rand.nextInt(2);
    for (var i = 0; i < strands; i++) {
      // Spread starting points more — from edges and corners
      final startX = size.width * (0.05 + (i / (strands - 1)) * 0.9);
      final swayOffset = sin(animationValue * 2 * pi + i * 1.2) * 15.0;

      // Main hanging vine — smooth S-curve using cubic beziers
      final vinePath = Path();
      vinePath.moveTo(startX + swayOffset, -20);

      var cx = startX + swayOffset;
      var cy = -20.0;
      final vineLength = size.height * (0.5 + rand.nextDouble() * 0.4);
      final segments = 5 + rand.nextInt(3);

      for (var j = 0; j < segments; j++) {
        final t = j / segments;
        final segLen = vineLength / segments;

        // Alternating S-curves — large sinuous horizontal drift
        final drift = sin(animationValue * 2 * pi + j * 0.6 + i) * 18.0;
        final horizontalCurve = sin(t * pi * 2 + i * 1.5) * (50 + rand.nextDouble() * 40);

        final nextCx = cx + horizontalCurve * 0.3 + drift;
        final nextCy = cy + segLen;

        // Cubic bezier for smooth S-curves
        final ctrl1X = cx + horizontalCurve * 0.6;
        final ctrl1Y = cy + segLen * 0.3;
        final ctrl2X = nextCx - horizontalCurve * 0.3;
        final ctrl2Y = nextCy - segLen * 0.3;

        vinePath.cubicTo(ctrl1X, ctrl1Y, ctrl2X, ctrl2Y, nextCx, nextCy);

        // Draw larger flower clusters at vine nodes
        if (rand.nextDouble() > 0.15) {
          _drawWisteriaCluster(canvas, nextCx, nextCy, rand, fillPaint, inkPaint, t);
        }

        cx = nextCx;
        cy = nextCy;
        if (cy > size.height * 0.9) break;
      }

      canvas.drawPath(vinePath, inkPaint);

      // Sub-tendrils branching off
      if (rand.nextDouble() > 0.3) {
        final branchY = vineLength * (0.3 + rand.nextDouble() * 0.3);
        final branchX = startX + sin(branchY * 0.01 + i) * 30;
        final subPath = Path();
        subPath.moveTo(branchX, branchY);
        final subEndX = branchX + (rand.nextDouble() - 0.5) * 80;
        final subEndY = branchY + 60 + rand.nextDouble() * 80;
        subPath.quadraticBezierTo(
            branchX + (subEndX - branchX) * 0.5 + 20,
            branchY + (subEndY - branchY) * 0.4,
            subEndX, subEndY);
        canvas.drawPath(subPath, inkPaint);
        _drawWisteriaCluster(canvas, subEndX, subEndY, rand, fillPaint, inkPaint, 0.5);
      }
    }

    // Floating individual teardrop petals — more and larger
    final floaters = 8 + rand.nextInt(5);
    for (var i = 0; i < floaters; i++) {
      final fx = size.width * rand.nextDouble();
      final baseY = size.height * rand.nextDouble();
      final fy = baseY + sin(animationValue * 2 * pi + i * 0.7) * 20;
      final rotation = animationValue * 2 * pi * 0.2 + i * 1.0;
      final s = 5 + rand.nextDouble() * 9;
      _drawTeardrop(canvas, fx, fy, s, rotation, fillPaint);
      // Outline for visibility
      _drawTeardrop(canvas, fx, fy, s + 1, rotation, inkPaint);
    }
  }

  void _drawWisteriaCluster(Canvas canvas, double x, double y, Random rand,
      Paint fill, Paint stroke, double progression) {
    // Cascading teardrop chain — gets smaller toward the tip
    final count = 4 + rand.nextInt(4);
    for (var k = 0; k < count; k++) {
      final offsetY = k * (10 + rand.nextDouble() * 6);
      final offsetX = sin(k * 0.8 + animationValue * 2 * pi) * (8 + rand.nextDouble() * 6);
      final s = (8 - k * 0.8).clamp(3.0, 9.0);
      _drawTeardrop(canvas, x + offsetX, y + offsetY, s, pi, fill);
      _drawTeardrop(canvas, x + offsetX, y + offsetY, s + 1.5, pi, stroke);
    }
  }

  void _drawTeardrop(Canvas canvas, double cx, double cy, double size,
      double angle, Paint paint) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final path = Path();
    path.moveTo(0, -size);
    path.quadraticBezierTo(size * 0.65, -size * 0.2, 0, size * 0.6);
    path.quadraticBezierTo(-size * 0.65, -size * 0.2, 0, -size);
    path.close();
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  // ──────────────────────────────────────────────
  //  BAUHINIA — orchid-tree petals + dandelion wisps
  //  Character: open star-like 5-petal flowers, radiating lines, floating seeds
  // ──────────────────────────────────────────────
  void _paintBauhinia(Canvas canvas, Size size) {
    final rand = Random(seed);

    // Soft glow blobs — cool grey/white
    _drawGlowBlobs(canvas, size, rand, count: 2, maxRadius: 150);

    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Draw 2-3 large bauhinia flowers (geometric 5-petal stars)
    final flowerCount = 2 + rand.nextInt(2);
    for (var i = 0; i < flowerCount; i++) {
      final fx = size.width * (0.2 + rand.nextDouble() * 0.6);
      final fy = size.height * (0.15 + rand.nextDouble() * 0.5);
      final fSize = 40 + rand.nextDouble() * 50;
      final rotation = animationValue * pi * 0.1 + i * 1.2;
      _drawBauhiniaFlower(canvas, fx, fy, fSize, rotation, inkPaint, fillPaint, rand);
    }

    // Dandelion wisps — radiating line clusters with floating seeds
    final wispCount = 3 + rand.nextInt(3);
    for (var i = 0; i < wispCount; i++) {
      final wx = size.width * rand.nextDouble();
      final wy = size.height * (0.3 + rand.nextDouble() * 0.5);
      _drawDandelionWisp(canvas, wx, wy, rand, inkPaint, fillPaint);
    }

    // Floating dandelion seeds
    final seedCount = 6 + rand.nextInt(5);
    for (var i = 0; i < seedCount; i++) {
      final sx = size.width * rand.nextDouble();
      final baseY = size.height * rand.nextDouble();
      final sy = baseY - sin(animationValue * 2 * pi + i * 0.9) * 20;
      _drawDandelionSeed(canvas, sx, sy, rand, inkPaint);
    }
  }

  void _drawBauhiniaFlower(Canvas canvas, double cx, double cy, double size,
      double rotation, Paint stroke, Paint fill, Random rand) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);

    // 5 elongated petals, each slightly different
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * pi;
      canvas.save();
      canvas.rotate(angle);

      final petalPath = Path();
      final petalLen = size * (0.8 + rand.nextDouble() * 0.4);
      final petalWidth = size * 0.3;

      petalPath.moveTo(0, 0);
      petalPath.quadraticBezierTo(petalWidth, -petalLen * 0.5, 0, -petalLen);
      petalPath.quadraticBezierTo(-petalWidth, -petalLen * 0.5, 0, 0);

      canvas.drawPath(petalPath, fill);
      canvas.drawPath(petalPath, stroke);

      // Center vein line
      final veinPaint = Paint()
        ..color = inkColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4;
      final vein = Path();
      vein.moveTo(0, 0);
      vein.lineTo(0, -petalLen * 0.85);
      canvas.drawPath(vein, veinPaint);

      canvas.restore();
    }

    // Center circle
    canvas.drawCircle(Offset.zero, size * 0.08, fill);
    canvas.drawCircle(Offset.zero, size * 0.08, stroke);

    canvas.restore();
  }

  void _drawDandelionWisp(Canvas canvas, double cx, double cy, Random rand,
      Paint stroke, Paint fill) {
    // Radiating thin lines from a center point
    final rays = 8 + rand.nextInt(8);
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * 2 * pi + animationValue * 0.3;
      final len = 15 + rand.nextDouble() * 25;
      final endX = cx + cos(angle) * len;
      final endY = cy + sin(angle) * len;

      canvas.drawLine(Offset(cx, cy), Offset(endX, endY), stroke);
      // Tiny circle at tip
      canvas.drawCircle(Offset(endX, endY), 1.5, fill);
    }
  }

  void _drawDandelionSeed(Canvas canvas, double cx, double cy, Random rand,
      Paint stroke) {
    // Tiny parachute shape — stem + radiating wisps
    final stemLen = 8 + rand.nextDouble() * 12;
    canvas.drawLine(
        Offset(cx, cy), Offset(cx, cy + stemLen), stroke);

    // Tiny radiating lines at top
    final wisps = 5 + rand.nextInt(4);
    for (var i = 0; i < wisps; i++) {
      final angle = pi + (i / wisps) * pi;
      final len = 4 + rand.nextDouble() * 6;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + cos(angle) * len, cy + sin(angle) * len),
        stroke,
      );
    }
  }

  // ──────────────────────────────────────────────
  //  SAKURA — cherry blossom branches, floating petals
  //  Character: delicate 5-petal flowers on angular branches, scattered petals
  // ──────────────────────────────────────────────
  void _paintSakura(Canvas canvas, Size size) {
    final rand = Random(seed);

    // Warm pink glow blobs
    _drawGlowBlobs(canvas, size, rand, count: 3, maxRadius: 160);

    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Angular branch from corner
    final branchCount = 1 + rand.nextInt(2);
    for (var b = 0; b < branchCount; b++) {
      _drawSakuraBranch(canvas, size, rand, inkPaint, fillPaint, b);
    }

    // Floating individual petals
    final petalCount = 8 + rand.nextInt(6);
    for (var i = 0; i < petalCount; i++) {
      final px = size.width * rand.nextDouble();
      final baseY = size.height * rand.nextDouble();
      final py = baseY + sin(animationValue * 2 * pi + i * 0.7) * 12;
      final rotation = animationValue * pi * 0.5 + i * 1.8;
      final petalSize = 5 + rand.nextDouble() * 8;
      _drawSakuraPetal(canvas, px, py, petalSize, rotation, fillPaint, inkPaint);
    }
  }

  void _drawSakuraBranch(Canvas canvas, Size size, Random rand, Paint stroke,
      Paint fill, int branchIndex) {
    // Branch starts from a corner and extends diagonally
    final fromLeft = branchIndex % 2 == 0;
    final startX = fromLeft ? -10.0 : size.width + 10;
    final startY = size.height * (0.1 + rand.nextDouble() * 0.3);
    final direction = fromLeft ? 1.0 : -1.0;

    final branchPaint = Paint()
      ..color = inkColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(startX, startY);

    var cx = startX;
    var cy = startY;
    final segments = 4 + rand.nextInt(3);

    for (var i = 0; i < segments; i++) {
      final segLen = 60 + rand.nextDouble() * 80;
      final nextCx = cx + direction * segLen * (0.6 + rand.nextDouble() * 0.4);
      final nextCy = cy + (rand.nextDouble() - 0.3) * 40;

      path.lineTo(nextCx, nextCy);

      // Place a 5-petal sakura flower at joints
      if (rand.nextDouble() > 0.2) {
        _drawSakuraFlower(canvas, nextCx, nextCy, 12 + rand.nextDouble() * 16,
            rand, fill, stroke);
      }

      // Sub-branches
      if (rand.nextDouble() > 0.5) {
        final subPath = Path();
        subPath.moveTo(nextCx, nextCy);
        final subAngle = direction * (0.3 + rand.nextDouble() * 0.8);
        final subLen = 30 + rand.nextDouble() * 40;
        final subEndX = nextCx + cos(subAngle) * subLen;
        final subEndY = nextCy - sin(subAngle.abs()) * subLen;
        subPath.lineTo(subEndX, subEndY);
        canvas.drawPath(subPath, branchPaint);

        if (rand.nextDouble() > 0.3) {
          _drawSakuraFlower(canvas, subEndX, subEndY,
              10 + rand.nextDouble() * 12, rand, fill, stroke);
        }
      }

      cx = nextCx;
      cy = nextCy;
    }

    canvas.drawPath(path, branchPaint);
  }

  void _drawSakuraFlower(Canvas canvas, double cx, double cy, double size,
      Random rand, Paint fill, Paint stroke) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rand.nextDouble() * 2 * pi);

    // 5 petals with notched tips (classic sakura)
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * pi;
      canvas.save();
      canvas.rotate(angle);

      final petal = Path();
      final petalLen = size;
      final petalW = size * 0.45;

      petal.moveTo(0, 0);
      petal.quadraticBezierTo(petalW, -petalLen * 0.6, petalW * 0.3, -petalLen);
      // Notch at tip
      petal.lineTo(0, -petalLen * 0.85);
      petal.lineTo(-petalW * 0.3, -petalLen);
      petal.quadraticBezierTo(-petalW, -petalLen * 0.6, 0, 0);

      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, stroke);

      canvas.restore();
    }

    // Center stamens — small lines
    for (var i = 0; i < 3; i++) {
      final angle = (i / 3) * 2 * pi + 0.3;
      final len = size * 0.3;
      canvas.drawLine(Offset.zero,
          Offset(cos(angle) * len, sin(angle) * len), stroke);
      canvas.drawCircle(
          Offset(cos(angle) * len, sin(angle) * len), 1.2, fill);
    }

    canvas.restore();
  }

  void _drawSakuraPetal(Canvas canvas, double cx, double cy, double size,
      double angle, Paint fill, Paint stroke) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    final petal = Path();
    petal.moveTo(0, -size);
    petal.quadraticBezierTo(size * 0.5, -size * 0.3, 0, size * 0.4);
    petal.quadraticBezierTo(-size * 0.5, -size * 0.3, 0, -size);
    petal.close();

    canvas.drawPath(petal, fill);
    canvas.drawPath(petal, stroke);

    canvas.restore();
  }

  // ──────────────────────────────────────────────
  //  MAPLE — pointed autumn leaves + golden shower cascades
  //  Character: angular star-shaped maple leaves, cascading golden clusters
  // ──────────────────────────────────────────────
  void _paintMaple(Canvas canvas, Size size) {
    final rand = Random(seed);

    // Warm amber glow blobs
    _drawGlowBlobs(canvas, size, rand, count: 2, maxRadius: 160);

    final inkPaint = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Floating maple leaves
    final leafCount = 5 + rand.nextInt(4);
    for (var i = 0; i < leafCount; i++) {
      final lx = size.width * rand.nextDouble();
      final baseY = size.height * rand.nextDouble();
      final ly = baseY + sin(animationValue * 2 * pi + i * 1.1) * 15;
      final rotation = animationValue * pi * 0.4 + i * 2.0;
      final leafSize = 15 + rand.nextDouble() * 25;
      _drawMapleLeaf(canvas, lx, ly, leafSize, rotation, fillPaint, inkPaint);
    }

    // Golden shower cascading clusters (like the yellow flower photo)
    final cascadeCount = 2 + rand.nextInt(2);
    for (var i = 0; i < cascadeCount; i++) {
      final startX = size.width * (0.2 + rand.nextDouble() * 0.6);
      final swayOffset = sin(animationValue * 2 * pi + i * 1.8) * 10;
      _drawGoldenCascade(canvas, startX + swayOffset, size, rand, inkPaint, fillPaint);
    }
  }

  void _drawMapleLeaf(Canvas canvas, double cx, double cy, double size,
      double angle, Paint fill, Paint stroke) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Classic 5-pointed maple leaf geometry
    final path = Path();
    final points = 5;

    for (var i = 0; i < points; i++) {
      final baseAngle = (i / points) * 2 * pi - pi / 2;
      final tipAngle = baseAngle;
      final leftAngle = baseAngle - 0.3;
      final rightAngle = baseAngle + 0.3;

      final tipR = size;
      final midR = size * 0.45;
      final baseR = size * 0.35;

      if (i == 0) {
        path.moveTo(cos(leftAngle) * baseR, sin(leftAngle) * baseR);
      }

      // Point outward
      path.lineTo(cos(leftAngle) * midR, sin(leftAngle) * midR);
      path.lineTo(cos(tipAngle) * tipR, sin(tipAngle) * tipR);
      path.lineTo(cos(rightAngle) * midR, sin(rightAngle) * midR);

      // Valley
      final nextBaseAngle = ((i + 1) / points) * 2 * pi - pi / 2 - 0.3;
      path.lineTo(cos(nextBaseAngle) * baseR, sin(nextBaseAngle) * baseR);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Center veins
    for (var i = 0; i < points; i++) {
      final angle = (i / points) * 2 * pi - pi / 2;
      final veinPaint = Paint()
        ..color = inkColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.4;
      canvas.drawLine(
          Offset.zero,
          Offset(cos(angle) * size * 0.7, sin(angle) * size * 0.7),
          veinPaint);
    }

    // Stem
    canvas.drawLine(
        Offset.zero,
        Offset(0, size * 1.2),
        stroke);

    canvas.restore();
  }

  void _drawGoldenCascade(Canvas canvas, double startX, Size size,
      Random rand, Paint stroke, Paint fill) {
    // Hanging cluster of small 4-petal flowers
    final vinePath = Path();
    vinePath.moveTo(startX, -5);

    var cx = startX;
    var cy = 0.0;
    final segments = 5 + rand.nextInt(4);

    for (var i = 0; i < segments; i++) {
      final nextCy = cy + 40 + rand.nextDouble() * 30;
      final drift = sin(animationValue * 2 * pi + i * 0.9) * 8;
      final nextCx = cx + (rand.nextDouble() - 0.5) * 20 + drift;

      vinePath.quadraticBezierTo(
          cx + (rand.nextDouble() - 0.5) * 15, (cy + nextCy) / 2,
          nextCx, nextCy);

      // Small 4-petal golden flowers along the cascade
      if (rand.nextDouble() > 0.2) {
        _drawSmallFlower(canvas, nextCx, nextCy, 4 + rand.nextDouble() * 4,
            rand, fill, stroke, 4);
      }

      cx = nextCx;
      cy = nextCy;
      if (cy > size.height * 0.7) break;
    }

    canvas.drawPath(vinePath, stroke);
  }

  void _drawSmallFlower(Canvas canvas, double cx, double cy, double size,
      Random rand, Paint fill, Paint stroke, int petals) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rand.nextDouble() * 2 * pi);

    for (var i = 0; i < petals; i++) {
      final angle = (i / petals) * 2 * pi;
      canvas.save();
      canvas.rotate(angle);

      final petal = Path();
      petal.moveTo(0, 0);
      petal.quadraticBezierTo(size * 0.4, -size * 0.5, 0, -size);
      petal.quadraticBezierTo(-size * 0.4, -size * 0.5, 0, 0);

      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, stroke);
      canvas.restore();
    }

    canvas.drawCircle(Offset.zero, size * 0.15, fill);
    canvas.restore();
  }

  // ──────────────────────────────────────────────
  //  SHARED UTILITIES
  // ──────────────────────────────────────────────

  /// Draws soft, gaussian-blurred organic blob shapes.
  void _drawGlowBlobs(Canvas canvas, Size size, Random rand,
      {int count = 3, double maxRadius = 150}) {
    final blobPaint = Paint()
      ..color = blobColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    for (var i = 0; i < count; i++) {
      final cx = size.width * (0.1 + rand.nextDouble() * 0.8);
      final cy = size.height * (0.1 + rand.nextDouble() * 0.8);
      final radius = 80.0 + rand.nextDouble() * (maxRadius - 80);

      // Animate blob positions subtly
      final drift = sin(animationValue * 2 * pi + i * 1.3) * 15;

      final path = Path();
      final points = 8;
      for (var j = 0; j < points; j++) {
        final angle = (j / points) * 2 * pi;
        final distortion = 0.6 + rand.nextDouble() * 0.4;
        final r = radius * distortion;

        final x = cx + cos(angle) * r + drift;
        final y = cy + sin(angle) * r;

        if (j == 0) {
          path.moveTo(x, y);
        } else {
          final prevAngle = ((j - 1) / points) * 2 * pi;
          final ctrlX = cx + cos((angle + prevAngle) / 2) * r * 1.15 + drift;
          final ctrlY = cy + sin((angle + prevAngle) / 2) * r * 1.15;
          path.quadraticBezierTo(ctrlX, ctrlY, x, y);
        }
      }
      path.close();
      canvas.drawPath(path, blobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BotanicalPainter oldDelegate) {
    return seed != oldDelegate.seed ||
        blobColor != oldDelegate.blobColor ||
        inkColor != oldDelegate.inkColor ||
        flowerType != oldDelegate.flowerType ||
        animationValue != oldDelegate.animationValue;
  }
}
