import 'package:flutter/material.dart';
import '../../../theme/delve_theme.dart';
import '../../../providers/delve_theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../widgets/delve_botanical_painter.dart';

class ThemePreviewScreen extends StatefulWidget {
  final DelveTheme previewTheme;

  const ThemePreviewScreen({super.key, required this.previewTheme});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = widget.previewTheme;

    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          // Animated botanical background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return RepaintBoundary(
                  child: CustomPaint(
                    painter: BotanicalPainter(
                      blobColor: theme.isDark
                          ? theme.accent.withValues(alpha: 0.05)
                          : theme.accent.withValues(alpha: 0.1),
                      inkColor: theme.botanicalInk.withValues(alpha: 0.5),
                      accentColor: theme.accentSecondary.withValues(alpha: 0.25),
                      seed: 123,
                      flowerType: theme.flowerType,
                      animationValue: _animController.value,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.cardBackground.withValues(alpha: 0.6),
                        ),
                        child: Icon(Icons.close, color: theme.text, size: 24),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const Spacer(),

                // Preview content
                Column(
                  children: [
                    // Flower type indicator
                    Text(
                      _flowerSubtitle(theme.flowerType),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sample word
                    Text(
                      'Ephemeral',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        theme.feel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.text.withValues(alpha: 0.5),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Apply button
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.read<DelveThemeProvider>().setTheme(theme);
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Apply ${theme.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
