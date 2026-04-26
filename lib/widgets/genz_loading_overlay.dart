import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';

class GenZLoadingOverlay extends StatefulWidget {
  const GenZLoadingOverlay({super.key});

  @override
  State<GenZLoadingOverlay> createState() => _GenZLoadingOverlayState();
}

class _FloatingEmoji {
  String emoji;
  double x;
  double y;
  double size;
  double speed;
  double angle;
  double opacity;

  _FloatingEmoji({
    required this.emoji,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.angle,
    required this.opacity,
  });
}

class _GenZLoadingOverlayState extends State<GenZLoadingOverlay>
    with TickerProviderStateMixin {
  static const _funnyTexts = [
    'Loading… brain buffering too',
    'One sec, vibes syncing',
    'Hold up, cooking something',
    'Loading… don\'t panic yet',
    'Just vibing, almost ready',
    'System doing its thing',
    'Chill, it\'s not frozen',
    'Loading… trust issues incoming',
    'Almost there, promise bro',
    'Fixing bugs (not insects)',
    'Making it less cringe',
    'Loading… dramatic pause moment',
    'Wait… that felt faster',
    'Still loading, stay hydrated',
    'Don\'t click anything please',
    'Loading… no thoughts head empty',
    'Doing magic behind scenes',
    'Just a tiny existential delay',
    'Loading… patience skill unlocked',
    'We got this, relax',
  ];

  static const _emojis = [
    '🔥', '✨', '💫', '⚡', '🎯', '🚀', '💎', '🌊', '🎪', '🦋',
    '🌈', '💜', '🔮', '⭐', '🎉', '🦄',
  ];

  static const _gradients = [
    [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
    [Color(0xFFF59E0B), Color(0xFFEC4899)],
    [Color(0xFF10B981), Color(0xFF3B82F6)],
    [Color(0xFFEF4444), Color(0xFFF97316)],
  ];

  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _textController;
  late final AnimationController _shimmerController;

  late String _currentText;
  late List<Color> _currentGradient;
  final List<_FloatingEmoji> _floatingEmojis = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _currentText = _funnyTexts[_rng.nextInt(_funnyTexts.length)];
    _currentGradient = _gradients[_rng.nextInt(_gradients.length)];

    // Spawn floating emojis
    for (int i = 0; i < 12; i++) {
      _floatingEmojis.add(_FloatingEmoji(
        emoji: _emojis[_rng.nextInt(_emojis.length)],
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 18 + _rng.nextDouble() * 24,
        speed: 0.003 + _rng.nextDouble() * 0.005,
        angle: _rng.nextDouble() * 2 * pi,
        opacity: 0.4 + _rng.nextDouble() * 0.5,
      ));
    }

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Cycle text every 2.5s
    _scheduleTextCycle();
  }

  void _scheduleTextCycle() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _textController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentText = _funnyTexts[_rng.nextInt(_funnyTexts.length)];
          _currentGradient = _gradients[_rng.nextInt(_gradients.length)];
        });
        _textController.forward();
        _scheduleTextCycle();
      });
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _floatController,
            _pulseController,
            _shimmerController,
          ]),
          builder: (context, _) {
            final t = _floatController.value;
            final pulse = _pulseController.value;
            final shimmer = _shimmerController.value;

            return Stack(
              children: [
                // ── Blurred dark backdrop ──
                Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),

                // ── Floating emojis ──
                ..._floatingEmojis.map((e) {
                  final dx = sin(t * 2 * pi * e.speed * 200 + e.angle) * 0.08;
                  final dy = cos(t * 2 * pi * e.speed * 150 + e.angle) * 0.06;
                  final screenW = MediaQuery.of(context).size.width;
                  final screenH = MediaQuery.of(context).size.height;
                  return Positioned(
                    left: (e.x + dx) * screenW,
                    top: (e.y + dy) * screenH,
                    child: Opacity(
                      opacity: e.opacity,
                      child: Text(
                        e.emoji,
                        style: TextStyle(fontSize: e.size),
                      ),
                    ),
                  );
                }),

                // ── Center card ──
                Center(
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _currentGradient[0].withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Animated spinner ──
                        Transform.scale(
                          scale: 0.92 + pulse * 0.12,
                          child: Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  _currentGradient[0].withValues(alpha: 0.15),
                                  _currentGradient[1].withValues(alpha: 0.15),
                                ],
                              ),
                              border: Border.all(
                                color: _currentGradient[0].withValues(
                                  alpha: 0.4 + pulse * 0.4,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _currentGradient[0].withValues(
                                    alpha: 0.3 + pulse * 0.2,
                                  ),
                                  blurRadius: 20 + pulse * 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              strokeCap: StrokeCap.round,
                              valueColor: AlwaysStoppedAnimation(
                                Color.lerp(
                                  _currentGradient[0],
                                  _currentGradient[1],
                                  shimmer,
                                )!,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Gradient label ──
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: _currentGradient,
                            begin: Alignment(
                              -1.0 + shimmer * 2.0,
                              0,
                            ),
                            end: Alignment(
                              -0.2 + shimmer * 2.0,
                              0,
                            ),
                          ).createShader(bounds),
                          child: Text(
                            'UTOPIA',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── Cycling fun text ──
                        AnimatedBuilder(
                          animation: _textController,
                          builder: (ctx, _) => Opacity(
                            opacity: _textController.value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - _textController.value) * 8),
                              child: Text(
                                _currentText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Shimmer progress bar ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 3,
                            width: double.infinity,
                            color: Colors.white.withValues(alpha: 0.1),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1.0,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [..._currentGradient, ..._currentGradient],
                                  stops: const [0.0, 0.4, 0.6, 1.0],
                                  begin: Alignment(-1.0 + shimmer * 2.5, 0),
                                  end: Alignment(0.5 + shimmer * 2.5, 0),
                                  tileMode: TileMode.mirror,
                                ).createShader(bounds),
                                child: Container(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
