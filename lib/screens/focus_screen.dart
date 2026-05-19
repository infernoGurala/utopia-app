import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../theme/image_overlay_colors.dart';
import 'daily_note_screen.dart';
import 'heatmap_home_screen.dart';
import 'profile_screen.dart';
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
  late final String _greetingText;

  static const _motivationalTexts = [
    'Small steps every day\nlead to big change.',
    'Discipline is the bridge\nbetween goals and success.',
    'Today is a new opportunity\nto grow stronger.',
    'Consistency beats intensity.\nKeep showing up.',
    'Your future self will\nthank you for this.',
    'Progress, not perfection,\nis what matters.',
  ];

  String _generateRandomGreeting() {
    final time = DateTime.now().hour + DateTime.now().minute / 60.0;
    final List<String> variants;
    if (time >= 5.0 && time < 11.5) {
      variants = const [
        'Rise and shine',
        'Good morning',
        'Top of the morning',
        'Have a beautiful morning',
        'Wishing you a bright morning',
        'Wake up and conquer',
        'Hello, early bird',
        'A fresh start today',
        'Time to shine',
        'Good morning, champion',
        'Hope your day starts great',
        'Good morning, legend',
        'Start with a smile',
        'Embrace the fresh day',
        'Morning, superstar',
        'Ready for a great day?',
        'A beautiful morning to you',
        'Make today count',
        'Rise up and thrive',
        'Hello there, sunshine',
      ];
    } else if (time >= 11.5 && time < 16.0) {
      variants = const [
        'Good afternoon',
        'Hope your afternoon is great',
        'Good afternoon, legend',
        'Happy midday',
        'Keep going strong',
        'Crushing your day?',
        'Stay focused this afternoon',
        'A wonderful afternoon to you',
        'Enjoy this beautiful afternoon',
        'Afternoon, superstar',
        'Halfway to your goals',
        'Keep up the great momentum',
        'Midday motivation is here',
        'Hope your day is productive',
        'Taking a breath?',
        'Good afternoon, champion',
        'Stay energized',
        'Make the rest of the day count',
        'Afternoon, early achiever',
        'Doing amazing things today',
      ];
    } else {
      variants = const [
        'Good evening',
        'Hope you had a great day',
        'Good evening, legend',
        'Unwind and relax',
        'Time to ease into the evening',
        'A peaceful evening to you',
        'Evening, superstar',
        'Reflect on today\'s wins',
        'Hope your evening is cozy',
        'Good evening, champion',
        'Time to recharge',
        'Rest well tonight',
        'Evening, achiever',
        'You did great today',
        'Relax and reflect',
        'Cozy evening vibes',
        'Enjoy your evening rest',
        'A calm evening to you',
        'Great work today',
        'Sunset vibes are here',
      ];
    }
    final index = DateTime.now().microsecondsSinceEpoch % variants.length;
    return variants[index];
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

  String get _bgImagePath {
    final time = DateTime.now().hour + DateTime.now().minute / 60.0;
    
    String timeSlot;
    if (time >= 5.0 && time < 11.5) {
      timeSlot = 'morning';
    } else if (time >= 11.5 && time < 16.0) {
      timeSlot = 'afternoon';
    } else if (time >= 16.0 && time < 18.5) {
      timeSlot = 'evening';
    } else {
      timeSlot = 'night';
    }

    return 'assets/welcome_bg/one_light/$timeSlot.png';
  }

  Color get _onImageTitleColor =>
      ImageOverlayColors.titleColor(appThemeNotifier.value.key);

  Color get _onImageSubtitleColor =>
      ImageOverlayColors.subtitleColor(appThemeNotifier.value.key);

  Color get _greetingColor =>
      ImageOverlayColors.greetingColor(appThemeNotifier.value.key) ?? U.text;

  Color get _motivationalColor =>
      ImageOverlayColors.quoteColor(appThemeNotifier.value.key) ?? U.sub;

  @override
  void initState() {
    super.initState();
    _greetingText = _generateRandomGreeting();
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
      backgroundColor: U.bg,
      body: Stack(
        children: [
          // ── Background Image ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.80,
            child: Image.asset(
              _bgImagePath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // ── Gradient: top half clear, bottom half smooth fade ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    U.bg.withValues(alpha: 0.0),
                    U.bg.withValues(alpha: 0.0),
                    U.bg,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Utopia',
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w700,
                                      color: _onImageTitleColor,
                                      fontStyle: FontStyle.italic,
                                      letterSpacing: -1.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 0),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Transform.rotate(
                                      angle: 30 * 3.1415926535 / 180,
                                      child: Transform.scale(
                                        scaleX: -1,
                                        child: Image.asset(
                                          'assets/focus screen/leaves.png',
                                          width: 22,
                                          height: 22,
                                          fit: BoxFit.contain,
                                          color: _onImageTitleColor,
                                          colorBlendMode: BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Stay productive and track your habits',
                                style: GoogleFonts.outfit(
                                  color: _onImageSubtitleColor,
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
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              opaque: false,
                              pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                final slideAnimation = Tween<Offset>(
                                  begin: const Offset(0.0, 0.12),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                                final fadeAnimation = Tween<double>(
                                  begin: 0.0,
                                  end: 1.0,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOut,
                                  ),
                                );
                                return FadeTransition(
                                  opacity: fadeAnimation,
                                  child: SlideTransition(
                                    position: slideAnimation,
                                    child: child,
                                  ),
                                );
                              },
                              transitionDuration: const Duration(milliseconds: 380),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Animated Energy Ring
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      U.primary.withValues(alpha: 0.0),
                                      U.primary,
                                      U.primary.withValues(alpha: 0.0),
                                    ],
                                    stops: const [0.1, 0.5, 0.9],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: U.primary.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ).animate(onPlay: (controller) => controller.repeat()).rotate(duration: 3.seconds),

                              // Inner Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: U.bg.withValues(alpha: 0.6), // Subtle inner separator
                                    width: 1.5,
                                  ),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: U.card,
                                  backgroundImage: _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                                      ? CachedNetworkImageProvider(_userPhotoUrl!)
                                      : null,
                                  child: _userPhotoUrl == null || _userPhotoUrl!.isEmpty
                                      ? Icon(Icons.person, color: U.dim, size: 24)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ).animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), delay: 200.ms, duration: 500.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),

                  // ── Greeting Section ──
                  SizedBox(height: screenHeight * 0.18),
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          // A very faint gradient to smooth out the text area without hard edges
                          gradient: LinearGradient(
                            colors: [
                              U.surface.withValues(alpha: 0.0),
                              U.surface.withValues(alpha: appThemeNotifier.value.isDark ? 0.2 : 0.15),
                              U.surface.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: _greetingColor.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userName.isEmpty ? _greetingText : '$_greetingText, $_userName',
                                      style: GoogleFonts.tiroGurmukhi(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w500,
                                        color: _greetingColor,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _motivationalText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: _motivationalColor,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate()
                            .fadeIn(delay: 300.ms, duration: 600.ms)
                            .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 600.ms, curve: Curves.easeOut),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Feature Cards (2+1 Grid) ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Top row: Daily Note + Reminders
                        Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                title: 'Daily Note',
                                description: 'Write your thoughts\nand ideas',
                                icon: Icons.edit_note_rounded,
                                iconColor: U.blue,
                                statLabel: 'Write today',
                                statColor: U.blue,
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
                                title: 'Reminders',
                                description: 'Stay on top of your\nimportant tasks',
                                icon: Icons.notifications_outlined,
                                iconColor: U.lavender,
                                statLabel: '$_upcomingReminders upcoming',
                                statColor: U.lavender,
                                delay: 500,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                                ).then((_) => _loadData()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Bottom row: Activity (full width)
                        _FeatureCard(
                          title: 'Activity',
                          description: 'Track your habits\nand progress',
                          icon: Icons.grid_view_rounded,
                          iconColor: U.peach,
                          statLabel: '$_activeHabits habits active',
                          statColor: U.peach,
                          delay: 600,
                          isWide: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HeatmapHomeScreen()),
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
                        color: U.surface.withValues(alpha: appThemeNotifier.value.isDark ? 0.4 : 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: U.border.withValues(alpha: 0.5),
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
                              color: U.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: U.primary.withValues(alpha: 0.7),
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
                                    color: U.text,
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
                                    color: U.sub,
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
                                color: U.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: U.border, width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Day $_streakDays',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: U.text,
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
              color: U.surface.withValues(alpha: appThemeNotifier.value.isDark ? 0.4 : 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: U.border.withValues(alpha: appThemeNotifier.value.isDark ? 0.3 : 0.7),
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
                  color: iconColor.withValues(alpha: appThemeNotifier.value.isDark ? 0.22 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: iconColor.withValues(alpha: appThemeNotifier.value.isDark ? 0.35 : 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: U.text.withValues(alpha: 0.8),
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
              color: U.text,
            ),
          ),
          const SizedBox(height: 3),

          // Description
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: U.sub,
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
            color: iconColor.withValues(alpha: appThemeNotifier.value.isDark ? 0.22 : 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: iconColor.withValues(alpha: appThemeNotifier.value.isDark ? 0.35 : 0.25),
              width: 1,
            ),
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
                  color: U.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description.replaceAll('\n', ' '),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: U.sub,
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
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.chevron_right_rounded,
            color: U.text.withValues(alpha: 0.8),
            size: 16,
          ),
        ),
      ],
    );
  }
}
