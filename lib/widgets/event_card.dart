import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../screens/event_details_screen.dart';

class EventCard extends StatelessWidget {
  final EventModel event;
  final bool isLarge;
  final VoidCallback? onReturn;

  const EventCard({
    super.key,
    required this.event,
    this.isLarge = false,
    this.onReturn,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor = U.primary;
    if (event.status == EventStatus.liveNow) {
      statusColor = U.red;
    } else if (event.status == EventStatus.upcoming) {
      statusColor = U.teal;
    } else if (event.status == EventStatus.almostFull) {
      statusColor = U.peach;
    } else if (event.status == EventStatus.completed) {
      statusColor = U.dim;
    }

    if (isLarge) {
      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
          );
          if (onReturn != null) {
            onReturn!();
          }
        },
        child: Container(
          width: 280.0,
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner Image
              Stack(
                children: [
                  Hero(
                    tag: 'event_banner_${event.id ?? event.title}',
                    child: Container(
                      height: 130.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [U.primary.withValues(alpha: 0.4), U.teal.withValues(alpha: 0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: event.bannerUrl != null && event.bannerUrl!.isNotEmpty
                          ? (event.status == EventStatus.completed || event.status == EventStatus.cancelled)
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      1, 0,
                                  ]),
                                  child: CachedNetworkImage(
                                    imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Center(
                                      child: Icon(Icons.event_rounded, size: 36, color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(Icons.event_rounded, size: 36, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                )
                          : Center(
                              child: Icon(Icons.event_rounded, size: 36, color: Colors.white.withValues(alpha: 0.5)),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        event.category,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: U.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_formatDate(event.date)} • ${event.startTime}',
                      style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.venue} • ${event.participantCount} registered',
                      style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Side-by-side split layout for vertical list events
      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
          );
          if (onReturn != null) {
            onReturn!();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Image Banner
              Hero(
                tag: 'event_banner_${event.id ?? event.title}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [U.primary.withValues(alpha: 0.4), U.teal.withValues(alpha: 0.4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: event.bannerUrl != null && event.bannerUrl!.isNotEmpty
                        ? (event.status == EventStatus.completed || event.status == EventStatus.cancelled)
                            ? ColorFiltered(
                                colorFilter: const ColorFilter.matrix([
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0,      0,      0,      1, 0,
                                ]),
                                child: CachedNetworkImage(
                                  imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(Icons.event_rounded, size: 24, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Center(
                                  child: Icon(Icons.event_rounded, size: 24, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              )
                        : Center(
                            child: Icon(Icons.event_rounded, size: 24, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Right: Info Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          event.category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: U.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: U.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(event.date)} • ${event.startTime}',
                      style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${event.venue} • ${event.participantCount} registered',
                      style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
