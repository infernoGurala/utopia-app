import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'daily_note_screen.dart';
import 'heatmap_home_screen.dart';
import 'reminders_screen.dart';
import '../services/focus_supabase_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _service = FocusSupabaseService();
  String _quote = '"Focus on progress, not perfection."';
  final String _quoteSubtitle = 'Every small step moves you forward.';
  int _streakDays = 0;
  int _activeHabits = 0;
  int _upcomingReminders = 0;

  static const _motivationalTexts = [
    'Small steps every day\nlead to big change.',
    'Discipline is the bridge\nbetween goals and success.',
    'Today is a new opportunity\nto grow stronger.',
    'Consistency beats intensity.\nKeep showing up.',
    'Your future self will\nthank you for this.',
    'Progress, not perfection,\nis what matters.',
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final name = user.displayName ?? '';
    if (name.isEmpty) return '';
    return name.split(' ').first;
  }

  String? get _userPhotoUrl {
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  String get _motivationalText {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return _motivationalTexts[dayOfYear % _motivationalTexts.length];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadQuote();
    _loadStats();
  }

  Future<void> _loadData() async {
    try {
      await _service.initialize();
      final info = await _service.getBestActiveStreak();
      if (mounted) {
        setState(() {
          _streakDays = info?['streak'] as int? ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadQuote() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('quotes')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['quotes'] is List && (data['quotes'] as List).isNotEmpty) {
          final quotes = (data['quotes'] as List).map((e) => e.toString()).toList();
          final dayIndex = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
          final selectedQuote = quotes[dayIndex % quotes.length];
          if (mounted) {
            setState(() {
              _quote = '"$selectedQuote"';
            });
          }
        }
      }
    } catch (_) {
      // Use default quote
    }
  }

  Future<void> _loadStats() async {
    try {
      final tasks = await _service.getAllTrackedTasks();
      final activeTasks = tasks.length;

      // Get upcoming reminders count
      int reminderCount = 0;
      try {
        final reminders = await _service.getReminders();
        reminderCount = reminders.where((r) => r.isActive).length;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _activeHabits = activeTasks;
          _upcomingReminders = reminderCount;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F1F6),
      body: Stack(
        children: [
          // ── Background Image ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.58,
            child: Image.asset(
              'assets/welcome_bg/one_light/morning.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // ── Gradient overlay for readability at bottom of image ──
          Positioned(
            top: screenHeight * 0.35,
            left: 0,
            right: 0,
            height: screenHeight * 0.25,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFFF0F1F6).withValues(alpha: 0.6),
                    const Color(0xFFF0F1F6).withValues(alpha: 0.95),
                    const Color(0xFFF0F1F6),
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // ── Background below image ──
          Positioned(
            top: screenHeight * 0.58,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(color: const Color(0xFFF0F1F6)),
          ),

          // ── Main scrollable content ──
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: topPadding + 16),

                  // ── Header: Utopia title + Profile Avatar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Utopia',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A2E),
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stay productive and track your habits',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF555577),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ).animate()
                              .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                              .slideY(begin: 0.15, end: 0, duration: 600.ms, curve: Curves.easeOut),
                        ),

                        // Profile Avatar
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFE8E8F0),
                              backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                                  ? NetworkImage(_userPhotoUrl!)
                                  : null,
                              child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                                  ? Icon(Icons.person, color: const Color(0xFF888899), size: 24)
                                  : null,
                            ),
                          ),
                        ).animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),

                  // ── Greeting Section ──
                  SizedBox(height: screenHeight * 0.2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, $_userName',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _motivationalText,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF555577),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ).animate()
                        .fadeIn(delay: 300.ms, duration: 600.ms)
                        .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 600.ms, curve: Curves.easeOut),
                  ),

                  const SizedBox(height: 28),

                  // ── Feature Cards (2+1 Grid) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Top row: Daily Note + Activity
                        Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                title: 'Daily Note',
                                description: 'Write your thoughts\nand ideas',
                                icon: Icons.edit_note_rounded,
                                iconColor: const Color(0xFF4078F2),
                                statLabel: 'Write today',
                                statColor: const Color(0xFF4078F2),
                                delay: 400,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DailyNoteScreen()),
                                ).then((_) => _loadData()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _FeatureCard(
                                title: 'Activity',
                                description: 'Track your habits\nand progress',
                                icon: Icons.grid_view_rounded,
                                iconColor: const Color(0xFFE88A2A),
                                statLabel: '$_activeHabits habits active',
                                statColor: const Color(0xFFE88A2A),
                                delay: 500,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HeatmapHomeScreen()),
                                ).then((_) => _loadData()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Bottom row: Reminders (full width)
                        _FeatureCard(
                          title: 'Reminders',
                          description: 'Stay on top of your\nimportant tasks',
                          icon: Icons.notifications_outlined,
                          iconColor: const Color(0xFF7C6AF7),
                          statLabel: '$_upcomingReminders upcoming',
                          statColor: const Color(0xFF7C6AF7),
                          delay: 600,
                          isWide: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RemindersScreen()),
                          ).then((_) => _loadData()),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Motivational Quote Card ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4078F2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: const Color(0xFF4078F2).withValues(alpha: 0.7),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quote,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFF2A2A40),
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _quoteSubtitle,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF7A7A99),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_streakDays > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5FA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Day $_streakDays',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF555577),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text('📈', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate()
                        .fadeIn(delay: 700.ms, duration: 600.ms)
                        .slideY(begin: 0.1, end: 0, delay: 700.ms, duration: 600.ms, curve: Curves.easeOut),
                  ),

                  // Bottom padding for nav bar
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String statLabel;
  final Color statColor;
  final VoidCallback onTap;
  final int delay;
  final bool isWide;

  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.statLabel,
    required this.statColor,
    required this.onTap,
    required this.delay,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = isWide ? _buildWideLayout() : _buildSquareLayout();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: cardContent,
          ),
        ),
      ),
    ).animate()
        .fadeIn(delay: delay.ms, duration: 500.ms)
        .slideY(begin: 0.12, end: 0, delay: delay.ms, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Square card layout (for Daily Note, Activity)
  Widget _buildSquareLayout() {
    return SizedBox(
      height: 175,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Arrow row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF666680),
                  size: 16,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 3),

          // Description
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: const Color(0xFF7A7A99),
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Stat line + label
          Container(
            width: 26,
            height: 2.5,
            decoration: BoxDecoration(
              color: statColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            statLabel,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Wide card layout (for Reminders – full width)
  Widget _buildWideLayout() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description.replaceAll('\n', ' '),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF7A7A99),
                  height: 1.35,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                width: 26,
                height: 2.5,
                decoration: BoxDecoration(
                  color: statColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                statLabel,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: const Color(0xFF666680),
            size: 16,
          ),
        ),
      ],
    );
  }
}
