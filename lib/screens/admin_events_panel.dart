import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class AdminEventsPanel extends StatelessWidget {
  const AdminEventsPanel({super.key});

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
          'Admin Moderation Panel',
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Approval Queue',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
            ),
            const SizedBox(height: 16),
            _buildApprovalItem('Data Science Bootcamp', 'Data Science Society', 'Pending Approval'),
            _buildApprovalItem('Inter-College Basketball', 'Sports Council', 'Pending Approval'),
            
            const SizedBox(height: 32),
            Text(
              'Club Verification Requests',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
            ),
            const SizedBox(height: 16),
            _buildVerificationItem('Photography Club', 'Requested 2 days ago'),
            _buildVerificationItem('Literature Society', 'Requested 3 days ago'),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalItem(String title, String organizer, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: U.peach.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.outfit(color: U.peach, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('By $organizer', style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: U.red,
                    side: BorderSide(color: U.red.withOpacity(0.4)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: U.primary,
                    foregroundColor: U.bg,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildVerificationItem(String clubName, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: U.dim.withOpacity(0.2),
            child: Icon(Icons.group_rounded, color: U.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clubName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text)),
                Text(time, style: GoogleFonts.outfit(fontSize: 12, color: U.sub)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.check_circle_outline_rounded, color: U.teal),
            onPressed: () {},
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}
