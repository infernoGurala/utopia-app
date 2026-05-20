import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../theme/image_overlay_colors.dart';
import 'daily_note_screen.dart';
import 'heatmap_home_screen.dart';
import 'profile_screen.dart';
import 'reminders_screen.dart';
import '../services/focus_supabase_service.dart';
import '../models/focus_models.dart';

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
  String _dailyNoteInsight = 'Write today';
  String _remindersInsight = 'No upcoming';


  static const _motivationalTexts = [
    'If one person believes something illogical, he is called a fool – but if ten million people believe the same illogical thing, it is called religion.',
    'It is not who you are underneath, it\'s what you do that defines you.',
    'Nothing is permanent, except change.',
    'Every day, people straighten up their hair. Why not the heart?',
    'I am not what happened to me, I am what I choose to become.',
    'When walking, walk! When eating, eat!',
    'Do what is right, not what is popular, nor what is easy.',
    'Ignorance is the mother of all evil.',
    'Regret comes from missed opportunities; discipline weighs ounces, and regret weighs tons.',
    'The more pleasure we seek, the less happy we become. ~MA',
    'Love is enough to get everything done in life; you would need power only when you want to do something harmful.',
    'You don\'t have to be great to start, but you have to start to be great.',
    'Courage isn\'t having the strength to go on, it is going on when you don\'t have the strength.',
    'Anything that makes me weak, physically, intellectually, and spiritually, I reject as poison.',
    'The cave you fear to enter holds the treasure you seek.',
    'You could be good today, instead you choose tomorrow.',
    'No one can make you upset; you choose to be.',
    'A goal without a plan is just a wish.',
    'The self is an illusion built by mental programming.',
    'The key to evolution is variation.',
    'You can\'t always control what happens, but you can control how you respond; that\'s where your power is.',
    'The only limit to our realization of tomorrow is our doubts of today.',
    'Do not wait for permission.',
    'What you are not changing, you are choosing.',
    'One good book is equal to a hundred good friends, but one good friend is equal to a library.',
    'Winners are not those who never fail but those who never quit.',
    'If you want to shine like the sun, first burn like the sun.',
    'The greatest sin is to think yourself weak.',
    'Time and tide wait for no man.',
    'The greatest disability is the mind, not the body.',
    'Don\'t think about doing the thing; do the thing.',
  ];

  String _generateRandomGreeting(String slot) {
    final List<String> variants;
    if (slot == 'morning') {
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
    } else if (slot == 'afternoon') {
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
    } else if (slot == 'evening') {
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
        'Evening, achiever',
        'You did great today',
        'Relax and reflect',
        'Cozy evening vibes',
        'Enjoy your evening rest',
        'A calm evening to you',
        'Great work today',
        'Sunset vibes are here',
      ];
    } else {
      variants = const [
        'Good night',
        'Rest well tonight',
        'Time to wind down',
        'Quiet night, sharp mind',
        'Good night, champion',
        'Sleep tight, legend',
        'Sweet dreams',
        'Late night grind?',
        'Midnight focus',
        'Working late, superstar?',
        'Time to wrap up your day',
        'Rest your eyes, legend',
        'Sleep is the best meditation',
        'Peaceful dreams ahead',
        'Unwind and recharge',
        'Still awake, champion?',
        'Stars are shining, rest well',
        'Cozy night vibes',
      ];
    }
    final now = DateTime.now();
    final dayIndex = now.difference(DateTime(now.year)).inDays;
    final seed = dayIndex + now.hour;
    final index = seed % variants.length;
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
    final day = DateTime.now().day;
    return _motivationalTexts[(day - 1) % _motivationalTexts.length];
  }

  // Obsolete getters removed. Background and overlay colors are now calculated atomically in build()

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
      _loadStats();
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

  DateTime? _getNextOccurrence(FocusReminder r, DateTime now) {
    final timeParts = r.reminderTime.split(':');
    if (timeParts.length < 2) return null;
    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    if (r.type == 'one_time') {
      if (r.remindDate == null) return null;
      final dateParts = r.remindDate!.split('-');
      if (dateParts.length < 3) return null;
      final year = int.tryParse(dateParts[0]) ?? 0;
      final month = int.tryParse(dateParts[1]) ?? 0;
      final day = int.tryParse(dateParts[2]) ?? 0;
      final scheduled = DateTime(year, month, day, hour, minute);
      if (scheduled.isAfter(now)) return scheduled;
      return null;
    } else if (r.type == 'weekly') {
      if (r.weekdays == null || r.weekdays!.isEmpty) return null;
      for (int i = 0; i < 8; i++) {
        final candidateDate = now.add(Duration(days: i));
        final candidateWeekday = candidateDate.weekday - 1; // 0=Mon...6=Sun
        if (r.weekdays!.contains(candidateWeekday)) {
          final scheduled = DateTime(candidateDate.year, candidateDate.month, candidateDate.day, hour, minute);
          if (scheduled.isAfter(now)) return scheduled;
        }
      }
    } else if (r.type == 'monthly_date') {
      if (r.monthDay == null) return null;
      final thisMonthScheduled = DateTime(now.year, now.month, r.monthDay!, hour, minute);
      if (thisMonthScheduled.isAfter(now)) return thisMonthScheduled;
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      return DateTime(nextYear, nextMonth, r.monthDay!, hour, minute);
    }
    return null;
  }

  Future<void> _loadStats() async {
    try {
      final tasks = await _service.getAllTrackedTasks();
      final activeTasks = tasks.length;

      // 1. Get today's habits remaining
      String dailyNoteInsight = 'Write today';
      try {
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final note = await _service.getLocalNote(todayStr);
        final userHabits = await _service.getLocalUserHabits();
        
        final habitsList = userHabits?.habits ?? [];
        if (habitsList.isEmpty) {
          dailyNoteInsight = 'No habits configured';
        } else {
          int doneCount = 0;
          if (note != null && note.habitsState.isNotEmpty) {
            for (final h in note.habitsState.keys) {
              if (note.habitsState[h] == true && habitsList.contains(h)) {
                doneCount++;
              }
            }
          }
          final left = habitsList.length - doneCount;
          if (left <= 0) {
            dailyNoteInsight = 'All habits completed! 🎉';
          } else {
            dailyNoteInsight = '$left habits remaining';
          }
        }
      } catch (e) {
        debugPrint('FocusScreen daily note insight load failed: $e');
      }

      // 2. Get next upcoming reminder
      String remindersInsight = 'No reminders';
      int reminderCount = 0;
      try {
        final reminders = await _service.getReminders();
        final activeReminders = reminders.where((r) => r.isActive).toList();
        reminderCount = activeReminders.length;

        if (activeReminders.isEmpty) {
          remindersInsight = 'All clear! No tasks';
        } else {
          final now = DateTime.now();
          final List<MapEntry<FocusReminder, DateTime>> futureReminders = [];

          for (final r in activeReminders) {
            final nextOccur = _getNextOccurrence(r, now);
            if (nextOccur != null) {
              futureReminders.add(MapEntry(r, nextOccur));
            }
          }

          if (futureReminders.isEmpty) {
            remindersInsight = 'All clear for today';
          } else {
            // Sort by next occurrence ascending
            futureReminders.sort((a, b) => a.value.compareTo(b.value));
            
            final nextEntry = futureReminders.first;
            final nextReminder = nextEntry.key;
            final nextDt = nextEntry.value;

            // Format display
            final todayDate = DateTime(now.year, now.month, now.day);
            final occurrenceDate = DateTime(nextDt.year, nextDt.month, nextDt.day);
            final difference = occurrenceDate.difference(todayDate).inDays;

            final hr = nextDt.hour;
            final min = nextDt.minute.toString().padLeft(2, '0');
            final ampm = hr >= 12 ? 'PM' : 'AM';
            final displayHr = hr == 0 ? 12 : (hr > 12 ? hr - 12 : hr);
            final formattedTime = '$displayHr:$min $ampm';

            const weekdaysList = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            String dayLabel = '';
            if (difference == 0) {
              dayLabel = 'Today, $formattedTime';
            } else if (difference == 1) {
              dayLabel = 'Tomorrow, $formattedTime';
            } else {
              dayLabel = '${weekdaysList[nextDt.weekday - 1]}, $formattedTime';
            }

            remindersInsight = '$dayLabel: ${nextReminder.label}';
          }
        }
      } catch (e) {
        debugPrint('FocusScreen reminders insight load failed: $e');
      }

      if (mounted) {
        setState(() {
          _activeHabits = activeTasks;
          _upcomingReminders = reminderCount;
          _dailyNoteInsight = dailyNoteInsight;
          _remindersInsight = remindersInsight;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;

    final timeSlot = ImageOverlayColors.getTimeSlot();
    final greetingText = _generateRandomGreeting(timeSlot);
    final bgImagePath = 'assets/welcome_bg/one_light/$timeSlot.png';
    final themeKey = appThemeNotifier.value.key;
    final isDarkTheme = appThemeNotifier.value.isDark;

    final onImageTitleColor = ImageOverlayColors.titleColor(themeKey, timeSlot);
    final onImageSubtitleColor = ImageOverlayColors.subtitleColor(themeKey, timeSlot);
    final greetingColor = ImageOverlayColors.greetingColor(themeKey, timeSlot) ?? U.text;
    final motivationalColor = ImageOverlayColors.quoteColor(themeKey, timeSlot) ?? U.sub;

    final isDarkSky = timeSlot == 'evening' || timeSlot == 'night';
    final useLightStatusBarIcons = isDarkSky || isDarkTheme;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightStatusBarIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness: useLightStatusBarIcons ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightStatusBarIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness: useLightStatusBarIcons ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
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
              bgImagePath,
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
                                    style: TextStyle(
                                      fontFamily: 'OrangeAvenue',
                                      fontSize: 42,
                                      fontWeight: FontWeight.w700,
                                      color: onImageTitleColor,
                                      letterSpacing: -0.5,
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
                                          color: onImageTitleColor,
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
                                  color: onImageSubtitleColor,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
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
                                  color: greetingColor.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userName.isEmpty ? greetingText : '$greetingText, $_userName',
                                      style: GoogleFonts.tiroGurmukhi(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w500,
                                        color: greetingColor,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _motivationalText,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: motivationalColor,
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
                                statLabel: _dailyNoteInsight,
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
                                statLabel: _remindersInsight,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
