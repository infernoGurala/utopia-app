import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';

class TaskHeatmapScreen extends StatefulWidget {
  final String taskName;
  const TaskHeatmapScreen({super.key, required this.taskName});
  @override
  State<TaskHeatmapScreen> createState() => _TaskHeatmapScreenState();
}

class _TaskHeatmapScreenState extends State<TaskHeatmapScreen> {
  final _service = FocusSupabaseService();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.taskName.isNotEmpty
        ? widget.taskName[0].toUpperCase() + widget.taskName.substring(1)
        : widget.taskName;

    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: UtopiaLoader(scale: 0.7))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 24, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  color: U.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Daily consistency matrix',
                                style: GoogleFonts.outfit(
                                  color: U.sub.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Year grid card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: U.border.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildYearGrid(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Heatmap Legend
                            Row(
                              children: [
                                Text(
                                  'Less',
                                  style: GoogleFonts.outfit(fontSize: 10, color: U.sub.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                                _buildLegendCell(0.0),
                                _buildLegendCell(0.25),
                                _buildLegendCell(0.50),
                                _buildLegendCell(0.75),
                                _buildLegendCell(1.0),
                                const SizedBox(width: 6),
                                Text(
                                  'More',
                                  style: GoogleFonts.outfit(fontSize: 10, color: U.sub.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
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
                                  style: GoogleFonts.outfit(
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

                  // Tooltip Detail Container
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _tooltipDate != null
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    U.surface,
                                    U.card,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: U.border.withValues(alpha: 0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: U.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.today_rounded, color: U.primary, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTooltipDate(_tooltipDate!),
                                          style: GoogleFonts.outfit(
                                            color: U.text,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_tooltipCount completion${_tooltipCount == 1 ? '' : 's'} recorded',
                                          style: GoogleFonts.outfit(
                                            color: U.sub,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
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

                  const SizedBox(height: 28),

                  // Premium Stats Grid Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'PERFORMANCE METRICS',
                      style: GoogleFonts.outfit(
                        color: U.sub.withValues(alpha: 0.5),
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
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _buildStatCard('Current Streak', '${_currentStreak}d', Icons.local_fire_department_rounded, Colors.orange),
                        _buildStatCard('Longest Streak', '${_longestStreak}d', Icons.emoji_events_rounded, Colors.amber),
                        _buildStatCard('Total Completed', '$_totalDone', Icons.check_circle_outline_rounded, U.teal),
                        _buildStatCard('This Month', '$_thisMonth', Icons.calendar_month_rounded, U.blue),
                      ],
                    ),
                  ),

                  // Last active bottom notice
                  if (_lastActive != '—') ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Last Active: $_lastActive',
                        style: GoogleFonts.outfit(
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
    );
  }

  Widget _buildLegendCell(double opacity) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: opacity > 0.0
            ? U.primary.withValues(alpha: opacity)
            : U.text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(2),
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
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: U.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        SizedBox(
          height: 16,
          child: Row(
            children: [
              const SizedBox(width: 18), // day label space
              ...List.generate(53, (col) {
                return SizedBox(
                  width: cellSize + gap,
                  child: monthLabels.containsKey(col)
                      ? Text(monthLabels[col]!, style: GoogleFonts.outfit(fontSize: 9, color: U.dim, fontWeight: FontWeight.w500))
                      : null,
                );
              }),
            ],
          ),
        ),
        // Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day labels
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  SizedBox(height: cellSize + gap), // Mon (skip)
                  SizedBox(height: cellSize + gap, child: Text('M', style: GoogleFonts.outfit(fontSize: 8.5, color: U.dim, fontWeight: FontWeight.w600))),
                  SizedBox(height: cellSize + gap), // Wed (skip)
                  SizedBox(height: cellSize + gap, child: Text('W', style: GoogleFonts.outfit(fontSize: 8.5, color: U.dim, fontWeight: FontWeight.w600))),
                  SizedBox(height: cellSize + gap), // Fri (skip)
                  SizedBox(height: cellSize + gap, child: Text('F', style: GoogleFonts.outfit(fontSize: 8.5, color: U.dim, fontWeight: FontWeight.w600))),
                  SizedBox(height: cellSize + gap), // Sun (skip)
                ],
              ),
            ),
            // Cells
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
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

                        double opacity = 0.0;
                        if (count >= 4) opacity = 1.0;
                        else if (count == 3) opacity = 0.75;
                        else if (count == 2) opacity = 0.5;
                        else if (count == 1) opacity = 0.25;

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
                              color: count > 0
                                  ? U.primary.withValues(alpha: opacity)
                                  : (U.text.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(2.5),
                              border: isCurrentTooltip
                                  ? Border.all(color: U.text, width: 1.0)
                                  : null,
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
