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
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: U.text),
                  ),
                  const SizedBox(width: 4),
                  Text('Activity', style: GoogleFonts.playfairDisplay(
                    fontSize: 24, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search a task…',
                  hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 15),
                  prefixIcon: Icon(Icons.search_rounded, color: U.dim, size: 20),
                  filled: false,
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: U.border)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: U.primary)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Task list
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: U.primary))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _allTasks.isEmpty
                                ? 'Complete a task in your daily note to start tracking.'
                                : 'No history for this task yet.',
                            style: GoogleFonts.outfit(color: U.dim, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final task = _filtered[i];
                            final name = task['task_name'] as String;
                            final streak = _streaks[name] ?? 0;
                            // Display cased name (capitalize first letter)
                            final displayName = name.isNotEmpty
                                ? name[0].toUpperCase() + name.substring(1)
                                : name;

                            return InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => TaskHeatmapScreen(taskName: name),
                              )),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(displayName, style: GoogleFonts.outfit(
                                        color: U.text, fontSize: 15, fontWeight: FontWeight.w400)),
                                    ),
                                    if (streak > 0)
                                      Text('$streak day streak', style: GoogleFonts.outfit(
                                        color: U.dim, fontSize: 12, fontWeight: FontWeight.w400)),
                                  ],
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
