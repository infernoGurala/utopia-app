// UTOPIA - heatmap_home_screen.dart - Activity history & consistency tracking screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/focus_supabase_service.dart';
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
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

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
                            'Activity',
                            style: GoogleFonts.newsreader(
                              fontSize: 32,
                              fontWeight: FontWeight.w400,
                              fontStyle: FontStyle.italic,
                              color: U.text,
                              letterSpacing: -0.5,
                            ),
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

              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isSearchFocused = hasFocus;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: U.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _isSearchFocused ? U.primary : U.border,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: _isSearchFocused ? U.primary : U.sub,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.plusJakartaSans(
                              color: U.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
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
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: U.sub.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
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
              ).animate().fadeIn(delay: 50.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, delay: 50.ms, duration: 400.ms),

              // Filter Pills
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterPill('all', 'All', Icons.grid_view_rounded),
                      const SizedBox(width: 8),
                      _buildFilterPill('habits', 'Habits', Icons.loop_rounded),
                      const SizedBox(width: 8),
                      _buildFilterPill('tasks', 'Tasks', Icons.check_circle_outline_rounded),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, end: 0, delay: 100.ms, duration: 400.ms),

              // Task List
              Expanded(
                child: _loading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: U.primary,
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: U.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: U.border, width: 0.5),
                                    ),
                                    child: Icon(
                                      Icons.insights_rounded,
                                      size: 32,
                                      color: U.sub,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _allTasks.isEmpty
                                        ? 'No habits tracked yet'
                                        : 'No match found',
                                    style: GoogleFonts.plusJakartaSans(
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
                                    style: GoogleFonts.plusJakartaSans(
                                      color: U.sub,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 300.ms)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final task = _filtered[i];
                              final name = task['task_name'] as String;
                              final streak = _streaks[name] ?? 0;
                              final displayName = name.isNotEmpty
                                  ? name[0].toUpperCase() + name.substring(1)
                                  : name;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: U.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: U.border,
                                    width: 0.5,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => TaskHeatmapScreen(taskName: name),
                                    )),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          // Leading habit badge
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: streak > 0 
                                                  ? U.primary.withValues(alpha: 0.08)
                                                  : U.text.withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: streak > 0 ? U.primary.withValues(alpha: 0.2) : Colors.transparent,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              streak > 0 
                                                  ? Icons.local_fire_department_rounded
                                                  : Icons.insights_rounded,
                                              color: streak > 0 ? U.primary : U.sub,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              displayName,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: U.text,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: -0.1,
                                              ),
                                            ),
                                          ),
                                          if (streak > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: U.surface,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: U.primary.withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    '🔥 ',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                  Text(
                                                    '$streak d streak',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: U.primary,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
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
                              ).animate()
                                  .fadeIn(delay: (120 + i * 30).ms, duration: 400.ms)
                                  .slideY(begin: 0.05, end: 0, delay: (120 + i * 30).ms, duration: 400.ms, curve: Curves.easeOutCubic);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(String filterKey, String label, IconData icon) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
          _onSearch();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? U.primary : U.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? U.primary : U.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? U.bg : U.sub,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? U.bg : U.text,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
