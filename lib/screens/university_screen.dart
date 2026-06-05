import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import 'university_selection_screen.dart';
import 'iaa_screen.dart';
import 'attendance_screen.dart';
import 'people_screen.dart';
import 'friends_screen.dart';
import 'map_screen.dart';
import 'uni_chat_screen.dart';
import 'docs_screen.dart';
import 'events_screen.dart';
import 'timetable_screen.dart';
import '../services/cache_service.dart';

class UniversityScreen extends StatefulWidget {
  const UniversityScreen({super.key});

  @override
  State<UniversityScreen> createState() => _UniversityScreenState();
}

class _UniversityScreenState extends State<UniversityScreen> {
  String _universityId = U.cachedUniversityId;
  String _universityName = U.cachedUniversityName;
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
        
        String uniName = '';
        if (uniId != null && uniId.isNotEmpty) {
          final uniDoc = await FirebaseFirestore.instance
              .collection('universities')
              .doc(uniId)
              .get();
          if (uniDoc.exists && uniDoc.data() != null) {
            uniName = uniDoc.data()?['name'] as String? ?? '';
          }

          // Cache selected university locally
          await CacheService().saveAppSetting('cached_university_id', uniId);
          await CacheService().saveAppSetting('cached_university_name', uniName);
          U.cachedUniversityId = uniId;
          U.cachedUniversityName = uniName;
        }

        if (mounted) {
          setState(() {
            _universityId = uniId ?? '';
            _universityName = uniName;
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

  String get _displayUniversityName {
    if (_universityName.isNotEmpty) return _universityName;
    if (_universityId.isNotEmpty) {
      return _universityId
          .split('-')
          .map((word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '')
          .join(' ');
    }
    return 'Utopia Campus';
  }



  @override
  Widget build(BuildContext context) {
    final theme = appThemeNotifier.value;

    final cards = [
      _CardItem(
        title: 'Attendance',
        subtitle: 'Track presence.',
        icon: Icons.fact_check_rounded,
        color: theme.primary,
        badgeText: '98%',
        delay: 50,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
        ),
      ),
      _CardItem(
        title: 'People',
        subtitle: 'Campus directory.',
        icon: Icons.people_alt_rounded,
        color: theme.blue,
        badgeText: 'Find',
        delay: 100,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PeopleScreen()),
        ),
      ),
      _CardItem(
        title: 'Friends',
        subtitle: 'Connections.',
        icon: Icons.groups_rounded,
        color: theme.peach,
        badgeText: 'Chat',
        delay: 150,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
        ),
      ),
      _CardItem(
        title: 'Events',
        subtitle: 'Happenings.',
        icon: Icons.local_activity_rounded,
        color: theme.green,
        badgeText: 'Live',
        delay: 200,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventsScreen()),
        ),
      ),
      _CardItem(
        title: 'Uni Chat',
        subtitle: 'Group discussion.',
        icon: Icons.chat_bubble_rounded,
        color: theme.teal,
        badgeText: 'Room',
        delay: 250,
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
      _CardItem(
        title: 'Docs',
        subtitle: 'Study resources.',
        icon: Icons.folder_copy_rounded,
        color: theme.lavender,
        badgeText: 'PDFs',
        delay: 300,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DocsScreen()),
        ),
      ),
      _CardItem(
        title: 'IAA',
        subtitle: 'AI Assistant.',
        icon: Icons.auto_awesome_rounded,
        color: theme.primary,
        badgeText: 'GPT',
        delay: 350,
        onTap: () => Navigator.push(
          context,
          IAAScreen.route(),
        ),
      ),
      _CardItem(
        title: 'Map',
        subtitle: 'Campus locator.',
        icon: Icons.explore_rounded,
        color: (theme.key == 'primary-light' || theme.key == 'primary-dark')
            ? theme.primary
            : theme.red,
        badgeText: '3D',
        delay: 400,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        ),
      ),
      _CardItem(
        title: 'Timetable',
        subtitle: 'Class schedule.',
        icon: Icons.calendar_month_rounded,
        color: theme.sky,
        badgeText: 'Today',
        delay: 450,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimetableScreen()),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Premium Modern Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular University Change Button (Left)
                      _HeaderButton(
                        icon: Icons.swap_horiz_rounded,
                        tooltip: 'Change University',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UniversitySelectionScreen(),
                            ),
                          );
                          _loadData(); // Reload selected university details on back
                        },
                      ),
                      // Circular Notification Bell Button (Right)
                      _HeaderButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notifications',
                        showBadge: true,
                        badgeText: '1',
                        onTap: () {
                          U.showSnackBar(
                            context,
                            'Welcome to UTOPIA! Explore your campus network.',
                            icon: Icons.notifications_active_rounded,
                            iconColor: theme.primary,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY CAMPUS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: theme.primary.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _displayUniversityName,
                        style: GoogleFonts.outfit(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: theme.text,
                          letterSpacing: -0.6,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return _UniversityCard(
                          title: card.title,
                          subtitle: card.subtitle,
                          icon: card.icon,
                          color: card.color,
                          badgeText: card.badgeText,
                          delay: card.delay,
                          onTap: card.onTap,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _CardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badgeText;
  final int delay;
  final VoidCallback onTap;

  _CardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.delay,
    required this.onTap,
  });
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool showBadge;
  final String? badgeText;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08) 
                    : Colors.black.withValues(alpha: 0.05),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: U.text,
                size: 20,
              ),
            ),
            if (showBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: U.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: U.bg,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: badgeText != null
                      ? Text(
                          badgeText!,
                          style: GoogleFonts.plusJakartaSans(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UniversityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String badgeText;
  final VoidCallback onTap;
  final int delay;

  const _UniversityCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.badgeText,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = appThemeNotifier.value;
    final isDark = theme.isDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: U.border.withValues(alpha: 0.7),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : theme.primary)
                  .withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            // Stylized Centered Icon (Squircle shape with subtle gradient)
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: U.text,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: U.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 450.ms).slideY(
          begin: 0.12,
          end: 0,
          delay: delay.ms,
          duration: 450.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
