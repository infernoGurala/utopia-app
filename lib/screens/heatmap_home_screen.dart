import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/focus_supabase_service.dart';
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
    final tasks = await _service.getAllTrackedTasks();
    for (final t in tasks) {
      final name = t['task_name'] as String;
      _streaks[name] = await _service.getCurrentStreak(name);
    }
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _filtered = tasks;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allTasks
          : _allTasks.where((t) => (t['task_name'] as String).contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Heatmaps',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: U.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track consistency over time',
                        style: GoogleFonts.outfit(
                          color: U.sub.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
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
                    color: U.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSearchFocused ? U.primary : U.border.withValues(alpha: 0.5),
                      width: _isSearchFocused ? 1.8 : 1.0,
                    ),
                    boxShadow: [
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
            ),

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
                                    color: U.surface,
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
                        )
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
                              decoration: BoxDecoration(
                                color: U.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: U.border.withValues(alpha: 0.4),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
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
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    child: Row(
                                      children: [
                                        // Bullet design
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: streak > 0 ? U.primary : U.sub.withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
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
                                              borderRadius: BorderRadius.circular(14),
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
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
