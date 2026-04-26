import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import 'attendance_screen.dart';
import 'friends_screen.dart';
import 'map_screen.dart';

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
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'University',
                style: GoogleFonts.playfairDisplay(
                  color: U.text,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: U.text.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Explore your campus network',
                style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
            ),

            const SizedBox(height: 32),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: U.primary),
                ),
              )
            else
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _UniversityCard(
                      title: 'Attendance',
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
                      icon: Icons.groups_outlined,
                      color: U.peach,
                      delay: 150,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FriendsScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Map',
                      icon: Icons.map_outlined,
                      color: U.red,
                      delay: 200,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      ),
                    ),
                    _UniversityCard(
                      title: 'Events',
                      icon: Icons.event_available_outlined,
                      color: U.sub,
                      delay: 250,
                      isComingSoon: true,
                      onTap: () {},
                    ),
                    _UniversityCard(
                      title: 'Everyone',
                      icon: Icons.public_outlined,
                      color: U.sub,
                      delay: 300,
                      isComingSoon: true,
                      onTap: () {},
                    ),
                    _UniversityCard(
                      title: 'Ask Community',
                      icon: Icons.forum_outlined,
                      color: U.teal,
                      delay: 350,
                      isComingSoon: true,
                      onTap: () {},
                    ),
                  ],
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int delay;
  final bool isComingSoon;

  const _UniversityCard({
    required this.title,
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
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isComingSoon 
                    ? U.border.withValues(alpha: 0.5)
                    : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isComingSoon ? U.dim : color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: isComingSoon ? U.dim : U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isComingSoon)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Coming Soon',
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ).animate().fadeIn(delay: delay.ms, duration: 500.ms).slideY(
            begin: 0.1,
            end: 0,
            delay: delay.ms,
            duration: 500.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
