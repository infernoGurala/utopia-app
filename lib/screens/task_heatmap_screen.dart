// UTOPIA - task_heatmap_screen.dart - Detailed habit tracking & visual heatmap grid
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import '../widgets/utopia_loader.dart';

class TaskHeatmapScreen extends StatefulWidget {
  final String taskName;
  const TaskHeatmapScreen({super.key, required this.taskName});
  @override
  State<TaskHeatmapScreen> createState() => _TaskHeatmapScreenState();
}

class _TaskHeatmapScreenState extends State<TaskHeatmapScreen> {
  final _service = FocusSupabaseService();
  final _gridScrollController = ScrollController();
  List<HabitCompletion> _completions = [];
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalDone = 0;
  String _lastActive = '—';
  int _thisMonth = 0;
  bool _loading = true;
  String? _tooltipDate;
  int? _tooltipCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final completions = await _service.getCompletionsForTask(widget.taskName);
    final current = await _service.getCurrentStreak(widget.taskName);
    final longest = await _service.getLongestStreak(widget.taskName);

    final now = DateTime.now();
    final thisMonthCompletions = completions.where((c) {
      final d = DateTime.parse(c.date);
      return d.year == now.year && d.month == now.month && c.completed;
    }).length;

    String lastActiveStr = '—';
    final completed = completions.where((c) => c.completed).toList();
    if (completed.isNotEmpty) {
      final last = DateTime.parse(completed.last.date);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      lastActiveStr = '${months[last.month]} ${last.day}';
    }

