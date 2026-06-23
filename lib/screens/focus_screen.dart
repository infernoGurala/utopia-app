import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/image_overlay_colors.dart';
import 'habit_tracker_screen.dart';
import 'rockets_screen.dart';
import 'attendance_screen.dart';
import 'delve/delve_shell.dart';
import '../providers/delve_theme_provider.dart';
import '../providers/delve_deck_provider.dart';
import '../providers/delve_inventory_provider.dart';
import '../providers/delve_session_provider.dart';
import 'package:intl/intl.dart';
import '../services/focus_supabase_service.dart';
import '../models/focus_models.dart';
import '../services/cache_service.dart';
import '../services/secure_storage_service.dart';
import '../services/attendance_cache_service.dart';
import '../utils/habit_calculators.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final _service = FocusSupabaseService();
  String _quote = '';
  String _greetingText = '';
  int _streakDays = 0;
  int _scheduledHabitsCount = 0;
  int _completedHabitsCount = 0;
  String _dailyNoteInsight = 'Write today';
  String _delveInsight = 'Start learning intelligence words';

  String _streakHabitId = '';
  String _streakHabitName = '';
  double? _attendancePct;

  String _weatherCity = '';
  double? _weatherTemp;
  int? _weatherCode;

  String get _userName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final name = user.displayName;
    if (name == null || name.isEmpty) return '';
    return name.split(' ')[0];
  }

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

  @override
  void initState() {
    super.initState();
    final timeSlot = ImageOverlayColors.getTimeSlot();
    final greetingText = _generateRandomGreeting(timeSlot);
    final userNameStr = _userName;
    _greetingText = userNameStr.isEmpty ? greetingText : '$greetingText, $userNameStr';
    _loadCachedStreakHabit();
    _loadCachedWeather();
    _loadData();
    _loadQuote();
  }

  Future<void> _loadCachedStreakHabit() async {
    try {
      final habitId = await CacheService().getAppSetting('streak_habit_id');
      final habitName = await CacheService().getAppSetting('streak_habit_name');
      if (mounted) {
        setState(() {
          _streakHabitId = habitId ?? '';
          _streakHabitName = habitName ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading cached streak habit: $e');
    }
  }

  Future<void> _loadCachedWeather() async {
    try {
      final city = await CacheService().getAppSetting('weather_city');
      final tempStr = await CacheService().getAppSetting('weather_temp');
      final codeStr = await CacheService().getAppSetting('weather_code');
      if (mounted) {
        setState(() {
          _weatherCity = city ?? (U.cachedUniversityName.isNotEmpty ? U.cachedUniversityName : 'Kakinada');
          if (tempStr != null) _weatherTemp = double.tryParse(tempStr);
          if (codeStr != null) _weatherCode = int.tryParse(codeStr);
        });
      }
    } catch (e) {
      debugPrint('Error loading cached weather: $e');
    }
  }

  Future<void> _fetchWeather() async {
    if (_weatherCity.isEmpty) return;
    try {
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(_weatherCity)}&count=1&language=en&format=json',
      );
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final first = results.first;
          final lat = first['latitude'];
          final lon = first['longitude'];
          final name = first['name'] as String? ?? _weatherCity;

          final weatherUrl = Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
          );
          final weatherRes = await http.get(weatherUrl);
          if (weatherRes.statusCode == 200) {
            final weatherData = jsonDecode(weatherRes.body);
            final current = weatherData['current_weather'];
            if (current != null) {
              final temp = (current['temperature'] as num?)?.toDouble();
              final code = current['weathercode'] as int?;

              if (mounted) {
                setState(() {
                  _weatherTemp = temp;
                  _weatherCode = code;
                  _weatherCity = name;
                });
              }

              await CacheService().saveAppSetting('weather_city', name);
              if (temp != null) {
                await CacheService().saveAppSetting('weather_temp', temp.toString());
              }
              if (code != null) {
                await CacheService().saveAppSetting('weather_code', code.toString());
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  IconData _getWeatherIcon(int? code) {
    if (code == null) return Icons.thermostat_rounded;
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code >= 1 && code <= 3) return Icons.wb_cloudy_rounded;
    if (code == 45 || code == 48) return Icons.cloud_rounded;
    if (code >= 51 && code <= 55) return Icons.grain_rounded;
    if (code >= 61 && code <= 65) return Icons.umbrella_rounded;
    if (code >= 71 && code <= 75) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.thermostat_rounded;
  }

  void _showWeatherCityPicker() {
    final controller = TextEditingController(text: _weatherCity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: U.border, width: 0.5),
        ),
        title: Text(
          'Set Weather Location',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(color: U.text),
          decoration: InputDecoration(
            labelText: 'City Name',
            labelStyle: GoogleFonts.plusJakartaSans(color: U.sub),
            hintText: 'e.g. Kakinada, Surampalem',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: U.sub),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final newCity = controller.text.trim();
              if (newCity.isNotEmpty) {
                setState(() {
                  _weatherCity = newCity;
                });
                Navigator.pop(ctx);
                await CacheService().saveAppSetting('weather_city', newCity);
                _fetchWeather();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showStreakHabitPicker() async {
    final habits = await _service.getHabits(includeArchived: false);
    if (habits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please create a habit first in the Habit Tracker!')),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Habit for Streak',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: habits.length,
                itemBuilder: (context, index) {
                  final h = habits[index];
                  final isSelected = h.id == _streakHabitId;
                  return ListTile(
                    title: Text(
                      h.name,
                      style: GoogleFonts.plusJakartaSans(
                        color: U.text,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check, color: U.primary) : null,
                    onTap: () async {
                      setState(() {
                        _streakHabitId = h.id;
                        _streakHabitName = h.name;
                      });
                      Navigator.pop(ctx);
                      await CacheService().saveAppSetting('streak_habit_id', h.id);
                      await CacheService().saveAppSetting('streak_habit_name', h.name);
                      _loadStats();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      await _service.initialize();
      // Start download sync in background to update local SQLite
      _service.syncDownAllData().then((_) {
        _loadStats();
        _fetchWeather();
      });
      _loadStats();
      _fetchWeather();
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
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedQuote = prefs.getString('daily_quote_text');
        final cachedAuthor = prefs.getString('daily_quote_author');
        if (cachedQuote == null || cachedAuthor == null) {
          if (mounted) {
            setState(() {
              _quote = '"Focus on progress, not perfection." — Unknown';
            });
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _quote = '"Focus on progress, not perfection." — Unknown';
          });
        }
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      int totalHabits = 0;
      int completedHabits = 0;

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
          
          totalHabits = scheduledCount;
          completedHabits = doneCount;

          if (scheduledCount == 0) {
            dailyNoteInsight = 'No habits today';
          } else {
            final left = scheduledCount - doneCount;
            if (left <= 0) {
              dailyNoteInsight = 'All habits completed!';
            } else {
              dailyNoteInsight = '$left ${left == 1 ? "habit" : "habits"} remaining';
            }
          }
        }
      } catch (e) {
        debugPrint('FocusScreen daily habits insight load failed: $e');
      }

      // Calculate streak for chosen habit
      try {
        final habits = await _service.getHabits(includeArchived: false);
        if (habits.isNotEmpty) {
          String targetHabitId = _streakHabitId;
          if (targetHabitId.isEmpty) {
            targetHabitId = habits.first.id;
            _streakHabitId = targetHabitId;
            _streakHabitName = habits.first.name;
            await CacheService().saveAppSetting('streak_habit_id', targetHabitId);
            await CacheService().saveAppSetting('streak_habit_name', _streakHabitName);
          }

          final chosenHabit = habits.firstWhere(
            (h) => h.id == targetHabitId,
            orElse: () => habits.first,
          );

          final records = await _service.getRecordsForHabit(chosenHabit.id);
          final streak = HabitCalculators.calculateCurrentStreak(chosenHabit, records);
          
          if (mounted) {
            setState(() {
              _streakDays = streak;
              _streakHabitId = chosenHabit.id;
              _streakHabitName = chosenHabit.name;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _streakDays = 0;
              _streakHabitId = '';
              _streakHabitName = 'No Habits';
            });
          }
        }
      } catch (e) {
        debugPrint('Error calculating custom streak: $e');
      }

      // Load attendance percentage
      double? attendancePct;
      try {
        final credentials = await SecureStorageService.getCredentials();
        if (credentials != null) {
          final roll = credentials['rollNumber'];
          if (roll != null) {
            final cachedAttendance = await AttendanceCacheService.load(roll);
            if (cachedAttendance != null) {
              attendancePct = cachedAttendance.data['overallPercentage'] as double?;
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading cached attendance: $e');
      }

      // 2. Get Delve vocabulary learning insight
      String delveInsight = 'Start learning intelligence words';
      try {
        final prefs = await SharedPreferences.getInstance();
        final deckString = prefs.getString('delve_active_deck');
        if (deckString != null) {
          final deckMap = jsonDecode(deckString);
          final currentDay = deckMap['currentDay'] as int? ?? 1;
          final lastSessionDateStr = deckMap['lastSessionDate'] as String?;
          bool completedToday = false;
          if (lastSessionDateStr != null) {
            final lastSessionDate = DateTime.parse(lastSessionDateStr);
            final now = DateTime.now();
            completedToday = lastSessionDate.year == now.year &&
                lastSessionDate.month == now.month &&
                lastSessionDate.day == now.day;
          }
          if (completedToday) {
            delveInsight = 'Day $currentDay completed today!';
          } else {
            delveInsight = 'Day $currentDay: Session is waiting';
          }
        } else {
          final inventoryString = prefs.getString('delve_inventory');
          int wordCount = 0;
          if (inventoryString != null) {
            final List<dynamic> jsonList = jsonDecode(inventoryString);
            wordCount = jsonList.length;
          }
          if (wordCount < 15) {
            delveInsight = 'Need ${15 - wordCount} more words to start deck';
          } else {
            delveInsight = '15+ words ready! Begin Day 1';
          }
        }
      } catch (e) {
        debugPrint('FocusScreen Delve insight load failed: $e');
      }

      if (mounted) {
        setState(() {
          _scheduledHabitsCount = totalHabits;
          _completedHabitsCount = completedHabits;
          _dailyNoteInsight = dailyNoteInsight;
          _delveInsight = delveInsight;
          _attendancePct = attendancePct;
        });
      }
    } catch (_) {}
  }

  Widget _buildQuickPill({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = appThemeNotifier.value.isDark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? color.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isDark ? color.withValues(alpha: 0.95) : color.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? color.withValues(alpha: 0.95) : color.withValues(alpha: 0.85),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = appThemeNotifier.value.isDark;
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateStr = '${weekdays[now.weekday - 1].toUpperCase()}, ${months[now.month].toUpperCase()} ${now.day}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Header: Utopia brand identity & Date ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Utopia',
                              style: TextStyle(
                                fontFamily: 'OrangeAvenue',
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                color: U.text,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: U.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: U.primary.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            dateStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: U.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Greeting text
                    (() {
                      final commaIndex = _greetingText.indexOf(',');
                      if (commaIndex != -1) {
                        final greetingPart = _greetingText.substring(0, commaIndex);
                        final namePart = _greetingText.substring(commaIndex + 1).trim();
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$greetingPart, ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                  color: U.text,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              TextSpan(
                                text: namePart,
                                style: GoogleFonts.outfit(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: U.text,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return Text(
                          _greetingText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            color: U.text,
                            letterSpacing: -0.4,
                          ),
                        );
                      }
                    })(),
                    if (_quote.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: U.primary.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Text(
                          _quote,
                          style: GoogleFonts.newsreader(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: U.sub,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
                  .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 18),

              // ── Inline Metric Quick Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildQuickPill(
                        label: _streakHabitName.isNotEmpty && _streakHabitName != 'No Habits'
                            ? '$_streakDays Day $_streakHabitName Streak'
                            : '$_streakDays Day Streak',
                        icon: Icons.local_fire_department_rounded,
                        color: U.peach,
                        onTap: _showStreakHabitPicker,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        label: _attendancePct != null
                            ? '${_attendancePct!.toStringAsFixed(0)}% Attendance'
                            : 'Connect Attendance',
                        icon: Icons.bar_chart_rounded,
                        color: U.green,
                        onTap: () {
                          navigatorKey.currentState?.push(
                            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                          ).then((_) => _loadStats());
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickPill(
                        label: _weatherTemp != null
                            ? '${_weatherTemp!.toStringAsFixed(0)}°C $_weatherCity'
                            : 'Set Location',
                        icon: _getWeatherIcon(_weatherCode),
                        color: U.lavender,
                        onTap: _showWeatherCityPicker,
                      ),
                    ],
                  ),
                ),
              ).animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, delay: 150.ms, duration: 400.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 20),

              // ── Habit Progress Hero Card (Wide) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PressableCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HabitTrackerScreen()),
                  ).then((_) => _loadData()),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: U.border.withValues(alpha: 0.8),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: U.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.event_repeat_rounded,
                                      color: U.green,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'DAILY ROUTINES',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: U.green.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Habit Tracker',
                                style: GoogleFonts.newsreader(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: U.text,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _dailyNoteInsight,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: U.sub,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _scheduledHabitsCount > 0
                                      ? _completedHabitsCount / _scheduledHabitsCount
                                      : 0.0,
                                  backgroundColor: U.surface,
                                  valueColor: AlwaysStoppedAnimation<Color>(U.green),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        (() {
                          final pct = _scheduledHabitsCount > 0
                              ? _completedHabitsCount / _scheduledHabitsCount
                              : 0.0;
                          return SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 76,
                                  height: 76,
                                  child: CircularProgressIndicator(
                                    value: pct,
                                    backgroundColor: U.surface,
                                    color: U.green,
                                    strokeWidth: 7,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: U.green.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${(pct * 100).toInt()}%',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: U.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })(),
                      ],
                    ),
                  ),
                ),
              ).animate()
                  .fadeIn(delay: 250.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, delay: 250.ms, duration: 500.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // ── Rockets & Delve Project Side-by-Side ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 225,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Rockets Reader Card
                      Expanded(
                        child: PressableCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RocketsScreen()),
                          ).then((_) => _loadData()),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: U.card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: U.border.withValues(alpha: 0.8),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Accent edge
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          U.peach.withValues(alpha: 0.0),
                                          U.peach,
                                          U.peach.withValues(alpha: 0.0),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: U.peach.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.rocket_launch_rounded,
                                              color: U.peach,
                                              size: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'READ ALOUD',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                                color: U.peach.withValues(alpha: 0.85),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Rockets Reader',
                                        style: GoogleFonts.newsreader(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          color: U.text,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 10,
                                            color: U.peach.withValues(alpha: 0.6),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Neural AI TTS',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                color: U.sub,
                                                letterSpacing: 0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 76,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: U.peach.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(height: 4),
                                            AnimatedWaveform(color: U.peach),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [U.peach, U.peach.withValues(alpha: 0.8)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: U.peach.withValues(alpha: 0.25),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                'Listen',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: appThemeNotifier.value.isDark
                                                      ? const Color(0xFF0B0612)
                                                      : Colors.white,
                                                ),
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Delve Project Card
                      Expanded(
                        child: PressableCard(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: U.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Beta Feature',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: U.text,
                                      ),
                                    ),
                                  ],
                                ),
                                content: Text(
                                  'This feature is currently in beta and we do not recommend using it. It may contain bugs, incomplete functionality, or unexpected behavior.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: U.sub,
                                    height: 1.5,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      'Go Back',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: U.sub,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MultiProvider(
                                            providers: [
                                              ChangeNotifierProvider(create: (_) => DelveThemeProvider()),
                                              ChangeNotifierProvider(
                                                create: (_) {
                                                  final provider = InventoryProvider();
                                                  final user = FirebaseAuth.instance.currentUser;
                                                  if (user != null) {
                                                    provider.initForUser(user.uid);
                                                  }
                                                  return provider;
                                                },
                                              ),
                                              ChangeNotifierProvider(
                                                create: (_) {
                                                  final provider = DeckProvider();
                                                  final user = FirebaseAuth.instance.currentUser;
                                                  if (user != null) {
                                                    provider.initForUser(user.uid);
                                                  }
                                                  return provider;
                                                },
                                              ),
                                              ChangeNotifierProvider(create: (_) => SessionProvider()),
                                            ],
                                            child: const DelveShell(),
                                          ),
                                        ),
                                      ).then((_) => _loadData());
                                    },
                                    child: Text(
                                      'Continue Anyway',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: U.card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: U.border.withValues(alpha: 0.8),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDarkTheme ? 0.2 : 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Accent edge
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  height: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          U.teal.withValues(alpha: 0.0),
                                          U.teal,
                                          U.teal.withValues(alpha: 0.0),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: U.teal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.spa_rounded,
                                              color: U.teal,
                                              size: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'DELVE',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                                color: U.teal.withValues(alpha: 0.85),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [U.teal, U.teal.withValues(alpha: 0.7)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'BETA',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w800,
                                                color: appThemeNotifier.value.isDark
                                                    ? const Color(0xFF0B0612)
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Delve Project',
                                        style: GoogleFonts.newsreader(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          color: U.text,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          _delveInsight,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: U.sub,
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 76,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: U.teal.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  U.teal.withValues(alpha: 0.15),
                                                  U.teal.withValues(alpha: 0.08),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.menu_book_rounded,
                                              color: U.teal.withValues(alpha: 0.85),
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0, delay: 400.ms, duration: 500.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: 140),
            ],
          ),
        ),
      ),
    );
  }
}

class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;

  const PressableCard({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.97,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class AnimatedWaveform extends StatefulWidget {
  final Color color;
  const AnimatedWaveform({super.key, required this.color});

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final heights = [0.35, 0.75, 0.5, 0.95, 0.65, 0.45, 0.25];
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(7, (index) {
            final animatedVal = _controller.value;
            final shift = sin((animatedVal * 2 * pi) + (index * 0.8));
            final currentHeight = 10.0 + 18.0 * heights[index] * (shift + 1.2);
            return Container(
              width: 3.5,
              height: currentHeight.clamp(4.0, 32.0),
              margin: const EdgeInsets.symmetric(horizontal: 1.8),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
