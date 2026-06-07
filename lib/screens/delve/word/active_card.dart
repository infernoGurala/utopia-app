import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/delve_word_model.dart';
import '../../../providers/delve_theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../services/delve_groq_service.dart';

class ActiveCard extends StatefulWidget {
  final Word word;
  final ValueChanged<bool> onSubmit;

  const ActiveCard({
    super.key,
    required this.word,
    required this.onSubmit,
  });

  @override
  State<ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<ActiveCard> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final GroqService _groqService = GroqService();
  bool _isChecking = false;
  bool? _resultPass;

  // Entrance & Exit animations
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -1.5),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _animationController.forward();
  }

  void _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    
    setState(() => _isChecking = true);
    
    final pass = await _groqService.validateMeaning(widget.word.word, widget.word.meaning, input);
    
    if (mounted) {
      setState(() {
        _isChecking = false;
        _resultPass = pass;
      });
    }
  }

  void _continue() {
    if (_resultPass != null) {
      // Trigger exit animation
      _animationController.animateTo(1.0, duration: const Duration(milliseconds: 400)).then((_) {
        if (mounted) {
          widget.onSubmit(_resultPass!);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // We use the same controller but different segments for entrance and exit
        // Entrance is handled by forward() and curves
        // Exit is handled by _continue() animating to 1.0 with different curves/offsets
        
        return SlideTransition(
          position: _offsetAnimation,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(
                widget.word.word,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.word.partOfSpeech != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.word.partOfSpeech!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.accent.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              if (_resultPass == null) ...[
                TextField(
                  controller: _controller,
                  style: TextStyle(color: theme.text, fontSize: 18),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'What does this mean?',
                    hintStyle: TextStyle(color: theme.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.isDark
                            ? theme.accent.withValues(alpha: 0.15)
                            : theme.divider,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.accent, width: 2),
                    ),
                    filled: true,
                    fillColor: theme.isDark
                        ? theme.background.withValues(alpha: 0.5)
                        : theme.background,
                  ),
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isChecking ? null : _submit,
                child: _isChecking 
                  ? SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        color: theme.isDark ? Colors.black : Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              // Result state
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _resultPass!
                            ? const Color(0xFF2DD4A0).withValues(alpha: 0.15)
                            : const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        _resultPass! ? Icons.check_rounded : Icons.close_rounded,
                        color: _resultPass!
                            ? const Color(0xFF2DD4A0)
                            : const Color(0xFFFF6B6B),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _resultPass! ? 'Spot on.' : 'Not quite.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_resultPass!) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.word.meaning,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 16,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: theme.isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _continue,
                      child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
),
);
  }
}
