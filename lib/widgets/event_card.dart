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
    final width = isLarge ? 300.0 : double.infinity;
    final imageHeight = isLarge ? 140.0 : 100.0;

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
        width: width,
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: U.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    height: imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [U.primary.withValues(alpha: 0.5), U.teal.withValues(alpha: 0.5)],
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Center(
                                  child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              )
                        : Center(
                            child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      event.category,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
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
                            fontSize: isLarge ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: U.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLarge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: U.dim),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(event.date)} • ${event.startTime}',
                        style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: U.dim),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!isLarge) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 14, color: U.dim),
                        const SizedBox(width: 6),
                        Text(
                          '${event.participantCount} registered',
                          style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
