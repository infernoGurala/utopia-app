import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../screens/event_details_screen.dart';
import 'aditya_logo_circle.dart';

class EventCard extends StatefulWidget {
  final EventModel event;
  final bool isLarge;
  final VoidCallback? onReturn;

  const EventCard({
    super.key,
    required this.event,
    this.isLarge = false,
    this.onReturn,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _pressed = false;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  Color _statusColor() {
    switch (widget.event.status) {
      case EventStatus.liveNow:
        return U.red;
      case EventStatus.upcoming:
        return U.teal;
      case EventStatus.almostFull:
        return U.peach;
      case EventStatus.completed:
        return U.dim;
      case EventStatus.cancelled:
        return U.dim;
      default:
        return U.primary;
    }
  }

  Widget _buildBannerImage({required double height, required double width}) {
    final event = widget.event;
    Widget imageContent;

    if (event.bannerUrl != null && event.bannerUrl!.isNotEmpty) {
      final isEnded = event.status == EventStatus.completed || event.status == EventStatus.cancelled;
      final imgWidget = CachedNetworkImage(
        imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
        fit: BoxFit.cover,
        width: width,
        height: height,
        placeholder: (_, __) => Container(
          color: U.primary.withValues(alpha: 0.1),
          child: Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: U.primary.withValues(alpha: 0.4)),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _DefaultBannerContent(height: height, width: width),
      );
      imageContent = isEnded
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: imgWidget,
            )
          : imgWidget;
    } else {
      imageContent = _DefaultBannerContent(height: height, width: width);
    }

    return SizedBox(width: width, height: height, child: imageContent);
  }

  void _navigate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: widget.event)),
    );
    widget.onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLarge ? _buildLargeCard() : _buildSmallCard();
  }

  // ── LARGE CINEMATIC CARD ──
  Widget _buildLargeCard() {
    final event = widget.event;
    final statusColor = _statusColor();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); _navigate(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 296,
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: U.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: U.primary.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Banner with overlay badges ──
              Stack(
                children: [
                  Hero(
                    tag: 'event_banner_${event.id ?? event.title}',
                    child: _buildBannerImage(height: 172, width: 296),
                  ),
                  // Gradient fade into card bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, U.card.withValues(alpha: 0.95)],
                        ),
                      ),
                    ),
                  ),
                  // Category pill — top left
                  Positioned(
                    top: 12, left: 12,
                    child: _GlassBadge(label: event.category),
                  ),
                  // Status badge — top right
                  Positioned(
                    top: 12, right: 12,
                    child: _GlassBadge(label: event.status.label, accentColor: statusColor),
                  ),
                  // Title overlaid at bottom of image
                  Positioned(
                    bottom: 10, left: 14, right: 14,
                    child: Text(
                      event.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: U.text,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // ── Details below ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.schedule_rounded, size: 12, color: U.primary.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(event.date)} • ${event.startTime}',
                        style: GoogleFonts.outfit(fontSize: 12, color: U.sub, fontWeight: FontWeight.w500),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      if (event.isAdityaEvent) ...[
                        const AdityaLogoCircle(size: 13),
                        const SizedBox(width: 6),
                      ] else ...[
                        Icon(Icons.place_outlined, size: 12, color: U.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          '${event.venue}  ·  ${event.participantCount} going',
                          style: GoogleFonts.outfit(fontSize: 12, color: U.sub, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SMALL PREMIUM CARD ──
  Widget _buildSmallCard() {
    final event = widget.event;
    final statusColor = _statusColor();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); _navigate(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: U.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: U.primary.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: image ──
              Stack(
                children: [
                  Hero(
                    tag: 'event_banner_${event.id ?? event.title}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildBannerImage(height: 88, width: 88),
                    ),
                  ),
                  // Subtle color tint overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            statusColor.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // ── Right: details ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          event.category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: U.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor, fontSize: 8, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w600, color: U.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.schedule_rounded, size: 11, color: U.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 5),
                      Text(
                        '${_formatDate(event.date)} · ${event.startTime}',
                        style: GoogleFonts.outfit(fontSize: 11, color: U.sub, fontWeight: FontWeight.w500),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (event.isAdityaEvent) ...[
                        const AdityaLogoCircle(size: 12),
                        const SizedBox(width: 5),
                      ] else ...[
                        Icon(Icons.place_outlined, size: 11, color: U.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          event.venue,
                          style: GoogleFonts.outfit(fontSize: 11, color: U.sub, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 11, color: U.dim.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Default Banner Content ──
class _DefaultBannerContent extends StatelessWidget {
  final double height;
  final double width;
  const _DefaultBannerContent({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [U.primary, U.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.event_rounded,
          size: height * 0.3,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ── Glass Badge Widget ──
class _GlassBadge extends StatelessWidget {
  final String label;
  final Color? accentColor;
  const _GlassBadge({required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (accentColor ?? Colors.white).withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: accentColor ?? Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
