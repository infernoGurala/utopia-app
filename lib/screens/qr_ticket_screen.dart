import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class QRTicketScreen extends StatelessWidget {
  final String eventName;
  final String date;
  final String time;
  final String venue;

  const QRTicketScreen({
    super.key,
    required this.eventName,
    required this.date,
    required this.time,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.primary, // Make it pop
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: U.bg, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: U.bg,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Admit One',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 14,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      eventName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        color: U.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Mock QR Code
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: U.border, width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 160, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Divider(color: U.border),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTicketInfo('Date', date),
                        _buildTicketInfo('Time', time),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTicketInfo('Venue', venue, isCenter: true),
                    const SizedBox(height: 16),
                    Text(
                      'TICKET ID: UTOPIA-8492-HTF',
                      style: GoogleFonts.outfit(
                        color: U.dim,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 32),
              
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.calendar_today_rounded, color: U.bg),
                label: Text('Add to Calendar', style: GoogleFonts.outfit(color: U.bg)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: U.bg.withOpacity(0.5)),
                ),
              ).animate().fadeIn(delay: 300.ms),
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
          style: GoogleFonts.outfit(
            color: U.sub,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
