import 'package:flutter/material.dart';

class BouncingLoader extends StatefulWidget {
  final Color color;
  const BouncingLoader({super.key, this.color = Colors.white});

  @override
  State<BouncingLoader> createState() => _BouncingLoaderState();
}

class _BouncingLoaderState extends State<BouncingLoader> with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  late Animation<double> _anim1;
  late Animation<double> _anim2;
  late Animation<double> _anim3;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _controller2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _controller3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _anim1 = CurvedAnimation(parent: _controller1, curve: Curves.easeInOut);
    _anim2 = CurvedAnimation(parent: _controller2, curve: Curves.easeInOut);
    _anim3 = CurvedAnimation(parent: _controller3, curve: Curves.easeInOut);

    _startAnimations();
  }

  void _startAnimations() {
    _controller1.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller2.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller3.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Shadows
              _buildShadow(_anim1, 0.15, true),
              _buildShadow(_anim2, 0.45, true),
              _buildShadow(_anim3, 0.15, false),
              
              // Circles
              _buildCircle(_anim1, 0.15, true),
              _buildCircle(_anim2, 0.45, true),
              _buildCircle(_anim3, 0.15, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(Animation<double> animation, double percentH, bool isLeft) {
    return Positioned(
      left: isLeft ? 120 * percentH : null,
      right: !isLeft ? 120 * percentH : null,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          double top = 36.0 - (36.0 * t);
          double height = 4.0;
          double scaleX = 1.7;
          BorderRadius borderRadius = const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          );

          if (t <= 0.4) {
            double pt = t / 0.4;
            height = 4.0 + (10.0 * pt);
            scaleX = 1.7 - (0.7 * pt);
          } else {
            height = 14.0;
            scaleX = 1.0;
            borderRadius = BorderRadius.circular(7);
          }

          return Container(
            padding: EdgeInsets.only(top: top),
            alignment: Alignment.topCenter,
            child: Transform.scale(
              scaleX: scaleX,
              alignment: Alignment.center,
              child: Container(
                width: 14,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: borderRadius,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShadow(Animation<double> animation, double percentH, bool isLeft) {
    return Positioned(
      left: isLeft ? 120 * percentH : null,
      right: !isLeft ? 120 * percentH : null,
      top: 48,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          double scaleX = 1.5;
          double opacity = 0.1; // Extremely light shadow
          
          if (t <= 0.4) {
            double pt = t / 0.4;
            scaleX = 1.5 - (0.5 * pt);
            opacity = 0.1 - (0.05 * pt); // 0.1 down to 0.05
          } else {
            double pt = (t - 0.4) / 0.6;
            scaleX = 1.0 - (0.8 * pt);
            opacity = 0.05 - (0.03 * pt); // 0.05 down to 0.02
          }

          return Transform.scale(
            scaleX: scaleX,
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black,
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
