import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/delve_word_model.dart';
import '../../../providers/delve_theme_provider.dart';
import '../../../theme/delve_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

class SwipeCard extends StatefulWidget {
  final Word word;
  final VoidCallback onDismissed;
  final VoidCallback? onComplete; // Triggered immediately on success

  const SwipeCard({
    super.key,
    required this.word,
    required this.onDismissed,
    this.onComplete,
  });

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> with TickerProviderStateMixin {
  bool _canFlip = false;
  bool _isFlipped = false;
  int _frontTimerSeconds = 3;
  Timer? _frontTimer;

  int _backTimerSeconds = 0;
  Timer? _backTimer;
  bool _isReadingDone = false;
  bool _isTypingDone = false;

  late final TraceEditingController _wordController;
  late final TraceEditingController _meaningController;
  final FocusNode _wordFocus = FocusNode();
  final FocusNode _meaningFocus = FocusNode();

  double _dismissProgress = 0.0;

  // Entrance animation
  late final AnimationController _entranceController;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  @override
  void initState() {
    super.initState();
    _startFrontTimer();

    _wordController = TraceEditingController(targetText: widget.word.word);
    _meaningController = TraceEditingController(targetText: widget.word.meaning);

    _wordController.addListener(_checkTyping);
    _meaningController.addListener(_checkTyping);

    _backTimerSeconds = _calculateTotalReadTimeSeconds(widget.word.meaning);

    // Entrance — Physics-based Pop
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _entranceScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController, 
        curve: Curves.elasticOut,
      ),
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _entranceController, 
          curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _entranceController.forward();
  }

  int _calculateTotalReadTimeSeconds(String text) {
    final words = text.split(RegExp(r'\s+'));
    int totalMs = 0;
    for (var word in words) {
      final lengthFactor = (word.length / 5.0).clamp(0.7, 1.8);
      final punctuationDelay = word.contains(RegExp(r'[.,;:!?]')) ? 180 : 0;
      totalMs += (260 * lengthFactor).round() + punctuationDelay;
    }
    // Each cycle = 300ms initial + read time + 1500ms pause + 500ms delay.
    // So approximately read time + 2000ms.
    int cycleMs = totalMs + 2000;
    int total3CyclesMs = cycleMs * 3;
    return (total3CyclesMs / 1000).ceil();
  }

