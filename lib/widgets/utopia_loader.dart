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
    // mainSize corresponds to 4em in CSS
    final double mainSize = 40 * widget.scale;
    final Color textColor = widget.color ?? U.text;
    final Color shadowColor = textColor.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: mainSize * 1.825, // 7.3em / 4 = 1.825
          height: mainSize * 0.25, // 1em / 4 = 0.25
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
        const SizedBox(height: 2), // Small gap before line
        // Line at the bottom
        Container(
          height: mainSize * 0.0125, // 0.05em / 4 = 0.0125
          width: mainSize * 0.125, // (mainSize / 2) / 4 = 0.125
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(mainSize * 0.0125),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _wobbleAnimation,
            builder: (context, child) {
              // translate -90% to 90%
              final double t = _wobbleAnimation.value;
              final double x = (t <= 0.5) 
                  ? (-0.9 + (t * 2) * 1.8) // 0 to 0.5 -> -0.9 to 0.9
                  : (0.9 - (t - 0.5) * 2 * 1.8); // 0.5 to 1 -> 0.9 to -0.9
              
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
      left: (mainSize * 0.9125) + marginLeft - (mainSize * 0.5), // Center adjustment
      child: Opacity(
        opacity: opacity,
        child: ClipRect(
          clipper: _SliceClipper(start, end),
          child: AnimatedBuilder(
            animation: _scrollAnimation,
            builder: (context, child) {
              final double scrollPos = _scrollAnimation.value;
              // translateX(-100%) to (100%)
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
    // Background size is 200%, position animates
    // We simulate this by adjusting stops based on t
    final List<Color> colors = [text, shadow];
    double stop;

    // CSS gradients have specific stops for each slice
    switch (index) {
      case 1: stop = 0.04; break;
      case 2: stop = 0.09; break;
      case 3: stop = 0.15; break;
      case 4: stop = 0.20; break;
      case 6: return LinearGradient(colors: [shadow, text], stops: [0.29 - (1-t), 0.32 - (1-t)], tileMode: TileMode.mirror);
      case 7: return LinearGradient(colors: [shadow, text], stops: [0.34 - (1-t), 0.37 - (1-t)], tileMode: TileMode.mirror);
      case 8: return LinearGradient(colors: [shadow, text], stops: [0.39 - (1-t), 0.42 - (1-t)], tileMode: TileMode.mirror);
      case 9: return LinearGradient(colors: [shadow, text], stops: [0.45 - (1-t), 0.48 - (1-t)], tileMode: TileMode.mirror);
      default: return LinearGradient(colors: [text, text]);
    }

    // Simulate shadow animation by shifting stops
    // background-position: -98% to 102%
    final double shift = (t * 2) - 1; // -1 to 1
    return LinearGradient(
      colors: colors,
      stops: [stop + shift, stop + 0.03 + shift],
      tileMode: TileMode.mirror,
    );
  }
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
