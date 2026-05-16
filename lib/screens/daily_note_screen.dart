import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import 'heatmap_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyNoteScreen extends StatefulWidget {
  const DailyNoteScreen({super.key});
  @override
  State<DailyNoteScreen> createState() => _DailyNoteScreenState();
}

class _DailyNoteScreenState extends State<DailyNoteScreen> {
  final _service = FocusSupabaseService();
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  bool _loading = true;
  bool _markDoneEnabled = true;
  FocusNote? _note;
  FocusUserHabits? _userHabits;
  Set<String> _noteDates = {};
  final Set<String> _collapsedSections = {};

  final _journalController = TextEditingController();
  final _taskController = TextEditingController();
  final _scrollController = ScrollController();

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    final prefs = await SharedPreferences.getInstance();
    _markDoneEnabled = prefs.getBool('daily_note_mark_done') ?? true;
    await _loadData();
    await _loadMonthDots();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final dateStr = _dateStr(_selectedDate);
    final note = await _service.loadNote(dateStr);
    final userHabits = await _service.getUserHabits();
    
    if (!mounted) return;
    setState(() {
      _note = note ?? FocusNote(userId: _userId, date: dateStr);
      _userHabits = userHabits ?? FocusUserHabits(userId: _userId);
      _journalController.text = _note!.journal;
      _loading = false;
    });
  }

  Future<void> _loadMonthDots() async {
    final start = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final end = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);
    final dates = await _service.getNoteDates(_dateStr(start), _dateStr(end));
    if (mounted) setState(() => _noteDates = dates);
  }

  Future<void> _saveNote() async {
    if (_note == null || _userId.isEmpty) return;
    
    final updatedNote = _note!.copyWith(
      journal: _journalController.text,
    );
    await _service.saveNote(updatedNote);
    if (!mounted) return;
    setState(() => _note = updatedNote);
    _loadMonthDots();
  }

  void _selectDate(DateTime date) {
    if (_note != null && _journalController.text != _note!.journal) {
      _saveNote();
    }
    setState(() => _selectedDate = date);
    _loadData();
  }

  void _toggleHabit(String habit) {
    if (_note == null) return;
    final state = Map<String, bool>.from(_note!.habitsState);
    state[habit] = !(state[habit] ?? false);
    _note = _note!.copyWith(habitsState: state);
    setState(() {});
    _saveNote();
  }

  void _addTask(String label) {
    if (_note == null || label.trim().isEmpty) return;
    final tasks = List<Map<String, dynamic>>.from(_note!.tasks);
    tasks.add({'label': label.trim(), 'completed': false});
    _note = _note!.copyWith(tasks: tasks);
    _taskController.clear();
    setState(() {});
    _saveNote();
  }

  void _toggleTask(int index) {
    if (_note == null) return;
    final tasks = List<Map<String, dynamic>>.from(_note!.tasks);
    tasks[index]['completed'] = !(tasks[index]['completed'] == true);
    _note = _note!.copyWith(tasks: tasks);
    setState(() {});
    _saveNote();
  }

  void _deleteTask(int index) {
    if (_note == null) return;
    final tasks = List<Map<String, dynamic>>.from(_note!.tasks);
    tasks.removeAt(index);
    _note = _note!.copyWith(tasks: tasks);
    setState(() {});
    _saveNote();
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 32, height: 4, decoration: BoxDecoration(color: U.dim, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              // Mark Done toggle
              SwitchListTile(
                secondary: Icon(Icons.check_circle_outline_rounded, color: U.sub, size: 22),
                title: Text('Allow Mark Done', style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text('Tap checkboxes to toggle completion', style: GoogleFonts.outfit(color: U.dim, fontSize: 12)),
                value: _markDoneEnabled,
                activeTrackColor: U.primary,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('daily_note_mark_done', v);
                  setSheetState(() => _markDoneEnabled = v);
                  setState(() {});
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _menuItem(Icons.loop_rounded, 'Edit Habits', () {
                Navigator.pop(ctx);
                _editHabits();
              }),
              _menuItem(Icons.delete_outline_rounded, 'Delete Note', () {
                Navigator.pop(ctx);
                _confirmDeleteNote();
              }, isDestructive: true),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? U.red : U.sub, size: 22),
      title: Text(label, style: GoogleFonts.outfit(color: isDestructive ? U.red : U.text, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Future<void> _editHabits() async {
    final controller = TextEditingController(text: _userHabits?.habits.join('\n') ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('Edit Habits', style: GoogleFonts.playfairDisplay(color: U.text, fontSize: 20, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text('Save', style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Enter one habit per line.', style: GoogleFonts.outfit(color: U.dim, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.jetBrainsMono(color: U.text, fontSize: 14, height: 1.6),
                    decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && _userHabits != null) {
      final habits = result.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final newConfig = _userHabits!.copyWith(habits: habits);
      await _service.saveUserHabits(newConfig);
      setState(() => _userHabits = newConfig);
    }
  }

  Future<void> _confirmDeleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Delete Note?', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Text('This will permanently delete this day\'s note.', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.outfit(color: U.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteNote(_dateStr(_selectedDate));
      await _loadData();
      await _loadMonthDots();
    }
  }

  @override
  void dispose() {
    if (_note != null && _journalController.text != _note!.journal) {
      _saveNote();
    }
    _journalController.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgImage = isDark ? 'assets/daily/dark.png' : 'assets/daily/light.png';

    return Scaffold(
      backgroundColor: U.bg,
      endDrawer: _buildCalendarDrawer(),
      body: Stack(
        children: [
          // Background Image (Top Half)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Opacity(
              opacity: isDark ? 0.7 : 0.9,
              child: Image.asset(
                bgImage,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          // Gradient overlay for seamless blending
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.61,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    U.bg.withValues(alpha: 0.1),
                    U.bg.withValues(alpha: 0.5),
                    U.bg,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(child: _loading ? _buildLoading() : _buildNoteBody()),
              ],
            ),
          ),
          // Slide bar to open calendar
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Builder(
              builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  if (details.primaryDelta != null && details.primaryDelta! < -1) {
                    Scaffold.of(ctx).openEndDrawer();
                  }
                },
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
                child: Container(
                  width: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, U.primary.withValues(alpha: 0.15)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 10,
                      height: 140,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: U.primary.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const dayFull = ['', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: U.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: U.border, width: 0.5),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: U.text, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text('Daily Note', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
              const Spacer(),
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: U.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: U.border, width: 0.5),
                    ),
                    child: Icon(Icons.calendar_today_rounded, color: U.sub, size: 17),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showMenu,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: U.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: U.border, width: 0.5),
                  ),
                  child: Icon(Icons.settings_outlined, color: U.sub, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Date hero
          Text(dayFull[_selectedDate.weekday], style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: U.primary, letterSpacing: 2.5)),
          const SizedBox(height: 4),
          Text('${_selectedDate.day} ${monthNames[_selectedDate.month]} ${_selectedDate.year}',
            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCalendarDrawer() {
    const dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun
    final offset = firstWeekday == 7 ? 0 : firstWeekday;

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return Theme(
      data: Theme.of(context).copyWith(
        drawerTheme: DrawerThemeData(
          backgroundColor: U.bg,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(monthNames[_calendarMonth.month], style: GoogleFonts.outfit(color: U.primary, fontSize: 24, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('${_calendarMonth.year}', style: GoogleFonts.outfit(color: U.dim, fontSize: 24, fontWeight: FontWeight.w400)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: U.dim),
                      onPressed: () {
                        setState(() {
                          _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                        });
                        _loadMonthDots();
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: U.dim),
                      onPressed: () {
                        setState(() {
                          _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                        });
                        _loadMonthDots();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Day headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: dayNames.map((d) => SizedBox(
                    width: 36,
                    child: Text(d, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: U.dim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                // Grid
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: 42,
                    itemBuilder: (context, index) {
                      final dayNumber = index - offset + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNumber);
                      final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
                      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                      final hasNote = _noteDates.contains(_dateStr(date));
                      
                      Color textColor = U.sub;
                      if (isSelected) {
                        textColor = U.primary;
                      } else if (isToday) {
                        textColor = U.text;
                      } else if (date.isBefore(today) || isToday) {
                        textColor = const Color(0xFF88A0B0);
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _selectDate(date);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? U.primary.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: U.primary.withValues(alpha: 0.2)) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$dayNumber', style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                              )),
                              const SizedBox(height: 4),
                              if (hasNote)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 4, height: 4, decoration: BoxDecoration(color: U.primary, shape: BoxShape.circle)),
                                    const SizedBox(width: 2),
                                    Container(width: 4, height: 4, decoration: BoxDecoration(color: U.primary.withValues(alpha: 0.4), shape: BoxShape.circle)),
                                  ],
                                )
                              else
                                const SizedBox(height: 4),
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
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(child: CircularProgressIndicator(strokeWidth: 2, color: U.primary));
  }

  Widget _buildNoteBody() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _buildHabitsCard(),
        const SizedBox(height: 16),
        _buildTasksCard(),
        const SizedBox(height: 16),
        _buildJournalCard(),
      ],
    );
  }

  Widget _buildHabitsCard() {
    final title = 'Habits';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.blue;
    final icon = Icons.loop_rounded;

    final habits = _userHabits?.habits ?? [];
    if (habits.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(icon, color: U.dim, size: 28),
              const SizedBox(height: 8),
              Text('No habits configured', style: GoogleFonts.outfit(color: U.dim)),
              const SizedBox(height: 8),
              TextButton(onPressed: _editHabits, child: Text('Setup Habits', style: GoogleFonts.outfit(color: accent))),
            ],
          ),
        ),
      );
    }

    int doneCount = 0;
    for (final h in habits) {
      if (_note?.habitsState[h] == true) doneCount++;
    }

    return _buildCardWrapper(
      title: title,
      icon: icon,
      accent: accent,
      isCollapsed: isCollapsed,
      onToggle: () => setState(() {
        isCollapsed ? _collapsedSections.remove(title) : _collapsedSections.add(title);
      }),
      subtitle: '$doneCount of ${habits.length} done',
      progress: habits.isEmpty ? 0 : doneCount / habits.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final habit in habits)
            _buildCheckItem(
              label: habit,
              checked: _note?.habitsState[habit] == true,
              isTask: false,
              onTap: () => _toggleHabit(habit),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksCard() {
    final title = 'Tasks';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.teal;
    final icon = Icons.checklist_rounded;

    final tasks = _note?.tasks ?? [];
    int doneCount = 0;
    for (final t in tasks) {
      if (t['completed'] == true) doneCount++;
    }

    return _buildCardWrapper(
      title: title,
      icon: icon,
      accent: accent,
      isCollapsed: isCollapsed,
      onToggle: () => setState(() {
        isCollapsed ? _collapsedSections.remove(title) : _collapsedSections.add(title);
      }),
      subtitle: tasks.isEmpty ? '0 tasks' : '$doneCount of ${tasks.length} done',
      progress: tasks.isEmpty ? 0 : doneCount / tasks.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < tasks.length; i++)
            _buildCheckItem(
              label: tasks[i]['label'],
              checked: tasks[i]['completed'] == true,
              isTask: true,
              onTap: () => _toggleTask(i),
              onDelete: () => _deleteTask(i),
            ),
          const SizedBox(height: 8),
          // Add Task Field
          TextField(
            controller: _taskController,
            style: GoogleFonts.outfit(color: U.text, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Add a new task...',
              hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 15),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.add_rounded, color: U.dim, size: 20),
            ),
            onSubmitted: (val) => _addTask(val),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard() {
    final title = 'Journal';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.peach;
    final icon = Icons.edit_rounded;

    return _buildCardWrapper(
      title: title,
      icon: icon,
      accent: accent,
      isCollapsed: isCollapsed,
      onToggle: () => setState(() {
        isCollapsed ? _collapsedSections.remove(title) : _collapsedSections.add(title);
      }),
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) _saveNote();
        },
        child: TextField(
          controller: _journalController,
          maxLines: null,
          style: GoogleFonts.outfit(color: U.text, fontSize: 15, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Write your thoughts...',
            hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 15),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Color accent,
    required bool isCollapsed,
    required VoidCallback onToggle,
    required Widget child,
    String? subtitle,
    double? progress,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: U.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (subtitle != null) ...[
                    Text(subtitle, style: GoogleFonts.outfit(color: U.dim, fontSize: 12)),
                    const SizedBox(width: 8),
                  ],
                  if (progress != null) ...[
                    SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: U.border,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded, color: U.dim, size: 20),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String label,
    required bool checked,
    required bool isTask,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _markDoneEnabled ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: checked ? U.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: checked ? U.primary : U.dim, width: 1.5),
              ),
              child: checked ? Icon(Icons.check, size: 14, color: U.bg) : null,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isTask ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeatmapHomeScreen(initialTask: label))) : null,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: checked ? U.dim : U.text,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  decorationColor: U.dim,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isTask)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, color: U.dim.withValues(alpha: 0.5), size: 18),
              ),
            ),
          if (isTask && onDelete == null)
            Icon(Icons.insights_rounded, color: U.dim.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }
}
