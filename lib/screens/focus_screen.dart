import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'habit_tracker_screen.dart';
import 'reminders_screen.dart';
import 'calendar_screen.dart';
import 'rockets_screen.dart';
import '../services/focus_supabase_service.dart';
import '../models/focus_models.dart';
import '../widgets/news_brief_dashboard_card.dart';
import '../services/google_calendar_service.dart';
import '../services/calendar_cache_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _service = FocusSupabaseService();
  String _quote = '';
  int _streakDays = 0;
  int _activeHabits = 0;
  int _upcomingReminders = 0;
  String _dailyNoteInsight = 'Write today';
  String _remindersInsight = 'No upcoming';
  String _calendarInsight = 'Connect Google Account';


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
      // Start download sync in background to update local SQLite
      _service.syncDownAllData().then((_) {
        _loadStats();
        _service.getBestActiveStreak().then((info) {
          if (mounted) {
            setState(() {
              _streakDays = info?['streak'] as int? ?? 0;
            });
          }
        });
      });

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
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedQuote = prefs.getString('daily_quote_text');
      final cachedAuthor = prefs.getString('daily_quote_author');
      final cachedDate = prefs.getString('daily_quote_date');

      if (cachedQuote != null && cachedAuthor != null && cachedDate == todayStr) {
        // Today's quote is already cached. Show it immediately and skip fetching.
        if (mounted) {
          setState(() {
            _quote = '"$cachedQuote" — $cachedAuthor';
          });
        }
        return;
      }

      // If a cache exists from a previous day, show it immediately before fetching
      if (cachedQuote != null && cachedAuthor != null) {
        if (mounted) {
          setState(() {
            _quote = '"$cachedQuote" — $cachedAuthor';
          });
        }
      } else {
        // Otherwise show nothing until fetched
        if (mounted) {
          setState(() {
            _quote = '';
          });
        }
      }

      // Fetch fresh quote from ZenQuotes API
      final response = await http.get(Uri.parse('https://zenquotes.io/api/today')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && data[0] is Map) {
          final q = data[0]['q'] as String?;
          final a = data[0]['a'] as String?;
          if (q != null && a != null && q.isNotEmpty && a.isNotEmpty) {
            // Cache the fresh quote, author, and date
            await prefs.setString('daily_quote_text', q);
            await prefs.setString('daily_quote_author', a);
            await prefs.setString('daily_quote_date', todayStr);

            if (mounted) {
              setState(() {
                _quote = '"$q" — $a';
              });
            }
            return;
          }
        }
      }

      // If API fails and no cache exists at all, show hardcoded fallback
      if (cachedQuote == null || cachedAuthor == null) {
        if (mounted) {
          setState(() {
            _quote = '"Focus on progress, not perfection." — Unknown';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching/loading daily quote: $e');
      final prefs = await SharedPreferences.getInstance().catchError((_) => null);
      final cachedQuote = prefs?.getString('daily_quote_text');
      final cachedAuthor = prefs?.getString('daily_quote_author');
      if (cachedQuote == null || cachedAuthor == null) {
        if (mounted) {
          setState(() {
            _quote = '"Focus on progress, not perfection." — Unknown';
          });
        }
      }
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
      String dailyNoteInsight = 'Track today';
      try {
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final habits = await _service.getHabits(includeArchived: false);
        
        if (habits.isEmpty) {
          dailyNoteInsight = 'No habits configured';
        } else {
          int scheduledCount = 0;
          int doneCount = 0;
          
          for (final h in habits) {
            bool isScheduled = false;
            if (h.frequencyType == 'daily') {
              isScheduled = true;
            } else if (h.frequencyType == 'days_of_week') {
              if (h.daysOfWeek != null && h.daysOfWeek!.contains(today.weekday - 1)) {
                isScheduled = true;
              }
            } else {
              isScheduled = true; // Weekly, monthly, and interval checklists are active
            }
            
            if (isScheduled) {
              scheduledCount++;
              final rec = await _service.getRecord(h.id, todayStr);
              if (rec != null && rec.completed) {
                doneCount++;
              }
            }
          }
          
          if (scheduledCount == 0) {
            dailyNoteInsight = 'No habits today';
          } else {
            final left = scheduledCount - doneCount;
            if (left <= 0) {
              dailyNoteInsight = 'All habits completed! 🎉';
            } else {
              dailyNoteInsight = '$left ${left == 1 ? "habit" : "habits"} remaining';
            }
          }
        }
      } catch (e) {
        debugPrint('FocusScreen daily habits insight load failed: $e');
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

      // 3. Get today's Google Calendar events count
      String calendarInsight = 'Connect Google Account';
      try {
        final connected = await GoogleCalendarService.instance.isConnected();
        if (connected) {
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
          final events = await CalendarCacheService.instance.getEvents(
            start: startOfDay,
            end: endOfDay,
            includeHidden: false,
          );
          if (events.isEmpty) {
            calendarInsight = 'No events today';
          } else {
            calendarInsight = '${events.length} ${events.length == 1 ? "event" : "events"} scheduled today';
          }
        } else {
          calendarInsight = 'Connect Google Account';
        }
      } catch (e) {
        debugPrint('FocusScreen calendar insight load failed: $e');
      }

      if (mounted) {
        setState(() {
          _activeHabits = activeTasks;
          _upcomingReminders = reminderCount;
          _dailyNoteInsight = dailyNoteInsight;
          _remindersInsight = remindersInsight;
          _calendarInsight = calendarInsight;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;

    final isDarkTheme = appThemeNotifier.value.isDark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Header: Utopia title ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Utopia',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'OrangeAvenue',
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: U.text,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
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
                                  color: U.primary,
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stay productive.',
                        style: GoogleFonts.plusJakartaSans(
                          color: U.dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ).animate()
                      .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut),
                ),

                // ── Greeting Section (Now containing only the Daily Quote) ──
                if (_quote.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 2,
                            color: U.border,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quote,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    color: U.sub,
                                    height: 1.5,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate()
                      .fadeIn(delay: 300.ms, duration: 500.ms)
                      .slideY(begin: 0.1, end: 0, delay: 300.ms, duration: 500.ms, curve: Curves.easeOut),
                  const SizedBox(height: 28),
                ] else ...[
                  const SizedBox(height: 24),
                ],

                // ── Feature Cards (2+1 Grid) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Top row: Habit Tracker + Reminders
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              title: 'Habit Tracker',
                              description: 'Build habits.',
                              icon: Icons.event_repeat_rounded,
                              svgAsset: 'assets/icons/routine_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg',
                              iconColor: U.blue,
                              statLabel: _dailyNoteInsight,
                              statColor: U.blue,
                              delay: 400,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HabitTrackerScreen()),
                              ).then((_) => _loadData()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureCard(
                              title: 'Reminders',
                              description: 'Manage tasks.',
                              icon: Icons.alarm_on_rounded,
                              svgAsset: 'assets/icons/alarm_smart_wake_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24.svg',
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
                      Row(
                        children: [
                          Expanded(
                            child: _FeatureCard(
                              title: 'Google Calendar',
                              description: 'Manage schedule.',
                              icon: Icons.calendar_today_rounded,
                              iconColor: U.gold,
                              statLabel: _calendarInsight,
                              statColor: U.gold,
                              delay: 600,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CalendarScreen()),
                              ).then((_) => _loadData()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FeatureCard(
                              title: 'Rockets',
                              description: 'Neural TTS reading.',
                              icon: Icons.rocket_launch_rounded,
                              iconColor: U.peach,
                              statLabel: 'Active sessions',
                              statColor: U.peach,
                              delay: 700,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RocketsScreen()),
                              ).then((_) => _loadData()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Today's Brief Card ──
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: NewsBriefDashboardCard(),
                ),

                // Bottom padding for nav bar
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? svgAsset;
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
    this.svgAsset,
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
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: U.border,
            width: 0.5,
          ),
        ),
        child: cardContent,
      ),
    ).animate()
        .fadeIn(delay: delay.ms, duration: 500.ms)
        .slideY(begin: 0.12, end: 0, delay: delay.ms, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  /// Square card layout (for Daily Note, Activity)
  Widget _buildSquareLayout() {
    return SizedBox(
      height: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Arrow row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: U.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: U.border,
                    width: 0.5,
                  ),
                ),
                child: svgAsset != null
                    ? SvgPicture.asset(
                        svgAsset!,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      )
                    : Icon(icon, color: iconColor, size: 20),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: U.dim,
                size: 16,
              ),
            ],
          ),
          const Spacer(),

          // Title
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

          // Description
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: U.sub,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Stat line
          Text(
            statLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: U.dim,
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: U.border,
              width: 0.5,
            ),
          ),
          child: svgAsset != null
              ? SvgPicture.asset(
                  svgAsset!,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                )
              : Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                description.replaceAll('\n', ' '),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: U.sub,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                statLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: U.dim,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: U.dim,
          size: 16,
        ),
      ],
    );
  }
}
