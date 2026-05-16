import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'attendance_screen.dart';
import 'people_screen.dart';
import 'friends_screen.dart';
import 'map_screen.dart';
import 'uni_chat_screen.dart';
import 'docs_screen.dart';
import 'events_screen.dart';

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen> {
  String _universityId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final uniId = userDoc.data()?['selectedUniversityId'] as String?;
        if (mounted) {
          setState(() {
            _universityId = uniId ?? '';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          // Background Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Opacity(
              opacity: isDark ? 0.3 : 0.6,
              child: Image.asset(
                'assets/university/background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          // Gradient fade for background
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.2,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.25,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    U.bg.withValues(alpha: 0.0),
                    U.bg,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'University',
                              style: GoogleFonts.playfairDisplay(
                                color: U.text,
                                fontSize: 42,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.normal,
                                letterSpacing: -1,
                              ),
                            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                            const SizedBox(height: 4),
                            Text(
                              'Explore your campus network',
                              style: GoogleFonts.outfit(color: U.dim, fontSize: 14, fontWeight: FontWeight.w400),
                            ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_isLoading)
                  Expanded(
                    child: Center(
                      child: const UtopiaLoader(scale: 0.7),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _UniversityCard(
                          title: 'Attendance',
                          subtitle: 'Track your\nclass presence',
                          icon: Icons.fact_check_outlined,
                          color: U.primary,
                          delay: 100,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                          ),
                        ),
                        _UniversityCard(
                          title: 'Friends',
                          subtitle: 'Connect with\nyour peers',
                          icon: Icons.groups_outlined,
                          color: U.peach,
                          delay: 150,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FriendsScreen()),
                          ),
                        ),
                        _UniversityCard(
                          title: 'Docs',
                          subtitle: 'Access important\nresources',
                          icon: Icons.description_outlined,
                          color: const Color(0xFF7C6AF7),
                          delay: 200,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DocsScreen()),
                          ),
                        ),
                        _UniversityCard(
                          title: 'People',
                          subtitle: 'Explore the\ncampus community',
                          icon: Icons.public_outlined,
                          color: U.blue,
                          delay: 250,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PeopleScreen(
                                universityId: _universityId.isNotEmpty
                                    ? _universityId
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        _UniversityCard(
                          title: 'Events',
                          subtitle: 'Campus happenings\nand activities',
                          icon: Icons.event_available_outlined,
                          color: const Color(0xFF10B981), // green
                          delay: 300,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EventsScreen()),
                          ),
                        ),
                        _UniversityCard(
                          title: 'Uni Chat',
                          subtitle: 'Chat with students\nand groups',
                          icon: Icons.forum_outlined,
                          color: U.teal,
                          delay: 350,
                          onTap: () async {
                            if (_universityId.isNotEmpty) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UniChatScreen(universityId: _universityId),
                                ),
                              );
                            }
                          },
                        ),
                        _UniversityCard(
                          title: 'Map',
                          subtitle: 'Navigate campus\neasily',
                          icon: Icons.map_outlined,
                          color: U.red,
                          delay: 400,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MapScreen()),
                          ),
                        ),
                      ],
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

class _UniversityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;
  final bool isComingSoon;

  const _UniversityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.delay,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isComingSoon 
                    ? const Color(0xFF10B981).withValues(alpha: 0.1) // Light green for Events
                    : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isComingSoon ? const Color(0xFF10B981) : color, size: 26),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ),
                if (isComingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Soon',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.chevron_right_rounded, color: U.dim, size: 16),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: delay.ms, duration: 400.ms).slideY(
            begin: 0.1,
            end: 0,
            delay: delay.ms,
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
