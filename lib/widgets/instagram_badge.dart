import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Real authentic Instagram logo painter rendering the camera body, lens & flash
class RealInstagramIcon extends StatelessWidget {
  final double size;
  const RealInstagramIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF833AB4),
            Color(0xFFFD1D1D),
            Color(0xFFFCB045),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.54,
          height: size * 0.54,
          child: CustomPaint(
            painter: _InstagramCameraPainter(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _InstagramCameraPainter extends CustomPainter {
  final Color color;
  _InstagramCameraPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.12;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Outer Camera Body (Rounded Rect)
    final RRect outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(outerRect, paint);

    // Center Lens (Circle)
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.22;
    canvas.drawCircle(center, radius, paint);

    // Top-Right Flash Dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final dotCenter = Offset(size.width * 0.72, size.height * 0.28);
    final dotRadius = size.width * 0.08;
    canvas.drawCircle(dotCenter, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _InstagramCameraPainter oldDelegate) =>
      oldDelegate.color != color;
}

class InstagramBadge extends StatelessWidget {
  const InstagramBadge({
    super.key,
    required this.handle,
    this.fontSize = 11.5,
    this.iconSize = 18,
    this.compact = false,
    this.showHandle,
  });

  final String handle;
  final double fontSize;
  final double iconSize;
  final bool compact;
  final bool? showHandle;

  static Future<void> launchInstagramProfile(String handle) async {
    final clean = handle.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://instagram.com/$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not open Instagram profile for $clean: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanHandle = handle.replaceAll('@', '').trim();
    if (cleanHandle.isEmpty) return const SizedBox.shrink();

    final bool displayHandle = showHandle ?? !compact;

    if (!displayHandle) {
      return GestureDetector(
        onTap: () => launchInstagramProfile(cleanHandle),
        child: RealInstagramIcon(size: iconSize),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => launchInstagramProfile(cleanHandle),
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFFE1306C).withValues(alpha: 0.18),
        highlightColor: const Color(0xFFE1306C).withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: displayHandle ? (compact ? 8 : 10) : 5,
            vertical: displayHandle ? (compact ? 3 : 5) : 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE1306C).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE1306C).withValues(alpha: 0.32),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RealInstagramIcon(size: iconSize),
              if (displayHandle) ...[
                const SizedBox(width: 5),
                Text(
                  '@$cleanHandle',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFE1306C),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.open_in_new_rounded,
                  size: fontSize * 0.9,
                  color: const Color(0xFFE1306C).withValues(alpha: 0.75),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
