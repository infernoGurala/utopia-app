import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

enum UtopiaSnackBarTone { success, error, info }

void showUtopiaSnackBar(
  BuildContext context, {
  required String message,
  UtopiaSnackBarTone tone = UtopiaSnackBarTone.info,
  String? actionLabel,
  VoidCallback? onActionPressed,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final isDark = Theme.of(context).brightness == Brightness.dark;

  final toneColor = switch (tone) {
    UtopiaSnackBarTone.success => const Color(0xFF08BB68),
    UtopiaSnackBarTone.error => const Color(0xFFF38BA8),
    UtopiaSnackBarTone.info => U.primary,
  };

  final icon = switch (tone) {
    UtopiaSnackBarTone.success => Icons.check_circle_rounded,
    UtopiaSnackBarTone.error => Icons.error_rounded,
    UtopiaSnackBarTone.info => Icons.info_rounded,
  };

  // Base background and border with premium glassmorphism
  final Color backgroundColor = isDark
      ? toneColor.withValues(alpha: 0.08)
      : toneColor.withValues(alpha: 0.06);
      
  final Color borderColor = isDark
      ? toneColor.withValues(alpha: 0.25)
      : toneColor.withValues(alpha: 0.18);

  final Color textColor = isDark
      ? Colors.white
      : Colors.black87;

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: actionLabel != null ? const Duration(milliseconds: 4000) : const Duration(milliseconds: 2200),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: toneColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      onActionPressed();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: toneColor.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundColor: toneColor,
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
