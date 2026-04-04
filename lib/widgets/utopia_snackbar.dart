import 'package:flutter/material.dart';
import '../main.dart';

enum UtopiaSnackBarTone { success, error, info }

void showUtopiaSnackBar(
  BuildContext context, {
  required String message,
  UtopiaSnackBarTone tone = UtopiaSnackBarTone.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final backgroundColor = switch (tone) {
    UtopiaSnackBarTone.success => const Color(0xFF1F2B24),
    UtopiaSnackBarTone.error => const Color(0xFF312127),
    UtopiaSnackBarTone.info => const Color(0xFF25263A),
  };
  final borderColor = switch (tone) {
    UtopiaSnackBarTone.success => const Color(0xFF3E8E63),
    UtopiaSnackBarTone.error => const Color(0xFFF38BA8),
    UtopiaSnackBarTone.info => U.primary,
  };
  final iconColor = switch (tone) {
    UtopiaSnackBarTone.success => const Color(0xFFA6E3A1),
    UtopiaSnackBarTone.error => const Color(0xFFF5B0C3),
    UtopiaSnackBarTone.info => U.primary,
  };
  final icon = switch (tone) {
    UtopiaSnackBarTone.success => Icons.check_circle_rounded,
    UtopiaSnackBarTone.error => Icons.error_rounded,
    UtopiaSnackBarTone.info => Icons.info_rounded,
  };

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(milliseconds: 2200),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