  void _startFrontTimer() {
    _frontTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_frontTimerSeconds > 1) {
          _frontTimerSeconds--;
        } else {
          _canFlip = true;
          _frontTimer?.cancel();
        }
      });
    });
  }

  void _startBackTimer() {
    _backTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_backTimerSeconds > 1) {
          _backTimerSeconds--;
        } else {
          _isReadingDone = true;
          _backTimerSeconds = 0;
          _backTimer?.cancel();
        }
      });
    });
  }

  void _checkTyping() {
    final w1 = _wordController.text.trim().toLowerCase();
    final w2 = widget.word.word.trim().toLowerCase();

    // 1. Auto-focus transition: If word is correct and we are on word field, move to meaning
    if (w1 == w2 && _wordFocus.hasFocus) {
      _meaningFocus.requestFocus();
    }

    final m1 = _meaningController.text.trim().toLowerCase();
    final m2 = widget.word.meaning.trim().toLowerCase();

    if (w1 == w2 && m1 == m2) {
      if (!_isTypingDone) {
        setState(() {
          _isTypingDone = true;
        });
        _wordFocus.unfocus();
        _meaningFocus.unfocus();

        // 2. Auto-submit with a "cool" delay and animation
        widget.onComplete?.call(); // Tell screen to start leaves NOW
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isTypingDone) {
            // Trigger dismissal
            _autoDismiss();
          }
        });
      }
    } else {
      if (_isTypingDone) {
        setState(() {
          _isTypingDone = false;
        });
      }
    }
  }

  void _autoDismiss() {
    // We no longer reverse the animation here because the Leaf Transition
    // handles the "vanishing" by swapping the card at the midpoint.
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _frontTimer?.cancel();
    _backTimer?.cancel();
    _wordController.dispose();
    _meaningController.dispose();
    _wordFocus.dispose();
    _meaningFocus.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (!_isFlipped) {
      if (_canFlip) {
        setState(() {
          _isFlipped = true;
        });
        _startBackTimer();
      }
    } else if (_isTypingDone) {
      // Allow flipping back only when typing is done
      setState(() {
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.word.id),
      direction: _isTypingDone ? DismissDirection.up : DismissDirection.none,
      onDismissed: (_) => widget.onDismissed(),
      onUpdate: (details) {
        if (mounted) {
          setState(() {
            _dismissProgress = details.progress;
          });
        }
      },
      child: AnimatedBuilder(
        animation: _entranceController,
        builder: (context, child) {
          final revealProgress = _entranceController.value;
          final exitProgress = 1.0 - revealProgress;
          
          // Physics-based Pop In/Out
          final double popScale = _entranceController.status == AnimationStatus.reverse
              ? revealProgress // Linear shrink on exit
              : Curves.elasticOut.transform(revealProgress); // Elastic pop on entrance
          
          return Transform.translate(
            offset: Offset(0, -(_dismissProgress * 400)), // Swipe up
            child: Transform.scale(
              scale: (1.0 - (_dismissProgress * 0.5)) * popScale,
              child: Opacity(
                opacity: (1.0 - (_dismissProgress * 2.0)).clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: GestureDetector(
          onTap: _flipCard,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOutCubic, // Smoother for longer duration
            tween: Tween<double>(begin: 0, end: _isFlipped ? pi : 0),
            builder: (context, double val, child) {
              bool isUnder = val > pi / 2;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective (matches 900px approx)
                  ..rotateY(val)
                  ..rotateZ(val), // Rotation on both Y and Z axes
                child: isUnder
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..rotateY(pi)
                          ..rotateZ(pi), // Compensate for card rotation
                        child: _buildFace(isBack: true),
                      )
                    : _buildFace(isBack: false),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTypingUI(DelveTheme theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Type exactly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _buildTraceField(
            controller: _wordController,
            focusNode: _wordFocus,
            theme: theme,
            isLarge: true,
          ),
          const SizedBox(height: 12),
          _buildTraceField(
            controller: _meaningController,
            focusNode: _meaningFocus,
            theme: theme,
            isLarge: false,
          ),
        ],
      ),
    );
  }

  Widget _buildTraceField({
    required TraceEditingController controller,
    required FocusNode focusNode,
    required DelveTheme theme,
    required bool isLarge,
  }) {
    final textStyle = TextStyle(
      color: theme.text,
      fontSize: isLarge ? 24 : 16,
      fontWeight: isLarge ? FontWeight.bold : FontWeight.w500,
      height: 1.3,
    );

    final hintStyle = textStyle.copyWith(
      color: theme.textSecondary.withValues(alpha: 0.25),
    );

    controller.activeStyle = textStyle;
    controller.hintStyle = hintStyle;

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final hasFocus = focusNode.hasFocus;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: textStyle,
          maxLines: isLarge ? 1 : null,
          minLines: isLarge ? 1 : null,
          textInputAction: isLarge ? TextInputAction.next : TextInputAction.done,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.accent.withValues(alpha: 0.5), width: 1.5),
            ),
            filled: true,
            fillColor: theme.isDark ? Colors.black12 : Colors.white12,
          ),
        );
      },
    );
  }

  Widget _buildFace({required bool isBack}) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return Container(
      width: double.infinity,
      height: 440,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        // Glassmorphism-inspired card
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDark
              ? [
                  theme.cardBackground.withValues(alpha: 0.95),
                  theme.cardBackground.withValues(alpha: 0.85),
                ]
              : [
                  theme.cardBackground.withValues(alpha: 0.98),
                  Color.lerp(theme.cardBackground, theme.accent, 0.05)!
                      .withValues(alpha: 0.95),
                ],
          stops: const [0.2, 1.0],
        ),
        border: Border.all(
          color: theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : theme.accent.withValues(alpha: 0.12),
          width: 1.2,
        ),
        boxShadow: [
          // Deep foundation shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 20),
            spreadRadius: -10,
          ),
          // Soft ambient glow
          BoxShadow(
            color: theme.accent.withValues(alpha: theme.isDark ? 0.04 : 0.02),
            blurRadius: 60,
            spreadRadius: 2,
          ),
          // Specular highlights
          BoxShadow(
            color: Colors.white.withValues(alpha: theme.isDark ? 0.05 : 0.2),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Stack(
            children: [
          // Subtle accent glow at top-right corner
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.accent.withValues(alpha: theme.isDark ? 0.06 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: isBack
                  ? _isReadingDone
                      ? _buildTypingUI(theme)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LyricGlowText(
                              text: widget.word.meaning,
                              style: TextStyle(
                                color: theme.text.withValues(alpha: 0.3),
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                              glowColor: theme.text,
                              accentColor: theme.accent,
                            ),
                            const SizedBox(height: 32),
                            Text(
                              '${widget.word.word.toLowerCase()} (${widget.word.partOfSpeech ?? "unknown"})',
                              style: TextStyle(
                                color: theme.textSecondary
                                    .withValues(alpha: 0.4),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.word.word,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bodoniModa(
                            color: theme.text,
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (widget.word.partOfSpeech != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.word.partOfSpeech!,
                            style: TextStyle(
                              color: theme.accent.withValues(alpha: 0.8),
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          // Bottom indicator
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Center(
              child: isBack
                  ? _isTypingDone
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_upward_rounded,
                                color: theme.accent.withValues(alpha: 0.6),
                                size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Swipe up to dismiss',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 13,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : _isReadingDone
                          ? Text(
                              'Type exactly to continue',
                              style: TextStyle(
                                color: theme.textSecondary
                                    .withValues(alpha: 0.6),
                                fontSize: 13,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : Text(
                              'Wait $_backTimerSeconds sec...',
                              style: TextStyle(
                                color: theme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                  : (!_canFlip)
                      ? Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.accent.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_frontTimerSeconds',
                              style: TextStyle(
                                color: theme.accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          'Tap to reveal',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

/// Apple Music lyric-style reading glow.
/// Words light up one by one at natural reading pace (200–250 WPM).
class _LyricGlowText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color glowColor;
  final Color accentColor;

  const _LyricGlowText({
    required this.text,
    required this.style,
    required this.glowColor,
    required this.accentColor,
  });

  @override
  State<_LyricGlowText> createState() => _LyricGlowTextState();
}

class _LyricGlowTextState extends State<_LyricGlowText>
    with SingleTickerProviderStateMixin {
  late final List<String> _words;
  late final AnimationController _controller;
  int _currentWordIndex = -1;
  Timer? _wordTimer;

  // ~220 WPM = ~273ms per word, with variance for word length
  static const _baseMs = 260;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(RegExp(r'\s+'));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Start the reading flow after a brief delay
    Future.delayed(const Duration(milliseconds: 300), _startReading);
  }

  void _startReading() {
    _advanceWord();
  }

  void _advanceWord() {
    if (!mounted) return;
    setState(() {
      _currentWordIndex++;
    });

    if (_currentWordIndex >= _words.length) {
      // Loop back after a pause
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _currentWordIndex = -1);
          Future.delayed(const Duration(milliseconds: 500), _startReading);
        }
      });
      return;
    }

    // Calculate delay based on word length (longer words get more time)
    final word = _words[_currentWordIndex];
    final lengthFactor = (word.length / 5.0).clamp(0.7, 1.8);
    // Add extra time for words after punctuation
    final hasPunctuation = word.contains(RegExp(r'[.,;:!?]'));
    final punctuationDelay = hasPunctuation ? 180 : 0;

    final delay = (_baseMs * lengthFactor).round() + punctuationDelay;

    _wordTimer?.cancel();
    _wordTimer = Timer(Duration(milliseconds: delay), _advanceWord);
  }

  @override
  void dispose() {
    _wordTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;
    final bool isDark = theme.isDark;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6.0,
      runSpacing: 4.0,
      children: List.generate(_words.length, (i) {
        final isActive = i == _currentWordIndex;
        final isPast = i < _currentWordIndex;

        return AnimatedScale(
          scale: isActive ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: isActive ? const Offset(0, -0.05) : Offset.zero,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              style: widget.style.copyWith(
                color: isActive
                    ? widget.glowColor
                    : isPast
                        ? widget.glowColor.withValues(alpha: isDark ? 0.7 : 0.5)
                        : widget.style.color,
                shadows: (isActive && isDark)
                    ? [
                        Shadow(
                          color: widget.accentColor.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                        Shadow(
                          color: widget.glowColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
              child: Text(_words[i]),
            ),
          ),
        );
      }),
    );
  }
}

class TraceEditingController extends TextEditingController {
  final String targetText;
  TextStyle? activeStyle;
  TextStyle? hintStyle;

  TraceEditingController({required this.targetText});

  @override
  set value(TextEditingValue newValue) {
    String newText = newValue.text;
    
    // 3. Auto-spacing logic
    if (newText.length > text.length) {
      // User added a character
      int lastIdx = newText.length - 1;
      
      // If we are at a position that SHOULD be a space in target, 
      // but the user typed something else, auto-inject the space.
      if (lastIdx < targetText.length && 
          targetText[lastIdx] == ' ' && 
          newText[lastIdx] != ' ') {
        
        final typedChar = newText[lastIdx];
        newText = text + ' ' + typedChar;
        
        newValue = newValue.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }

    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final tStyle = activeStyle ?? style ?? const TextStyle();
    final hStyle = hintStyle ?? style ?? const TextStyle();

    List<TextSpan> spans = [];

    for (int i = 0; i < text.length; i++) {
      if (i < targetText.length) {
        if (text[i].toLowerCase() == targetText[i].toLowerCase()) {
          spans.add(TextSpan(text: targetText[i], style: tStyle));
        } else {
          spans.add(TextSpan(
            text: text[i],
            style: tStyle.copyWith(
                color: Colors.redAccent, decoration: TextDecoration.underline),
          ));
        }
      } else {
        spans.add(
            TextSpan(text: text[i], style: tStyle.copyWith(color: Colors.redAccent)));
      }
    }

    if (text.length < targetText.length) {
      spans.add(
          TextSpan(text: targetText.substring(text.length), style: hStyle));
    }

    return TextSpan(style: style, children: spans);
  }
}
