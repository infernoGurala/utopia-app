import 'package:flutter/material.dart';

/// A sophisticated, pulsating unread notification dot with a subtle glowing aura.
class UnreadIndicatorDot extends StatefulWidget {
  final double size;
  final Color color;
  final Color? glowColor;
  final bool animate;

  const UnreadIndicatorDot({
    super.key,
    this.size = 9.0,
    this.color = const Color(0xFF2DD4BF), // U.teal
    this.glowColor,
    this.animate = true,
  });

  @override
  State<UnreadIndicatorDot> createState() => _UnreadIndicatorDotState();
}

class _UnreadIndicatorDotState extends State<UnreadIndicatorDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant UnreadIndicatorDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = widget.glowColor ?? widget.color;

    if (!widget.animate) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: effectiveGlowColor.withValues(alpha: 0.6),
              blurRadius: widget.size * 0.8,
              spreadRadius: widget.size * 0.2,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: effectiveGlowColor.withValues(
                    alpha: _glowAnimation.value.clamp(0.0, 1.0),
                  ),
                  blurRadius: widget.size * 1.1,
                  spreadRadius: widget.size * 0.35,
                ),
                BoxShadow(
                  color: effectiveGlowColor.withValues(alpha: 0.3),
                  blurRadius: widget.size * 2.0,
                  spreadRadius: widget.size * 0.7,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
