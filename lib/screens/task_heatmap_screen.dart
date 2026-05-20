import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import '../theme/image_overlay_colors.dart';
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

    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;

    final timeSlot = ImageOverlayColors.getTimeSlot();
    final bgImagePath = 'assets/welcome_bg/one_light/$timeSlot.png';
    final themeKey = appThemeNotifier.value.key;
    final onImageTitleColor = ImageOverlayColors.titleColor(themeKey, timeSlot);
    final onImageSubtitleColor = ImageOverlayColors.subtitleColor(themeKey, timeSlot);

    final isDarkSky = timeSlot == 'evening' || timeSlot == 'night';
    final isDarkTheme = appThemeNotifier.value.isDark;
    final useLightStatusBarIcons = isDarkSky || isDarkTheme;

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
        body: _loading
            ? const Center(child: UtopiaLoader(scale: 0.7))
            : Stack(
                children: [
                  // ── Background Image Cover (Extended for premium bleed through) ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.75,
                    child: Image.asset(
                      bgImagePath,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),

                  // ── Gradient Overlay ──
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: screenHeight * 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            U.bg.withValues(alpha: 0.0),
                            U.bg.withValues(alpha: 0.2),
                            U.bg,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Scrollable Body Content ──
                  Positioned.fill(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(0, topPadding + 8, 0, 40),
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 24, 8),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: onImageTitleColor, size: 20),
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
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: onImageTitleColor,
                                        letterSpacing: -0.6,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Daily consistency matrix',
                                      style: GoogleFonts.outfit(
                                        color: onImageSubtitleColor,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 500.ms),
                        const SizedBox(height: 20),

                        // Year grid card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
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
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: U.sub.withValues(alpha: 0.8),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildLegendCell(true),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Completed',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: U.sub.withValues(alpha: 0.8),
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
                            ),
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 550.ms).slideY(begin: 0.08, end: 0, delay: 150.ms, duration: 550.ms),

                        // Tooltip Detail Container
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _tooltipDate != null
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.03),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: (_tooltipCount ?? 0) > 0
                                                    ? U.primary.withValues(alpha: 0.12)
                                                    : U.text.withValues(alpha: 0.05),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                (_tooltipCount ?? 0) > 0
                                                    ? Icons.check_circle_rounded
                                                    : Icons.radio_button_unchecked_rounded,
                                                color: (_tooltipCount ?? 0) > 0 ? U.primary : U.sub,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _formatTooltipDate(_tooltipDate!),
                                                    style: GoogleFonts.outfit(
                                                      color: U.text,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    (_tooltipCount ?? 0) > 0
                                                        ? 'Habit Completed'
                                                        : 'No completion recorded',
                                                    style: GoogleFonts.outfit(
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
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 28),

                        // Performance Metrics Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'PERFORMANCE METRICS',
                            style: GoogleFonts.outfit(
                              color: onImageSubtitleColor.withValues(alpha: 0.7),
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
                            childAspectRatio: 1.85,
                            children: [
                              _buildStatCard('Current Streak', '${_currentStreak}d', Icons.local_fire_department_rounded, Colors.orange, isDarkTheme),
                              _buildStatCard('Longest Streak', '${_longestStreak}d', Icons.emoji_events_rounded, Colors.amber, isDarkTheme),
                              _buildStatCard('Total Completed', '$_totalDone', Icons.check_circle_outline_rounded, U.teal, isDarkTheme),
                              _buildStatCard('This Month', '$_thisMonth', Icons.calendar_month_rounded, U.blue, isDarkTheme),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms, duration: 500.ms).slideY(begin: 0.08, end: 0, delay: 250.ms, duration: 500.ms),

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
                ],
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
            : U.text.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3.5),
        border: completed
            ? null
            : Border.all(color: U.border.withValues(alpha: 0.2), width: 0.5),
        boxShadow: completed ? [
          BoxShadow(
            color: U.primary.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 0.5,
          )
        ] : null,
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDarkTheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkTheme
                      ? Color.lerp(color, Colors.black, 0.72)!.withValues(alpha: 0.85)
                      : Color.lerp(color, Colors.white, 0.84)!,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
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
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
              SizedBox(height: cellSize + gap, child: Text('M', style: GoogleFonts.outfit(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
              SizedBox(height: cellSize + gap), // Wed (skip)
              SizedBox(height: cellSize + gap, child: Text('W', style: GoogleFonts.outfit(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
              SizedBox(height: cellSize + gap), // Fri (skip)
              SizedBox(height: cellSize + gap, child: Text('F', style: GoogleFonts.outfit(fontSize: 9, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))),
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
                            ? Text(monthLabels[col]!, style: GoogleFonts.outfit(fontSize: 9.5, color: U.text.withValues(alpha: 0.65), fontWeight: FontWeight.w600))
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
                                  : U.text.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3.5),
                              border: isCurrentTooltip
                                  ? Border.all(color: U.text, width: 1.5)
                                  : (!isCompleted
                                      ? Border.all(color: U.border.withValues(alpha: 0.2), width: 0.5)
                                      : null),
                              boxShadow: isCompleted ? [
                                BoxShadow(
                                  color: U.primary.withValues(alpha: 0.25),
                                  blurRadius: 3,
                                  spreadRadius: 0.2,
                                )
                              ] : null,
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
