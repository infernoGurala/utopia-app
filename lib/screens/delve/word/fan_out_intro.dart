import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/delve_theme_provider.dart';
import '../../../theme/delve_theme.dart';
import '../../../models/delve_word_model.dart';

class FanOutIntro extends StatefulWidget {
  final List<Word> words;
  final VoidCallback onComplete;

  const FanOutIntro({
    super.key,
    required this.words,
    required this.onComplete,
  });

  @override
  State<FanOutIntro> createState() => _FanOutIntroState();
}

class _FanOutIntroState extends State<FanOutIntro> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _exitController;
  late Animation<double> _fanAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _spreadAnimation;
  
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initial pop and rotation
    _fanAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    // Spreading logic: starts after the pop
    _spreadAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Auto-complete after 5 seconds
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted && !_isExiting) {
        _fadeOutAndComplete();
      }
    });
  }

  void _fadeOutAndComplete() {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    
    _exitController.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DelveThemeProvider>(context).currentTheme;
    final words = widget.words;
    final int count = words.length;

    return GestureDetector(
      onTap: _fadeOutAndComplete,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.2), // Dim the background slightly for focus
        width: double.infinity,
        height: double.infinity,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fan out cards
              for (int i = 0; i < count; i++)
                AnimatedBuilder(
                  animation: Listenable.merge([_controller, _exitController]),
                  builder: (context, child) {
                    final double spread = _spreadAnimation.value;
                    final double exitValue = _exitController.value;
                    
                    // Arc calculation: slightly wider for a more natural feel
                    final double maxArc = count > 10 ? math.pi / 1.6 : math.pi / 2.2;
                    final double angle = (i - (count - 1) / 2) * (maxArc / (count - 1));
                    
                    final double rotation = angle * spread;
                    
                    // Radius and translation: middle ground to avoid clipping while staying 'relaxed'
                    final double radius = count > 10 ? 220 : 180;
                    final double translationY = -radius * spread * math.cos(angle).abs();
                    final double translationX = radius * 1.3 * spread * math.sin(angle);

                    // Exit transforms: Fly up, scale up slightly, fade out
                    final double exitY = -120 * exitValue;
                    final double exitScale = 1.0 + (0.1 * exitValue);
                    final double exitOpacity = (1.0 - exitValue).clamp(0.0, 1.0);

                    // Stack effect when not spread: subtle vertical offset for "stack" look
                    final double stackOffset = (count - 1 - i) * 2.0 * (1.0 - spread);

                    return Opacity(
                      opacity: _fadeAnimation.value * exitOpacity,
                      child: Transform.translate(
                        offset: Offset(translationX, translationY + 80 + stackOffset + exitY),
                        child: Transform.rotate(
                          angle: rotation,
                          child: Transform.scale(
                            scale: _fanAnimation.value * exitScale,
                            child: _IntroCard(
                              word: words[i].word,
                              theme: theme,
                              isSmall: count > 10,
                              spread: spread,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              
              // Text Overlays
              Positioned(
                bottom: 100,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_controller, _exitController]),
                  builder: (context, child) {
                    final double exitValue = _exitController.value;
                    return Opacity(
                      opacity: _fadeAnimation.value * (1.0 - exitValue),
                      child: Transform.translate(
                        offset: Offset(0, 40 * exitValue),
                        child: Column(
                          children: [
                            Text(
                              'THE DAILY DEEP',
                              style: GoogleFonts.inter(
                                color: theme.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Ready to delve?',
                              style: GoogleFonts.playfairDisplay(
                                color: theme.text,
                                fontSize: 32,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Progress dots or indicator
                            Row(
                              children: List.generate(3, (i) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.accent.withValues(alpha: 0.3),
                                ),
                              )),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final String word;
  final DelveTheme theme;
  final bool isSmall;
  final double spread;

  const _IntroCard({
    required this.word,
    required this.theme,
    required this.isSmall,
    required this.spread,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic shadow opacity to prevent 'black blob' when stacked
    final double shadowAlpha = 0.15 * spread;
    final double glowAlpha = (theme.isDark ? 0.04 : 0.02) * spread;

    return Container(
      width: isSmall ? 110 : 140,
      height: isSmall ? 170 : 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.isDark 
                ? theme.cardBackground.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.8),
            theme.isDark
                ? theme.cardBackground.withValues(alpha: 0.4)
                : theme.cardBackground.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.accent.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          // Foundation shadow - intensity linked to spread
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowAlpha),
            blurRadius: 40,
            offset: Offset(0, 15 * spread),
            spreadRadius: -10 * spread,
          ),
          // Soft ambient glow - intensity linked to spread
          BoxShadow(
            color: theme.accent.withValues(alpha: glowAlpha),
            blurRadius: 60 * spread,
            spreadRadius: 2 * spread,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            children: [
              // Subtle corner glow
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.accent.withValues(alpha: theme.isDark ? 0.08 : 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minimalist icon/mark
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accent.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      word,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.marcellus(
                        color: theme.text,
                        fontSize: isSmall ? 15 : 18,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
