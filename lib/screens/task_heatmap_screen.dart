import 'package:flutter/material.dart';
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
            ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: U.primary))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: U.text)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(displayName, style: GoogleFonts.playfairDisplay(
                            fontSize: 22, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Year grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildYearGrid(),
                  ),
                  // Tooltip
                  if (_tooltipDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: U.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: U.border),
                        ),
                        child: Text('$_tooltipDate · $_tooltipCount completion${_tooltipCount == 1 ? '' : 's'}',
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Stats row
                  _buildStatsRow(),
                  const Spacer(),
                ],
              ),
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

    const cellSize = 10.0;
    const gap = 2.0;

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
                      ? Text(monthLabels[col]!, style: GoogleFonts.outfit(fontSize: 9, color: U.dim))
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
                  SizedBox(height: cellSize + gap, child: Text('M', style: GoogleFonts.outfit(fontSize: 9, color: U.dim))),
                  SizedBox(height: cellSize + gap), // Wed (skip)
                  SizedBox(height: cellSize + gap, child: Text('W', style: GoogleFonts.outfit(fontSize: 9, color: U.dim))),
                  SizedBox(height: cellSize + gap), // Fri (skip)
                  SizedBox(height: cellSize + gap, child: Text('F', style: GoogleFonts.outfit(fontSize: 9, color: U.dim))),
                  SizedBox(height: cellSize + gap), // Sun (skip)
                ],
              ),
            ),
            // Cells
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _tooltipDate = dateStr;
                              _tooltipCount = count;
                            });
                          },
                          child: Container(
                            width: cellSize, height: cellSize,
                            margin: const EdgeInsets.all(gap / 2),
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? U.primary.withValues(alpha: opacity)
                                  : (U.text.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(2),
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

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem('Current\nStreak', '${_currentStreak}d'),
          _statItem('Longest\nStreak', '${_longestStreak}d'),
          _statItem('Total\nDone', '$_totalDone'),
          _statItem('Last\nActive', _lastActive),
          _statItem('This\nMonth', '$_thisMonth'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: U.dim, letterSpacing: 0.5, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: U.primary)),
      ],
    );
  }
}