    if (mounted) {
      setState(() {
        _completions = completions;
        _currentStreak = current;
        _longestStreak = longest;
        _totalDone = completed.length;
        _lastActive = lastActiveStr;
        _thisMonth = thisMonthCompletions;
        _loading = false;
      });

      // Automatically glide to the latest week's column
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_gridScrollController.hasClients) {
          _gridScrollController.animateTo(
            _gridScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.taskName.isNotEmpty
        ? widget.taskName[0].toUpperCase() + widget.taskName.substring(1)
        : widget.taskName;

    final isDarkTheme = appThemeNotifier.value.isDark;

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
        body: _loading
            ? const Center(child: UtopiaLoader(scale: 0.7))
            : SafeArea(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: U.primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.newsreader(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.italic,
                                    color: U.text,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daily consistency matrix',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: U.sub,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, duration: 400.ms),
                    const SizedBox(height: 20),

                    // Year grid card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: U.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: U.border,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildYearGrid(),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Heatmap Legend (Binary)
                                Row(
                                  children: [
                                    _buildLegendCell(false),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Not completed',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: U.sub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _buildLegendCell(true),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Completed',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: U.sub,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                // Clean clear selection if tooltip active
                                if (_tooltipDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _tooltipDate = null;
                                        _tooltipCount = null;
                                      });
                                    },
                                    child: Text(
                                      'Clear selection',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: U.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, delay: 100.ms, duration: 400.ms),

                    // Tooltip Detail Container
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _tooltipDate != null
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: U.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: U.border, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (_tooltipCount ?? 0) > 0
                                            ? U.primary.withValues(alpha: 0.08)
                                            : U.text.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (_tooltipCount ?? 0) > 0 ? U.primary.withValues(alpha: 0.2) : Colors.transparent,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Icon(
                                        (_tooltipCount ?? 0) > 0
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        color: (_tooltipCount ?? 0) > 0 ? U.primary : U.sub,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatTooltipDate(_tooltipDate!),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: U.text,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (_tooltipCount ?? 0) > 0
                                                ? 'Habit Completed'
                                                : 'No completion recorded',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: (_tooltipCount ?? 0) > 0 ? U.primary : U.sub,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 24),

                    // Performance Metrics Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'PERFORMANCE METRICS',
                        style: GoogleFonts.plusJakartaSans(
                          color: U.sub,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.85,
                        children: [
                          _buildStatCard('Current Streak', '${_currentStreak}d', Icons.local_fire_department_rounded, Colors.orange),
                          _buildStatCard('Longest Streak', '${_longestStreak}d', Icons.emoji_events_rounded, Colors.amber),
                          _buildStatCard('Total Completed', '$_totalDone', Icons.check_circle_outline_rounded, U.teal),
                          _buildStatCard('This Month', '$_thisMonth', Icons.calendar_month_rounded, U.blue),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, delay: 150.ms, duration: 400.ms),

                    // Last active bottom notice
                    if (_lastActive != '—') ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Last Active: $_lastActive',
                          style: GoogleFonts.plusJakartaSans(
                            color: U.sub.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLegendCell(bool completed) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: completed
            ? U.primary
            : U.text.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: completed
            ? null
            : Border.all(color: U.border, width: 0.5),
      ),
    );
  }

  String _formatTooltipDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: U.border,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: U.sub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: U.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearGrid() {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 364));

    // Build a map of date -> completion count
    final dateMap = <String, int>{};
    for (final c in _completions) {
      if (c.completed) {
        dateMap[c.date] = (dateMap[c.date] ?? 0) + c.completionCount;
      }
    }

    // Calculate grid: 53 columns x 7 rows
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final startOffset = firstDay.weekday - 1; // 0 = Monday
    final gridStart = firstDay.subtract(Duration(days: startOffset));

    // Month labels
    final monthLabels = <int, String>{};
    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    for (int col = 0; col < 53; col++) {
      final d = gridStart.add(Duration(days: col * 7));
      if (col == 0 || d.month != gridStart.add(Duration(days: (col - 1) * 7)).month) {
        monthLabels[col] = monthNames[d.month];
      }
    }

    const cellSize = 11.5;
    const gap = 3.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day labels pinned on the left
        SizedBox(
          width: 18,
          child: Column(
            children: [
              const SizedBox(height: 20), // aligns with Month labels (16) + spacing (4)
              SizedBox(height: cellSize + gap), // Mon (skip)
              SizedBox(height: cellSize + gap, child: Text('M', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
              SizedBox(height: cellSize + gap), // Wed (skip)
              SizedBox(height: cellSize + gap, child: Text('W', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
              SizedBox(height: cellSize + gap), // Fri (skip)
              SizedBox(height: cellSize + gap, child: Text('F', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
              SizedBox(height: cellSize + gap), // Sun (skip)
            ],
          ),
        ),
        // Scrollable Month labels AND Cells together
        Expanded(
          child: SingleChildScrollView(
            controller: _gridScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month Labels Row
                SizedBox(
                  height: 16,
                  child: Row(
                    children: List.generate(53, (col) {
                      return SizedBox(
                        width: cellSize + gap,
                        child: monthLabels.containsKey(col)
                            ? Text(monthLabels[col]!, style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))
                            : null,
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                // Grid Cells Row
                Row(
                  children: List.generate(53, (col) {
                    return Column(
                      children: List.generate(7, (row) {
                        final dayIndex = col * 7 + row;
                        final date = gridStart.add(Duration(days: dayIndex));
                        if (date.isAfter(now)) {
                           return SizedBox(width: cellSize + gap, height: cellSize + gap);
                        }
                        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        final count = dateMap[dateStr] ?? 0;
                        final isCompleted = count > 0;
                        final isCurrentTooltip = _tooltipDate == dateStr;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _tooltipDate = dateStr;
                              _tooltipCount = count;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: cellSize,
                            height: cellSize,
                            margin: const EdgeInsets.all(gap / 2),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? U.primary
                                  : U.text.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                              border: isCurrentTooltip
                                  ? Border.all(color: U.text, width: 1.5)
                                  : (!isCompleted
                                      ? Border.all(color: U.border, width: 0.5)
                                      : null),
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
        ),
      ],
    );
  }
}
