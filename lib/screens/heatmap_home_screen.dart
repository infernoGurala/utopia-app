import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/focus_supabase_service.dart';
import '../theme/image_overlay_colors.dart';
import '../models/focus_models.dart';
import 'task_heatmap_screen.dart';

class HeatmapHomeScreen extends StatefulWidget {
  final String? initialTask;
  const HeatmapHomeScreen({super.key, this.initialTask});
  @override
  State<HeatmapHomeScreen> createState() => _HeatmapHomeScreenState();
}

class _HeatmapHomeScreenState extends State<HeatmapHomeScreen> {
  final _service = FocusSupabaseService();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filtered = [];
  final Map<String, int> _streaks = {};
  FocusUserHabits? _userHabits;
  String _selectedFilter = 'all'; // 'all', 'habits', 'tasks'
  bool _loading = true;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearch);

    if (widget.initialTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskHeatmapScreen(taskName: widget.initialTask!),
        ));
      });
    }
  }

  Future<void> _load() async {
    await _service.initialize();
    await _service.syncDownAllData();

    final tasks = await _service.getAllTrackedTasks();
    final userHabits = await _service.getUserHabits();
    for (final t in tasks) {
      final name = t['task_name'] as String;
      _streaks[name] = await _service.getCurrentStreak(name);
    }
    if (mounted) {
      setState(() {
        _userHabits = userHabits;
        _allTasks = tasks;
        _filtered = tasks;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase().trim();
    final habitsSet = (_userHabits?.habits ?? [])
        .map((h) => h.toLowerCase().trim())
        .toSet();

    setState(() {
      _filtered = _allTasks.where((t) {
        final name = (t['task_name'] as String).toLowerCase().trim();

        // 1. Search Query filter
        if (q.isNotEmpty && !name.contains(q)) {
          return false;
        }

        // 2. Category filter
        final isHabit = habitsSet.contains(name);
        if (_selectedFilter == 'habits') {
          return isHabit;
        } else if (_selectedFilter == 'tasks') {
          return !isHabit;
        }

        return true;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        body: Stack(
          children: [
            // ── Background Image Banner ──
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

            // ── Smooth Gradient Fade ──
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

            // ── Main Content ──
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: topPadding + 8),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
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
                                'Activity',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: onImageTitleColor,
                                  letterSpacing: -0.6,
                                ),
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

                  // Search Input Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {
                          _isSearchFocused = hasFocus;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: U.surface.withValues(alpha: isDarkTheme ? 0.55 : 0.7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isSearchFocused ? U.primary : U.border.withValues(alpha: 0.5),
                            width: _isSearchFocused ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                            if (_isSearchFocused)
                              BoxShadow(
                                color: U.primary.withValues(alpha: 0.08),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: _isSearchFocused ? U.primary : U.sub, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.w500),
                                cursorColor: U.primary,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Search habit consistency...',
                                  hintStyle: GoogleFonts.outfit(color: U.sub.withValues(alpha: 0.5), fontSize: 15),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: U.sub, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 500.ms),

                  // ── Filter Pills ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildFilterPill('all', 'All', Icons.grid_view_rounded, isDarkTheme),
                          const SizedBox(width: 8),
                          _buildFilterPill('habits', 'Habits', Icons.loop_rounded, isDarkTheme),
                          const SizedBox(width: 8),
                          _buildFilterPill('tasks', 'Tasks', Icons.check_circle_outline_rounded, isDarkTheme),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 500.ms).slideY(begin: 0.08, end: 0, delay: 150.ms, duration: 500.ms),

                  // Task list
                  Expanded(
                    child: _loading
                        ? Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: U.primary))
                        : _filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: U.surface.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.insights_rounded,
                                          size: 40,
                                          color: U.sub.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _allTasks.isEmpty
                                            ? 'No habits tracked yet'
                                            : 'No match found',
                                        style: GoogleFonts.outfit(
                                          color: U.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _allTasks.isEmpty
                                            ? 'Complete a habit or daily task to automatically initiate tracking statistics.'
                                            : 'Try checking your spelling or search for another tracked task.',
                                        style: GoogleFonts.outfit(
                                          color: U.sub.withValues(alpha: 0.8),
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(duration: 400.ms)
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                                itemCount: _filtered.length,
                                itemBuilder: (ctx, i) {
                                  final task = _filtered[i];
                                  final name = task['task_name'] as String;
                                  final streak = _streaks[name] ?? 0;
                                  final displayName = name.isNotEmpty
                                      ? name[0].toUpperCase() + name.substring(1)
                                      : name;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: U.border.withValues(alpha: isDarkTheme ? 0.3 : 0.7),
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
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                                builder: (_) => TaskHeatmapScreen(taskName: name),
                                              )),
                                              borderRadius: BorderRadius.circular(24),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                                child: Row(
                                                  children: [
                                                    // Leading habit badge
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: streak > 0 
                                                            ? (isDarkTheme
                                                                ? Color.lerp(U.primary, Colors.black, 0.72)!.withValues(alpha: 0.85)
                                                                : Color.lerp(U.primary, Colors.white, 0.84)!)
                                                            : U.text.withValues(alpha: 0.05),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        streak > 0 
                                                            ? Icons.local_fire_department_rounded
                                                            : Icons.insights_rounded,
                                                        color: streak > 0 ? U.primary : U.sub,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Text(
                                                        displayName,
                                                        style: GoogleFonts.outfit(
                                                          color: U.text,
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: -0.1,
                                                        ),
                                                      ),
                                                    ),
                                                    if (streak > 0)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              U.primary.withValues(alpha: 0.16),
                                                              U.primary.withValues(alpha: 0.05),
                                                            ],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(
                                                            color: U.primary.withValues(alpha: 0.3),
                                                            width: 1.0,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '🔥 ',
                                                              style: TextStyle(fontSize: 12),
                                                            ),
                                                            Text(
                                                              '$streak d streak',
                                                              style: GoogleFonts.outfit(
                                                                color: U.primary,
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                letterSpacing: 0.1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else
                                                      Icon(
                                                        Icons.chevron_right_rounded,
                                                        color: U.sub.withValues(alpha: 0.5),
                                                        size: 20,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).animate()
                                      .fadeIn(delay: (200 + i * 40).ms, duration: 500.ms)
                                      .slideY(begin: 0.1, end: 0, delay: (200 + i * 40).ms, duration: 500.ms, curve: Curves.easeOutCubic);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label, IconData icon, bool isDarkTheme) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
          _onSearch();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? U.primary.withValues(alpha: 0.22)
                  : U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? U.primary.withValues(alpha: 0.5)
                    : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
                width: 1.0,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: U.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? U.primary : U.sub,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isSelected ? U.text : U.sub,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
