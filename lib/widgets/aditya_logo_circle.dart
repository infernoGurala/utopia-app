import 'package:flutter/material.dart';
import '../main.dart';

class AdityaLogoCircle extends StatelessWidget {
  final double size;
  final bool hasBorder;

  const AdityaLogoCircle({
    super.key,
    this.size = 20,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black, // Dark background matching logo
        border: hasBorder 
            ? Border.all(color: U.gold.withValues(alpha: 0.6), width: 1.0)
            : null,
        image: const DecorationImage(
          image: AssetImage('assets/university/aditya_logo.png'),
          fit: BoxFit.contain,
        ),
        boxShadow: hasBorder ? [
          BoxShadow(
            color: U.gold.withValues(alpha: 0.15),
            blurRadius: 4,
            spreadRadius: 1,
          )
        ] : null,
      ),
    );
  }
}
