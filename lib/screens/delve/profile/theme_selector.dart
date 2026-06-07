import 'package:flutter/material.dart';
import 'dart:math';
import '../../../theme/delve_theme.dart';
import '../../../theme/delve_themes.dart';
import '../../../providers/delve_theme_provider.dart';
import 'package:provider/provider.dart';
import 'theme_preview.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<DelveThemeProvider>();
    final isDark = themeProvider.currentTheme.isDark;

    final themes = isDark ? DelveThemes.darkThemes : DelveThemes.lightThemes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dark mode toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: themeProvider.currentTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeProvider.currentTheme.divider),
            ),
            child: SwitchListTile(
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  color: themeProvider.currentTheme.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                isDark ? 'Deep botanical tones' : 'Light botanical tones',
                style: TextStyle(
                  color: themeProvider.currentTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              activeTrackColor: themeProvider.currentTheme.accent,
              value: isDark,
              onChanged: (val) {
                themeProvider.toggleMode();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Flower label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Choose your flower',
            style: TextStyle(
              color: themeProvider.currentTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Theme grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final theme = themes[index];
            final isSelected = theme.name == themeProvider.currentTheme.name &&
                theme.isDark == themeProvider.currentTheme.isDark;

            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ThemePreviewScreen(previewTheme: theme),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? theme.accent : theme.divider,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.accent.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    children: [
                      // Mini botanical preview
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MiniFlowerPainter(
                            flowerType: theme.flowerType,
                            blobColor: theme.isDark
                                ? theme.accent.withValues(alpha: 0.06)
                                : theme.accent.withValues(alpha: 0.12),
                            inkColor: theme.botanicalInk.withValues(alpha: 0.5),
                            accentColor:
                                theme.accentSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),

                      // Content overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.background.withValues(alpha: 0.0),
                                theme.background.withValues(alpha: 0.85),
                                theme.background,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _flowerEmoji(theme.flowerType),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                theme.name,
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _flowerSubtitle(theme.flowerType),
                                style: TextStyle(
                                  color: theme.text.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Selected indicator
                      if (isSelected)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.accent,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color:
                                  theme.isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _flowerEmoji(FlowerType type) {
    switch (type) {
      case FlowerType.wisteria:
        return '🪻';
      case FlowerType.bauhinia:
        return '🌸';
      case FlowerType.sakura:
        return '🌺';
      case FlowerType.maple:
        return '🍁';
    }
  }

  String _flowerSubtitle(FlowerType type) {
    switch (type) {
      case FlowerType.wisteria:
        return 'Japanese Wisteria';
      case FlowerType.bauhinia:
        return 'Orchid Tree & Dandelion';
      case FlowerType.sakura:
        return 'Cherry Blossom';
      case FlowerType.maple:
        return 'Maple & Golden Shower';
    }
  }
}

/// Simplified mini painter for theme preview cards.
/// Draws a recognisable snippet of each flower type without animation.
class _MiniFlowerPainter extends CustomPainter {
  final FlowerType flowerType;
  final Color blobColor;
  final Color inkColor;
  final Color accentColor;

  _MiniFlowerPainter({
    required this.flowerType,
    required this.blobColor,
    required this.inkColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(flowerType.index * 42 + 7);

    // Background blob
    final blobPaint = Paint()
      ..color = blobColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(
        Offset(size.width * 0.65, size.height * 0.35),
        size.width * 0.35,
        blobPaint);

    final stroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    switch (flowerType) {
      case FlowerType.wisteria:
        // Mini hanging teardrops
        for (var i = 0; i < 3; i++) {
          final x = size.width * (0.3 + i * 0.2);
          final startY = size.height * 0.1;
          final path = Path();
          path.moveTo(x, startY);
          for (var j = 0; j < 4; j++) {
            final ty = startY + j * 18.0;
            _miniTeardrop(canvas, x + (rand.nextDouble() - 0.5) * 6, ty, 4, fill);
          }
          path.lineTo(x, startY + 70);
          canvas.drawPath(path, stroke);
        }
        break;

      case FlowerType.bauhinia:
        // Mini 5-petal flower
        final cx = size.width * 0.5;
        final cy = size.height * 0.4;
        for (var i = 0; i < 5; i++) {
          final angle = (i / 5) * 2 * pi;
          final petalPath = Path();
          final px = cx + cos(angle) * 20;
          final py = cy + sin(angle) * 20;
          petalPath.moveTo(cx, cy);
          petalPath.quadraticBezierTo(
              cx + cos(angle + 0.5) * 15, cy + sin(angle + 0.5) * 15, px, py);
          petalPath.quadraticBezierTo(
              cx + cos(angle - 0.5) * 15, cy + sin(angle - 0.5) * 15, cx, cy);
          canvas.drawPath(petalPath, fill);
          canvas.drawPath(petalPath, stroke);
        }
        // Wisp lines
        for (var i = 0; i < 5; i++) {
          final angle = (i / 5) * 2 * pi;
          canvas.drawLine(
            Offset(size.width * 0.7, size.height * 0.7),
            Offset(size.width * 0.7 + cos(angle) * 12,
                size.height * 0.7 + sin(angle) * 12),
            stroke,
          );
        }
        break;

      case FlowerType.sakura:
        // Mini branch with flowers
        final branchStroke = Paint()
          ..color = inkColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(-5, size.height * 0.3),
            Offset(size.width * 0.8, size.height * 0.25), branchStroke);
        // Mini blossoms
        for (var i = 0; i < 3; i++) {
          final fx = size.width * (0.2 + i * 0.25);
          final fy = size.height * (0.22 + (rand.nextDouble() - 0.5) * 0.1);
          for (var j = 0; j < 5; j++) {
            final angle = (j / 5) * 2 * pi;
            final pp = Path();
            pp.moveTo(fx, fy);
            pp.quadraticBezierTo(
                fx + cos(angle + 0.4) * 6,
                fy + sin(angle + 0.4) * 6,
                fx + cos(angle) * 8,
                fy + sin(angle) * 8);
            pp.quadraticBezierTo(
                fx + cos(angle - 0.4) * 6,
                fy + sin(angle - 0.4) * 6,
                fx, fy);
            canvas.drawPath(pp, fill);
            canvas.drawPath(pp, stroke);
          }
        }
        // Falling petals
        for (var i = 0; i < 4; i++) {
          _miniTeardrop(canvas, size.width * rand.nextDouble(),
              size.height * (0.4 + rand.nextDouble() * 0.4), 3, fill);
        }
        break;

      case FlowerType.maple:
        // Mini maple leaves
        for (var i = 0; i < 3; i++) {
          final lx = size.width * (0.2 + i * 0.3);
          final ly = size.height * (0.25 + rand.nextDouble() * 0.3);
          _miniMapleLeaf(canvas, lx, ly, 10, fill, stroke, i.toDouble());
        }
        // Mini cascade
        final cascadePath = Path();
        cascadePath.moveTo(size.width * 0.6, size.height * 0.1);
        cascadePath.quadraticBezierTo(size.width * 0.65, size.height * 0.4,
            size.width * 0.55, size.height * 0.7);
        canvas.drawPath(cascadePath, stroke);
        break;
    }
  }

  void _miniTeardrop(Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path();
    path.moveTo(cx, cy - s);
    path.quadraticBezierTo(cx + s * 0.5, cy, cx, cy + s * 0.4);
    path.quadraticBezierTo(cx - s * 0.5, cy, cx, cy - s);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _miniMapleLeaf(Canvas canvas, double cx, double cy, double size,
      Paint fill, Paint stroke, double rotation) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation * 0.7);

    final path = Path();
    for (var i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * pi - pi / 2;
      final tipR = size;
      final midR = size * 0.45;

      final tipX = cos(angle) * tipR;
      final tipY = sin(angle) * tipR;
      final leftX = cos(angle - 0.3) * midR;
      final leftY = sin(angle - 0.3) * midR;
      final rightX = cos(angle + 0.3) * midR;
      final rightY = sin(angle + 0.3) * midR;

      if (i == 0) path.moveTo(leftX, leftY);
      path.lineTo(leftX, leftY);
      path.lineTo(tipX, tipY);
      path.lineTo(rightX, rightY);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniFlowerPainter old) =>
      flowerType != old.flowerType ||
      blobColor != old.blobColor ||
      inkColor != old.inkColor;
}
