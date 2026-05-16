import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/event_model.dart';

class QRTicketScreen extends StatelessWidget {
  final EventModel event;
  final EventRegistration registration;

  const QRTicketScreen({
    super.key,
    required this.event,
    required this.registration,
  });

  void _addToCalendar() async {
    final startDate = event.date;
    final title = Uri.encodeComponent(event.title);
    final location = Uri.encodeComponent(event.venue);
    final details = Uri.encodeComponent(event.shortDescription);

    // Format dates for Google Calendar
    final dateStr = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
    final calendarUrl = 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$dateStr/$dateStr&details=$details&location=$location';

    final uri = Uri.parse(calendarUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = registration.ticketId ?? 'UTOPIA-TICKET';
    final qrData = 'utopia://checkin/${event.id}/${registration.userId}/$ticketId';

    return Scaffold(
      backgroundColor: U.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: U.bg, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Ticket',
          style: GoogleFonts.outfit(color: U.bg, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ticket card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: U.bg,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success check
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: U.teal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_rounded, color: U.teal, size: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registration Confirmed!',
                      style: GoogleFonts.outfit(color: U.teal, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ADMIT ONE',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: U.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Real QR Code
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: U.border, width: 2),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: U.border),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTicketInfo('Date', _formatDate(event.date)),
                        _buildTicketInfo('Time', event.startTime),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTicketInfo('Venue', event.venue, isCenter: true),
                    if (event.conductedBy.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildTicketInfo('Organized By', event.conductedBy, isCenter: true),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: U.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ticketId,
                        style: GoogleFonts.outfit(
                          color: U.dim,
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 32),

              // Add to Calendar button
              OutlinedButton.icon(
                onPressed: _addToCalendar,
                icon: Icon(Icons.calendar_today_rounded, color: U.bg),
                label: Text('Add to Calendar', style: GoogleFonts.outfit(color: U.bg, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: U.bg.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 12),

              Text(
                'Show this QR code at the venue for check-in',
                style: GoogleFonts.outfit(color: U.bg.withValues(alpha: 0.7), fontSize: 12),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketInfo(String label, String value, {bool isCenter = false}) {
    return Column(
      crossAxisAlignment: isCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(color: U.sub, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(color: U.text, fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: isCenter ? TextAlign.center : null,
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
