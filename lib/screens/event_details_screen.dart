import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'event_chat_screen.dart';
import 'qr_ticket_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final String title;
  final String category;
  final String date;
  final String time;
  final String venue;
  final String organizer;
  final String status;

  const EventDetailsScreen({
    super.key,
    required this.title,
    required this.category,
    required this.date,
    required this.time,
    required this.venue,
    required this.organizer,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor = U.primary;
    if (status == 'Live Now') statusColor = U.red;
    if (status == 'Upcoming') statusColor = U.teal;

    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(statusColor),
                      const SizedBox(height: 24),
                      _buildActionBar(context),
                      const SizedBox(height: 24),
                      _buildInfoSection(),
                      const SizedBox(height: 32),
                      _buildDescription(),
                      const SizedBox(height: 120), // Bottom padding for fixed register button
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomAction(context),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: U.bg,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'event_banner_$title',
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [U.primary.withOpacity(0.8), U.teal.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.event_rounded, size: 80, color: Colors.white30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: U.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: U.primary.withOpacity(0.2)),
              ),
              child: Text(
                category,
                style: GoogleFonts.outfit(
                  color: U.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                status,
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: U.text,
            height: 1.2,
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: U.dim.withOpacity(0.2),
              child: Icon(Icons.business_center_rounded, size: 16, color: U.dim),
            ),
            const SizedBox(width: 8),
            Text(
              'By $organizer',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: U.sub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        _buildActionItem(Icons.bookmark_border_rounded, 'Save', () {}),
        const SizedBox(width: 12),
        _buildActionItem(Icons.chat_bubble_outline_rounded, 'Chat', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventChatScreen(eventName: title)));
        }),
        const SizedBox(width: 12),
        _buildActionItem(Icons.share_outlined, 'Share', () {}),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: U.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: U.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.calendar_month_rounded, '$date at $time', 'Add to calendar'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: U.border, height: 1),
          ),
          _buildInfoRow(Icons.location_on_rounded, venue, 'View on map'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: U.border, height: 1),
          ),
          _buildInfoRow(Icons.groups_rounded, '250+ Attending', 'View participants'),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildInfoRow(IconData icon, String primary, String secondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: U.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: U.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: U.text,
                ),
              ),
              Text(
                secondary,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: U.sub,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: U.dim),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About Event',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: U.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Join us for an exciting campus event filled with learning, networking, and fun! This is a great opportunity to connect with peers and industry experts.\n\nMake sure to bring your student ID and laptop. Refreshments will be provided.',
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: U.sub,
            height: 1.6,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBottomAction(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
        decoration: BoxDecoration(
          color: U.surface.withOpacity(0.9),
          border: Border(top: BorderSide(color: U.border)),
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRTicketScreen(
                  eventName: title,
                  date: date,
                  time: time,
                  venue: venue,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: U.primary,
            foregroundColor: U.bg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            'Register Now',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ).animate().slideY(begin: 1, end: 0, delay: 500.ms, duration: 400.ms, curve: Curves.easeOutCubic),
    );
  }
}
