import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class EventNotificationsScreen extends StatelessWidget {
  const EventNotificationsScreen({super.key});

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
          'Notifications',
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildNotificationItem(
            'New Event Near You',
            'HackTheFuture 2026 was just added by the Computer Science Club.',
            '2h ago',
            Icons.location_on_rounded,
            U.primary,
            isUnread: true,
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          
          _buildNotificationItem(
            'Registration Ending Soon',
            'Only 2 days left to register for the Robotics Workshop.',
            '5h ago',
            Icons.warning_amber_rounded,
            U.peach,
            isUnread: true,
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

          _buildNotificationItem(
            'Event Saved',
            'You saved AI Summit. We will remind you 1 day before it starts.',
            '1d ago',
            Icons.bookmark_rounded,
            U.teal,
            isUnread: false,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String body,
    String time,
    IconData icon,
    Color color, {
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? color.withOpacity(0.05) : U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnread ? color.withOpacity(0.3) : U.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                          color: U.text,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isUnread ? U.text.withOpacity(0.9) : U.sub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
