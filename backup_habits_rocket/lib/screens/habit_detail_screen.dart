import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import '../utils/habit_calculators.dart';
import 'habit_editor_screen.dart';
import '../widgets/utopia_snackbar.dart';

class HabitDetailScreen extends StatefulWidget {
  final FocusHabit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final _service = FocusSupabaseService();
  late FocusHabit _habit;
  List<HabitRecord> _records = [];
  bool _loading = true;

  // Calendar parameters
  late DateTime _calendarMonth;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final freshHabit = await _service.getHabit(_habit.id);
      if (freshHabit != null) {
        _habit = freshHabit;
      }
      final records = await _service.getRecordsForHabit(_habit.id);
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Load habit details failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _colorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return U.primary;
    }
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatDisplayDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _toggleDateRecord(DateTime date) async {
    final dateStr = _dateStr(date);
    final existing = _records.firstWhere(
      (r) => r.date == dateStr,
      orElse: () => HabitRecord(id: '', habitId: '', userId: '', date: '', updatedAt: DateTime.now()),
    );

    if (_habit.type == 'measurable') {
      // Measurable habits should open a dialog rather than just toggles
      _showNumericalLogSheet(date, existing);
      return;
    }

    final bool currentlyCompleted = existing.id.isNotEmpty && existing.completed;
    final double newValue = currentlyCompleted ? 0.0 : 1.0;

    final updatedRecord = HabitRecord(
      id: existing.id.isEmpty ? '' : existing.id,
      habitId: _habit.id,
      userId: _userId,
      date: dateStr,
      value: newValue,
      targetValue: 1.0,
      completed: !currentlyCompleted,
      note: existing.id.isEmpty ? null : existing.note,
      syncStatus: 'pending',
      updatedAt: DateTime.now(),
    );

    await _service.saveRecord(updatedRecord);
    await _loadData();
    HapticFeedback.lightImpact();
  }

  void _showNumericalLogSheet(DateTime date, HabitRecord existing) {
    final dateStr = _dateStr(date);
    final valueController = TextEditingController(
      text: existing.id.isNotEmpty ? existing.value.toStringAsFixed(0) : '0',
    );
    final noteController = TextEditingController(text: existing.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                decoration: BoxDecoration(
                  color: U.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: U.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: U.dim.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _habit.name,
                          style: GoogleFonts.newsreader(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                            color: U.text,
                          ),
                        ),
                        Text(
                          '${date.day}/${date.month}/${date.year}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: U.sub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'LOG QUANTITY (${_habit.unit ?? 'units'})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: U.dim,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline_rounded, color: _colorFromHex(_habit.color), size: 28),
                          onPressed: () {
                            final val = double.tryParse(valueController.text) ?? 0.0;
                            if (val > 0) {
                              valueController.text = (val - 1).clamp(0.0, 99999.0).toStringAsFixed(0);
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: valueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: U.text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              fillColor: U.surface,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: _colorFromHex(_habit.color), size: 28),
                          onPressed: () {
                            final val = double.tryParse(valueController.text) ?? 0.0;
                            valueController.text = (val + 1).toStringAsFixed(0);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'DAILY COMMENT LOG NOTE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: U.dim,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Record a comment or check-off note...',
                        fillColor: U.surface,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _colorFromHex(_habit.color),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final value = double.tryParse(valueController.text) ?? 0.0;
                          final completed = value >= _habit.targetValue;
                          final noteText = noteController.text.trim();

                          final updatedRecord = HabitRecord(
                            id: existing.id.isEmpty ? '' : existing.id,
                            habitId: _habit.id,
                            userId: _userId,
                            date: dateStr,
                            value: value,
                            targetValue: _habit.targetValue,
                            completed: completed,
                            note: noteText.isEmpty ? null : noteText,
                            syncStatus: 'pending',
                            updatedAt: DateTime.now(),
                          );

                          await _service.saveRecord(updatedRecord);
                          await _loadData();
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          'Save Log Record',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _colorFromHex(_habit.color);
    final isDark = appThemeNotifier.value.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(themeColor),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        children: [
                          _buildStrengthCard(themeColor),
                          const SizedBox(height: 24),
                          _buildStreaksGrid(themeColor),
                          const SizedBox(height: 24),
                          _buildHeatmapSection(themeColor),
                          const SizedBox(height: 24),
                          _buildCalendarSection(themeColor),
                          const SizedBox(height: 24),
                          _buildWeekdayChartSection(themeColor),
                          const SizedBox(height: 36),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: U.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: U.border, width: 0.5),
              ),
              child: Icon(Icons.arrow_back_rounded, color: U.primary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: U.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _habit.frequencyType == 'daily'
                      ? 'Daily Habit'
                      : _habit.frequencyType == 'days_of_week'
                          ? 'Specific weekdays'
                          : '${_habit.frequencyValue}x per ${_habit.frequencyType == 'weekly' ? 'week' : 'month'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: U.sub,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: themeColor, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HabitEditorScreen(habit: _habit),
              ),
            ).then((hasChanged) {
              if (hasChanged == true) {
                _loadData();
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthCard(Color themeColor) {
    final strength = HabitCalculators.calculateStrength(_habit, _records);
    final percentage = (strength * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Circular strength gauge
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: strength,
                  strokeWidth: 8,
                  backgroundColor: themeColor.withValues(alpha: 0.12),
                  color: themeColor,
                ),
                Center(
                  child: Text(
                    '$percentage%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: U.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habit Strength',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: U.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Calculated using an exponential moving average. Ticks increase strength, missed scheduled sessions decrease it.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: U.sub,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.97, 0.97), duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildStreaksGrid(Color themeColor) {
    final currentStreak = HabitCalculators.calculateCurrentStreak(_habit, _records);
    final bestStreak = HabitCalculators.calculateBestStreak(_habit, _records);
    final totalCount = _records.where((r) => r.completed).length;
    final rate = HabitCalculators.calculateCompletionRate(_habit, _records);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Current Streak', '$currentStreak days', '🔥', themeColor),
        _buildStatCard('Best Streak', '$bestStreak days', '🏆', themeColor),
        _buildStatCard('Completion Rate', '${(rate * 100).toStringAsFixed(0)}%', '🎯', themeColor),
        _buildStatCard('Total Logs', '$totalCount checks', '📈', themeColor),
      ],
    ).animate().fadeIn(delay: 50.ms, duration: 400.ms);
  }

  Widget _buildStatCard(String title, String value, String emoji, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: U.dim),
              ),
              Text(emoji, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: U.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapSection(Color themeColor) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    // Create map of completions for last 365 days
    final recordMap = <String, HabitRecord>{};
    for (final r in _records) {
      recordMap[r.date] = r;
    }

    // Generate contribution matrix dates
    // 53 columns of 7 days = 371 days total, aligned to start on Monday
    final List<DateTime> heatmapDates = [];
    final startDay = todayStart.subtract(Duration(days: 364));
    
    // Find the Monday preceding startDay to align rows nicely
    // weekday in Dart: 1=Mon ... 7=Sun
    final alignOffset = startDay.weekday - 1;
    final firstAlignedDay = startDay.subtract(Duration(days: alignOffset));

    for (int i = 0; i < 371; i++) {
      heatmapDates.add(firstAlignedDay.add(Duration(days: i)));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONSISTENCY HEATMAP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: U.dim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            reverse: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day Labels Column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ['M', '', 'W', '', 'F', '', 'S'].map((day) {
                    return Container(
                      height: 12,
                      width: 14,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        day,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: U.dim,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 8),
                
                // Grid Columns (53 columns of 7 rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(53, (colIdx) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(7, (rowIdx) {
                        final listIdx = colIdx * 7 + rowIdx;
                        if (listIdx >= heatmapDates.length) return const SizedBox.shrink();

                        final date = heatmapDates[listIdx];
                        final dateStr = _dateStr(date);
                        final rec = recordMap[dateStr];
                        final isFuture = date.isAfter(todayStart);

                        Color cellColor = U.surface.withValues(alpha: 0.4);
                        if (isFuture) {
                          cellColor = Colors.transparent;
                        } else if (rec != null && rec.completed) {
                          cellColor = themeColor;
                        } else if (rec != null && rec.value > 0 && _habit.type == 'measurable') {
                          final frac = (rec.value / rec.targetValue).clamp(0.0, 1.0);
                          cellColor = themeColor.withValues(alpha: 0.15 + frac * 0.7);
                        }

                        return GestureDetector(
                          onTap: isFuture
                              ? null
                              : () {
                                  if (rec != null && rec.note != null) {
                                    showUtopiaSnackBar(
                                      context,
                                      message: '${_formatDisplayDate(date)} note:\n"${rec.note}"',
                                      tone: UtopiaSnackBarTone.info,
                                    );
                                  } else {
                                    _toggleDateRecord(date);
                                  }
                                },
                          child: Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 3, bottom: 3),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2.5),
                              border: isFuture
                                  ? null
                                  : Border.all(
                                      color: rec != null && rec.note != null
                                          ? U.primary
                                          : U.border.withValues(alpha: 0.15),
                                      width: rec != null && rec.note != null ? 1.0 : 0.5,
                                    ),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less  ',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.sub),
              ),
              ...[0.15, 0.45, 0.75, 1.0].map((alpha) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              Text(
                '  More',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.sub),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildCalendarSection(Color themeColor) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final offset = firstDay.weekday == 7 ? 0 : firstDay.weekday; // Aligning Sunday to column 0

    final recordMap = <String, HabitRecord>{};
    for (final r in _records) {
      recordMap[r.date] = r;
    }

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${monthNames[_calendarMonth.month]} ${_calendarMonth.year}',
                style: GoogleFonts.newsreader(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  color: U.text,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.chevron_left, color: U.sub, size: 20),
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: U.sub, size: 20),
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekHeaders.map((h) => Expanded(
              child: Center(
                child: Text(
                  h,
                  style: GoogleFonts.plusJakartaSans(
                    color: U.dim,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final isDark = appThemeNotifier.value.isDark;
              final dayNum = index - offset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNum);
              final dateStr = _dateStr(date);
              final rec = recordMap[dateStr];
              
              final isFuture = date.isAfter(DateTime.now());
              final isCompleted = rec != null && rec.completed;
              final isMeasurable = _habit.type == 'measurable';
              double frac = 0.0;
              if (rec != null && rec.targetValue > 0) {
                frac = (rec.value / rec.targetValue).clamp(0.0, 1.0);
              }

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () {
                        _toggleDateRecord(date);
                      },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isCompleted)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else if (isMeasurable && frac > 0)
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: U.surface.withValues(alpha: 0.7),
                          ),
                          child: CustomPaint(
                            painter: _PremiumCircleProgressPainter(
                              progress: frac,
                              color: themeColor,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: Text(
                        '$dayNum',
                        style: GoogleFonts.plusJakartaSans(
                          color: isCompleted
                              ? Colors.white
                              : isFuture
                                  ? U.text.withValues(alpha: 0.25)
                                  : U.text,
                          fontWeight: isCompleted || _isSameDay(date, DateTime.now()) ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (rec != null && rec.note != null)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: isCompleted ? Colors.white : themeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _buildWeekdayChartSection(Color themeColor) {
    // Calculate completions for Mon-Sun (1 to 7)
    final counts = List.filled(7, 0);
    for (final r in _records) {
      if (r.completed) {
        try {
          final dt = DateTime.parse(r.date);
          // weekday: 1=Mon ... 7=Sun
          counts[dt.weekday - 1]++;
        } catch (_) {}
      }
    }

    final weekdaysShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    int maxVal = 1;
    for (final c in counts) {
      if (c > maxVal) maxVal = c;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLETION FREQUENCY BY WEEKDAY',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: U.dim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final count = counts[i];
              // Height multiplier (bar height max 120)
              final height = (count / maxVal) * 110.0;

              return Column(
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: count > 0 ? themeColor : U.sub),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    width: 14,
                    height: height.clamp(4.0, 110.0),
                    decoration: BoxDecoration(
                      color: count > 0 ? themeColor : U.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weekdaysShort[i],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: U.dim,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}

class _PremiumCircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _PremiumCircleProgressPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 3.0;
    final double radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw the background track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.15 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw the active progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708, // Start at top
        6.28318 * progress, // Sweep angle
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumCircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
