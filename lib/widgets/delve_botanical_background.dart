import 'package:flutter/material.dart';
import '../main.dart';

class BotanicalBackground extends StatelessWidget {
  final Widget child;
  final int seed;
  final double opacity;

  const BotanicalBackground({
    super.key,
    required this.child,
    required this.seed,
    this.opacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: U.bg,
      child: child,
    );
  }
}
