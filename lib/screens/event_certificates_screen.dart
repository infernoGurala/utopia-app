import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class EventCertificatesScreen extends StatelessWidget {
  const EventCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Certificates',
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildCertificateCard('HackTheFuture 2025', 'Computer Science Club', 'Nov 12, 2025', U.primary),
          _buildCertificateCard('AI Workshop', 'Robotics Society', 'Oct 05, 2025', U.teal),
          _buildCertificateCard('Cultural Fest Participant', 'Cultural Committee', 'Mar 20, 2025', U.peach),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(String eventName, String issuer, String date, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Icon(Icons.workspace_premium_rounded, size: 48, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  eventName,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: U.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  issuer,
                  style: GoogleFonts.outfit(fontSize: 11, color: U.sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: GoogleFonts.outfit(fontSize: 10, color: U.dim),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }
}
