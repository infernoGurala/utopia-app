import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/role_service.dart';
import 'developer_panel_screen.dart';

class UtopiaSectionScreen extends StatefulWidget {
  final bool initialIsSuperUser;

  const UtopiaSectionScreen({
    super.key,
    required this.initialIsSuperUser,
  });

  @override
  State<UtopiaSectionScreen> createState() => _UtopiaSectionScreenState();
}

class _UtopiaSectionScreenState extends State<UtopiaSectionScreen> {
  bool _isSuperUser = false;

  @override
  void initState() {
    super.initState();
    _isSuperUser = widget.initialIsSuperUser;
    RoleService().isSuperUser().then((v) {
      if (mounted) {
        setState(() => _isSuperUser = v);
      }
    });
  }

  Future<void> _launchBugReport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'johnmosesg150@gmail.com',
      query: 'subject=UTOPIA Bug Report / Suggestion',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (_) {}
  }

  Widget _groupedTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: U.dim, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        title: Text(
          'UTOPIA',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: U.text,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Premium Logo Section
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: U.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.rocket_launch_outlined,
                      color: U.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UTOPIA',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App Version 1.0.0',
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Settings Group
            Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border),
              ),
              child: Column(
                children: [
                  // Report Bugs & Suggestions
                  _groupedTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report Bugs & Suggestions',
                    sub: 'Help us improve UTOPIA',
                    color: U.teal,
                    onTap: _launchBugReport,
                  ),

                  if (_isSuperUser) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: U.border.withValues(alpha: 0.5),
                    ),
                    // Super Controls
                    _groupedTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Super Controls',
                      sub: 'Analytics, broadcasts, and app-wide settings',
                      color: U.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeveloperPanelScreen(),
                        ),
                      ),
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
