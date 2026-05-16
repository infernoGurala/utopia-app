import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scrollAnimation;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scrollAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.1, 0.6, 0.9, 0.4),
    );

    _wobbleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.5, 0.8, 0.5, 0.2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double mainSize = 40 * widget.scale;
    final Color textColor = widget.color ?? U.primary;
    final Color shadowColor = textColor.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: mainSize * 1.825,
          height: mainSize * 0.25,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildSlice(1, 0.0, 0.1111, 20, -2.1, 0.6, mainSize, textColor, shadowColor),
              _buildSlice(2, 0.1111, 0.2222, 16, -0.98, 0.7, mainSize, textColor, shadowColor),
              _buildSlice(3, 0.2222, 0.3333, 13, -0.33, 0.8, mainSize, textColor, shadowColor),
              _buildSlice(4, 0.3333, 0.4444, 11, -0.05, 0.9, mainSize, textColor, shadowColor),
              _buildSlice(5, 0.4444, 0.5555, 10, 0.0, 1.0, mainSize, textColor, shadowColor),
              _buildSlice(6, 0.5555, 0.6666, 11, 0.05, 0.9, mainSize, textColor, shadowColor),
              _buildSlice(7, 0.6666, 0.7777, 13, 0.33, 0.8, mainSize, textColor, shadowColor),
              _buildSlice(8, 0.7777, 0.8888, 16, 0.98, 0.7, mainSize, textColor, shadowColor),
              _buildSlice(9, 0.8888, 1.0, 20, 2.1, 0.6, mainSize, textColor, shadowColor),
            ],
          ),
        ),
        const SizedBox(height: 2), 
        Container(
          height: mainSize * 0.0125, 
          width: mainSize * 0.125, 
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(mainSize * 0.0125),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _wobbleAnimation,
            builder: (context, child) {
              final double t = _wobbleAnimation.value;
              final double x = (t <= 0.5) 
                  ? (-0.9 + (t * 2) * 1.8) 
                  : (0.9 - (t - 0.5) * 2 * 1.8); 
              
              return FractionallySizedBox(
                alignment: Alignment(x, 0),
                widthFactor: 1.0,
                child: Container(
                  color: textColor,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSlice(
    int index,
    double start,
    double end,
    double divisor,
    double marginLeftEm,
    double opacity,
    double mainSize,
    Color textColor,
    Color shadowColor,
  ) {
    final double fontSize = mainSize / (divisor / 4);
    final double marginLeft = marginLeftEm * (mainSize / 4);

    return Positioned(
      left: (mainSize * 0.9125) + marginLeft - (mainSize * 0.5), 
      child: Opacity(
        opacity: opacity,
        child: ClipRect(
          clipper: _SliceClipper(start, end),
          child: AnimatedBuilder(
            animation: _scrollAnimation,
            builder: (context, child) {
              final double scrollPos = _scrollAnimation.value;
              final double offset = (scrollPos * 2 - 1) * mainSize * 0.5;

              return Transform.translate(
                offset: Offset(offset, 0),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return _getGradient(index, textColor, shadowColor, scrollPos).createShader(bounds);
                  },
                  child: Text(
                    'LOADING',
                    style: GoogleFonts.outfit(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradient(int index, Color text, Color shadow, double t) {
    final double shift = -0.98 + (t * 2.0); 
    double s1, s2;
    bool invert = false;

    switch (index) {
      case 1: s1 = 0.04; s2 = 0.07; break;
      case 2: s1 = 0.09; s2 = 0.13; break;
      case 3: s1 = 0.15; s2 = 0.18; break;
      case 4: s1 = 0.20; s2 = 0.23; break;
      case 5: return LinearGradient(colors: [text, text]);
      case 6: s1 = 0.29; s2 = 0.32; invert = true; break;
      case 7: s1 = 0.34; s2 = 0.37; invert = true; break;
      case 8: s1 = 0.39; s2 = 0.42; invert = true; break;
      case 9: s1 = 0.45; s2 = 0.48; invert = true; break;
      default: return LinearGradient(colors: [text, text]);
    }

    final double p1 = (s1 + shift).clamp(0.0, 1.0);
    final double p2 = (s2 + stopToOther(s1, s2) + shift).clamp(0.0, 1.0);

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: invert ? [shadow, text] : [text, shadow],
      stops: [p1, p2],
      tileMode: TileMode.clamp,
    );
  }

  double stopToOther(double s1, double s2) => s2 - s1;
}

class _SliceClipper extends CustomClipper<Rect> {
  final double start;
  final double end;

  _SliceClipper(this.start, this.end);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      size.width * start,
      0,
      size.width * end,
      size.height,
    );
  }

  @override
  bool shouldReclip(_SliceClipper oldClipper) =>
      oldClipper.start != start || oldClipper.end != end;
}
