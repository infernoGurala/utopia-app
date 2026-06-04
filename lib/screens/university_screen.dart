import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import '../theme/image_overlay_colors.dart';
import 'iaa_screen.dart';
import 'attendance_screen.dart';
import 'people_screen.dart';
import 'friends_screen.dart';
import 'map_screen.dart';
import 'uni_chat_screen.dart';
import 'docs_screen.dart';
import 'events_screen.dart';
import 'timetable_screen.dart';

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
    final isDark = appThemeNotifier.value.isDark;
    final currentThemeKey = appThemeNotifier.value.key;

    final titleColor = isDark
        ? (currentThemeKey == 'gruvbox'
            ? const Color(0xFFFB4934)
            : currentThemeKey == 'everforest'
                ? const Color(0xFFA7C080)
                : currentThemeKey == 'github-dark'
                    ? const Color(0xFF58A6FF)
                    : currentThemeKey == 'orchid'
                        ? const Color(0xFFCBA6F7)
                        : Colors.white)
        : ImageOverlayColors.titleColor(currentThemeKey, 'morning');

    final subtitleColor = isDark
        ? U.sub
        : ImageOverlayColors.subtitleColor(currentThemeKey, 'morning');

    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          // Background Image (Extended for smooth transition)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Opacity(
              opacity: isDark ? 0.35 : 0.6,
              child: Image.asset(
                'assets/university/background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                color: isDark ? U.bg : null,
                colorBlendMode: isDark ? BlendMode.multiply : null,
              ),
            ),
          ),
          // Gradient overlay: top half clear, bottom half smooth fade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          U.bg.withValues(alpha: 0.45),
                          U.bg.withValues(alpha: 0.15),
                          U.bg.withValues(alpha: 1.0),
                        ]
                      : [
                          U.bg.withValues(alpha: 0.0),
                          U.bg.withValues(alpha: 0.0),
                          U.bg,
                        ],
                  stops: const [0.0, 0.5, 1.0],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'University',
                        style: GoogleFonts.newsreader(
                          color: titleColor,
                          fontSize: 38,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Explore your campus network',
                        style: GoogleFonts.plusJakartaSans(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.1),
                              offset: const Offset(0, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: UtopiaLoader(scale: 0.7),
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
                      subtitle: 'Track presence.',
                      icon: Icons.fact_check_outlined,
                      color: U.primary,
                      delay: 100,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'People',
                      subtitle: 'Campus network.',
                      icon: Icons.public_outlined,
                      color: U.blue,
                      delay: 150,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PeopleScreen(),
                        ),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Friends',
                      subtitle: 'Your connections.',
                      icon: Icons.groups_outlined,
                      color: U.peach,
                      delay: 200,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendsScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Events',
                      subtitle: 'Happenings.',
                      icon: Icons.event_available_outlined,
                      color: const Color(0xFF10B981), // green
                      delay: 250,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EventsScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Uni Chat',
                      subtitle: 'Group chat.',
                      icon: Icons.forum_outlined,
                      color: U.teal,
                      delay: 300,
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
                      title: 'Docs',
                      subtitle: 'Resources.',
                      icon: Icons.description_outlined,
                      color: const Color(0xFF7C6AF7),
                      delay: 350,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DocsScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'IAA',
                      subtitle: 'AI Assistant.',
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF7F77DD),
                      delay: 400,
                      onTap: () => Navigator.push(
                        context,
                        IAAScreen.route(),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Map',
                      subtitle: 'Campus map.',
                      icon: Icons.map_outlined,
                      color: U.red,
                      delay: 450,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Timetable',
                      subtitle: 'Schedule.',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFFF43F5E),
                      delay: 500,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TimetableScreen()),
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
    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: U.border,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: U.primary, size: 20),
                Icon(Icons.chevron_right_rounded, color: U.dim, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.newsreader(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: U.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle.replaceAll('\n', ' '),
              style: GoogleFonts.plusJakartaSans(
                color: U.sub,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
