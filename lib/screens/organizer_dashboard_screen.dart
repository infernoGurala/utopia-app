import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class OrganizerDashboardScreen extends StatelessWidget {
  const OrganizerDashboardScreen({super.key});

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
          'Organizer Dashboard',
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 32),
              Text(
                'Analytics Overview',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
              ),
              const SizedBox(height: 16),
              _buildAnalyticsGrid(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Events',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text('Create New', style: GoogleFonts.outfit(color: U.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildManageEventsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: U.primary.withOpacity(0.2),
            child: Icon(Icons.business_center_rounded, color: U.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Computer Science Club',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded, color: U.teal, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text('5 Past Events • 1.2k Followers', style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total Registrations', '842', Icons.how_to_reg_rounded, U.primary),
        _buildStatCard('Event Views', '3.4k', Icons.visibility_rounded, U.teal),
        _buildStatCard('Engagement', '84%', Icons.auto_graph_rounded, U.peach),
        _buildStatCard('Shares', '156', Icons.share_rounded, U.blue),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: U.text),
          ),
        ],
      ),
    );
  }

  Widget _buildManageEventsList() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildManageEventItem('HackTheFuture 2026', 'May 20, 2026', '250 Registrations', 'Live Now', U.red),
        _buildManageEventItem('AI Summit', 'May 25, 2026', '120 Registrations', 'Upcoming', U.teal),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildManageEventItem(String title, String date, String regInfo, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text)),
                    const SizedBox(height: 4),
                    Text(date, style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
                  ],
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
                  style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: U.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(regInfo, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: U.text)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.people_outline_rounded, color: U.primary, size: 20),
                    onPressed: () {},
                    tooltip: 'View Participants',
                  ),
                  IconButton(
                    icon: Icon(Icons.campaign_outlined, color: U.primary, size: 20),
                    onPressed: () {},
                    tooltip: 'Send Announcement',
                  ),
                  IconButton(
                    icon: Icon(Icons.qr_code_scanner_rounded, color: U.primary, size: 20),
                    onPressed: () {},
                    tooltip: 'Scan QR Code Check-in',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
