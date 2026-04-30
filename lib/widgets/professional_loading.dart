import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

// Using constants from the app's standard theme config (assumed to be available as U)
import '../main.dart'; 

class ProfessionalLoading extends StatefulWidget {
  final String? message;
  const ProfessionalLoading({super.key, this.message});

  @override
  State<ProfessionalLoading> createState() => _ProfessionalLoadingState();
}

class _ProfessionalLoadingState extends State<ProfessionalLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * pi,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            U.primary.withValues(alpha: 0.1),
                            U.primary.withValues(alpha: 0.5),
                            U.primary,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: U.bg,
                      ),
                    ),
                    Icon(Icons.auto_awesome, color: U.primary, size: 20),
                  ],
                ),
              );
            },
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Gentle pulse for the text opacity
                final opacity = 0.5 + 0.5 * sin(_controller.value * 2 * pi);
                return Opacity(
                  opacity: opacity,
                  child: Text(
                    widget.message!,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
