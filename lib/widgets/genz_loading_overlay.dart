import 'dart:ui';
import 'package:flutter/material.dart';
import 'utopia_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class GenZLoadingOverlay extends StatefulWidget {
  const GenZLoadingOverlay({super.key});

  @override
  State<GenZLoadingOverlay> createState() => _GenZLoadingOverlayState();
}

class _GenZLoadingOverlayState extends State<GenZLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
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
            // ── Premium Blurred Backdrop ──
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.6) 
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),

            // ── Sleek Glassmorphism Content Card ──
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 0.95 + (_pulseController.value * 0.05);
                  final opacity = 0.8 + (_pulseController.value * 0.2);

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 240,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withValues(alpha: 0.4) 
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.08) 
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: U.primary.withValues(
                                alpha: isDark ? 0.15 : 0.08,
                              ),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Pulsing Ring & Utopia Loader ──
                            Container(
                              width: 64,
                              height: 64,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: U.primary.withValues(alpha: 0.05),
                                border: Border.all(
                                  color: U.primary.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: UtopiaLoader(
                                scale: 0.35,
                                color: U.primary,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Glowing Subtitle ──
                            Text(
                              'UTOPIA',
                              style: GoogleFonts.outfit(
                                color: U.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // ── Sleek Status Text ──
                            Text(
                              'Saving changes...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: U.text.withValues(alpha: 0.8),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
