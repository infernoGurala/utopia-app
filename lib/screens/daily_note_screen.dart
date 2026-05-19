import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import 'heatmap_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/utopia_loader.dart';
import '../theme/image_overlay_colors.dart';

class DailyNoteScreen extends StatefulWidget {
  const DailyNoteScreen({super.key});
  @override
  State<DailyNoteScreen> createState() => _DailyNoteScreenState();
}

class _DailyNoteScreenState extends State<DailyNoteScreen> with TickerProviderStateMixin {
  final _service = FocusSupabaseService();
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  bool _loading = true;
  bool _allowDeleteEnabled = true;
  FocusNote? _note;
  FocusUserHabits? _userHabits;
  Set<String> _noteDates = {};
  final Set<String> _collapsedSections = {};
  bool _isDraggingCalendar = false;

  final _journalController = TextEditingController();
  final _taskController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _calendarController;

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _calendarController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _calendarController.addListener(() => setState(() {}));
    _init();
  }

  Future<void> _init() async {
    await _service.initialize();
    final prefs = await SharedPreferences.getInstance();
    _allowDeleteEnabled = prefs.getBool('daily_note_allow_delete') ?? true;
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
      _userHabits = userHabits ?? FocusUserHabits(userId: _userId);
      
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final compareDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final isPast = compareDate.isBefore(todayDate);

      FocusNote finalNote;
      if (note != null) {
        finalNote = note;
        if (finalNote.habitsState.isEmpty && !isPast && _userHabits != null) {
          final initialState = <String, bool>{};
          for (final h in _userHabits!.habits) {
            initialState[h] = false;
          }
          finalNote = finalNote.copyWith(habitsState: initialState);
        }
      } else {
        final initialState = <String, bool>{};
        if (!isPast && _userHabits != null) {
          for (final h in _userHabits!.habits) {
            initialState[h] = false;
          }
        }
        finalNote = FocusNote(
          userId: _userId,
          date: dateStr,
          habitsState: initialState,
        );
      }

      _note = finalNote;
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

  void _closeCalendar() {
    _calendarController.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _openCalendar() {
    _calendarController.animateTo(1.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _toggleCalendar() {
    if (_calendarController.isAnimating) return;
    if (_calendarController.value > 0.5) {
      _closeCalendar();
    } else {
      _openCalendar();
    }
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

  void _editTask(int index, String newLabel) {
    if (_note == null || newLabel.trim().isEmpty) return;
    final tasks = List<Map<String, dynamic>>.from(_note!.tasks);
    tasks[index]['label'] = newLabel.trim();
    _note = _note!.copyWith(tasks: tasks);
    setState(() {});
    _saveNote();
  }

  void _showEditTaskSheet(int index, String currentLabel) {
    final controller = TextEditingController(text: currentLabel);
    bool isFocused = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  color: U.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: U.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
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
                          'Edit Task',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: U.text,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: U.sub),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Focus(
                      onFocusChange: (hasFocus) {
                        setSheetState(() {
                          isFocused = hasFocus;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: U.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isFocused ? U.teal : U.border.withValues(alpha: 0.5),
                            width: isFocused ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (isFocused)
                              BoxShadow(
                                color: U.teal.withValues(alpha: 0.08),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.w500),
                          cursorColor: U.teal,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Enter task label',
                            hintStyle: GoogleFonts.outfit(color: U.sub.withValues(alpha: 0.6), fontSize: 16),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _editTask(index, val);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: U.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          if (controller.text.trim().isNotEmpty) {
                            _editTask(index, controller.text);
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          'Save Changes',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
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
              // Allow Delete toggle
              SwitchListTile(
                secondary: Icon(Icons.delete_outline_rounded, color: U.sub, size: 22),
                title: Text('Allow Delete Tasks', style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w500)),
                subtitle: Text('Show delete (x) button next to tasks', style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
                value: _allowDeleteEnabled,
                activeTrackColor: U.primary,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('daily_note_allow_delete', v);
                  setSheetState(() => _allowDeleteEnabled = v);
                  setState(() {});
                },
              ),
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
    final List<String> localHabits = List<String>.from(_userHabits?.habits ?? []);
    final inputController = TextEditingController();
    bool forceApplyToday = false;
    bool isInputFocused = false;
    final suggestions = const [
      'Drink Water 💧',
      'Read 📚',
      'Meditation 🧘',
      'Workout 🏋️',
      'Sleep 8h 😴',
      'Journal ✍️',
      'Review Goals 🎯',
      'Walk 10k steps 🚶',
      'No Sugar 🍎',
      'Code 💻',
    ];

    final bool? forceApply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void addHabit(String habit) {
            final trimmed = habit.trim();
            if (trimmed.isNotEmpty && !localHabits.contains(trimmed)) {
              setSheetState(() {
                localHabits.add(trimmed);
              });
              inputController.clear();
            }
          }

          Widget buildTomorrowPanel() {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [U.surface, U.card],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: U.border.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: U.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline_rounded, color: U.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Template Updated',
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Changes take effect starting tomorrow.',
                              style: GoogleFonts.outfit(
                                color: U.sub,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_note != null && _note!.habitsState.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: U.border.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply to Today?',
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Resets today's habit completion progress",
                                style: GoogleFonts.outfit(
                                  color: U.red.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: forceApplyToday,
                          activeColor: U.red,
                          activeTrackColor: U.red.withValues(alpha: 0.2),
                          onChanged: (v) {
                            setSheetState(() {
                              forceApplyToday = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.82,
              decoration: BoxDecoration(
                color: U.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: U.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: U.dim.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Habits',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: U.text,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Customize daily activities to track',
                                  style: GoogleFonts.outfit(
                                    color: U.sub.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: U.teal.withValues(alpha: 0.15),
                                foregroundColor: U.teal,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx, forceApplyToday);
                              },
                              child: Text(
                                'Done',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        setSheetState(() {
                          isInputFocused = hasFocus;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: U.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isInputFocused ? U.blue : U.border.withValues(alpha: 0.5),
                            width: isInputFocused ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (isInputFocused)
                              BoxShadow(
                                color: U.blue.withValues(alpha: 0.08),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, color: isInputFocused ? U.blue : U.sub, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: inputController,
                                style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.w500),
                                cursorColor: U.blue,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Create a custom habit...',
                                  hintStyle: GoogleFonts.outfit(color: U.sub.withValues(alpha: 0.6), fontSize: 15),
                                ),
                                onSubmitted: addHabit,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_rounded, color: U.blue, size: 22),
                              onPressed: () => addHabit(inputController.text),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'QUICK SUGGESTIONS',
                        style: GoogleFonts.outfit(
                          color: U.sub.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final alreadyAdded = localHabits.contains(suggestion);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: alreadyAdded ? null : () => addHabit(suggestion),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: alreadyAdded ? U.surface.withValues(alpha: 0.3) : U.card.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: alreadyAdded ? U.border.withValues(alpha: 0.2) : U.border.withValues(alpha: 0.7),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    suggestion,
                                    style: GoogleFonts.outfit(
                                      color: alreadyAdded ? U.sub.withValues(alpha: 0.6) : U.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (alreadyAdded) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.check_circle_rounded, color: U.teal, size: 14),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: localHabits.isEmpty
                        ? ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            children: [
                              const SizedBox(height: 32),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: U.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.track_changes_outlined, size: 36, color: U.sub.withValues(alpha: 0.5)),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No habits added yet',
                                      style: GoogleFonts.outfit(color: U.sub, fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 48),
                              buildTomorrowPanel(),
                            ],
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: localHabits.length + 1,
                            itemBuilder: (context, index) {
                              if (index == localHabits.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                                  child: buildTomorrowPanel(),
                                );
                              }

                              final habit = localHabits[index];
                              return Dismissible(
                                key: Key(habit),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: U.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, color: U.red, size: 24),
                                ),
                                onDismissed: (direction) {
                                  setSheetState(() {
                                    localHabits.removeAt(index);
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: U.card,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: U.border.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [U.blue, U.blue.withValues(alpha: 0.7)],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              child: Text(
                                                habit,
                                                style: GoogleFonts.outfit(
                                                  color: U.text,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded, color: U.red.withValues(alpha: 0.7), size: 22),
                                            splashColor: U.red.withValues(alpha: 0.1),
                                            highlightColor: Colors.transparent,
                                            onPressed: () {
                                              setSheetState(() {
                                                localHabits.removeAt(index);
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 8),
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
        },
      ),
    );

    if (_userHabits != null) {
      final newConfig = _userHabits!.copyWith(habits: localHabits);
      await _service.saveUserHabits(newConfig);
      if (mounted) {
        setState(() {
          _userHabits = newConfig;

          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final compareDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          final isPast = compareDate.isBefore(todayDate);

          if (_note != null && !isPast) {
            // Apply today if they selected "Apply to Today" switch, OR if today's/future note has an empty habitsState
            if (forceApply == true || _note!.habitsState.isEmpty) {
              final initialState = <String, bool>{};
              for (final h in localHabits) {
                initialState[h] = false;
              }
              _note = _note!.copyWith(habitsState: initialState);
              _saveNote();
            }
          }
        });
      }
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
    _calendarController.dispose();
    _journalController.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgImage = isDark ? 'assets/daily/dark.png' : 'assets/daily/light.png';
    final screenWidth = MediaQuery.sizeOf(context).width;
    const handleTouchWidth = 36.0;
    final panelWidth = screenWidth * 0.85;
    final contentWidth = panelWidth - handleTouchWidth;

    return Scaffold(
      backgroundColor: U.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (details) {
          final isOpen = _calendarController.value > 0.5;
          final startFromRight = details.globalPosition.dx > screenWidth * 0.45;
          if (isOpen || startFromRight) {
            _isDraggingCalendar = true;
            _calendarController.stop();
          } else {
            _isDraggingCalendar = false;
          }
        },
        onHorizontalDragUpdate: (details) {
          if (!_isDraggingCalendar) return;
          // Multiplying dx by 1.6 to make the slider extremely responsive and direct!
          _calendarController.value = (_calendarController.value - (details.delta.dx * 1.6) / contentWidth).clamp(0.0, 1.0);
        },
        onHorizontalDragEnd: (details) {
          if (!_isDraggingCalendar) return;
          _isDraggingCalendar = false;
          // Lowered velocity trigger from 200 to 140, and value threshold from 0.3 to 0.18 for instant spring activation
          if (details.primaryVelocity != null && details.primaryVelocity! < -140) {
            _calendarController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
          } else if (details.primaryVelocity != null && details.primaryVelocity! > 140) {
            _calendarController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
          } else if (_calendarController.value > 0.18) {
            _calendarController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
          } else {
            _calendarController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
          }
        },
        child: Stack(
          children: [
            // Background Image (Extended for smooth transition)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: Image.asset(
                bgImage,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            // Gradient overlay: top half clear, bottom half smooth fade
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      U.bg.withValues(alpha: 0.0),
                      U.bg.withValues(alpha: 0.0),
                      U.bg,
                    ],
                    stops: const [0.0, 0.5, 1.0],
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

            // Backdrop dimming overlay scrim
            if (_calendarController.value > 0.0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeCalendar,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 5 * _calendarController.value,
                        sigmaY: 5 * _calendarController.value,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.12 * _calendarController.value),
                      ),
                    ),
                  ),
                ),
              ),
            
            // Sliding calendar panel
            _buildSlidingCalendarPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    Widget headerButton({required IconData icon, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
              child: Icon(icon, color: U.text.withValues(alpha: 0.8), size: 19),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              headerButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleCalendar,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '${_selectedDate.day} ${monthNames[_selectedDate.month]} ${_selectedDate.year}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: U.text.withValues(alpha: 0.95),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const Spacer(),
              headerButton(
                icon: Icons.calendar_today_rounded,
                onTap: _toggleCalendar,
              ),
              const SizedBox(width: 8),
              headerButton(
                icon: Icons.settings_outlined,
                onTap: _showMenu,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCalendarBody() {
    const dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday = firstDayOfMonth.weekday;
    final offset = firstWeekday == 7 ? 0 : firstWeekday;

    const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(monthNames[_calendarMonth.month], style: GoogleFonts.outfit(color: U.primary, fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${_calendarMonth.year}', style: GoogleFonts.outfit(color: U.sub, fontSize: 24, fontWeight: FontWeight.w400)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.chevron_left, color: U.sub),
                onPressed: () {
                  setState(() { _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1); });
                  _loadMonthDots();
                },
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: U.sub),
                onPressed: () {
                  setState(() { _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1); });
                  _loadMonthDots();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dayNames.map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: GoogleFonts.inter(
                    color: U.text.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
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
              final dayNumber = index - offset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_calendarMonth.year, _calendarMonth.month, dayNumber);
              final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
              final hasNote = _noteDates.contains(_dateStr(date));

              Color textColor = U.text.withValues(alpha: 0.6);
              if (isSelected) {
                textColor = U.primary;
              } else if (isToday) {
                textColor = U.text;
              } else if (date.isAfter(today)) {
                textColor = U.text.withValues(alpha: 0.3);
              }

              return GestureDetector(
                onTap: () {
                  _closeCalendar();
                  _selectDate(date);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected ? U.primary.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: U.primary.withValues(alpha: 0.2)) : null,
                        ),
                      ),
                    ),
                    Center(
                      child: Text('$dayNumber', style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                      )),
                    ),
                    if (hasNote)
                      Positioned(
                        bottom: 4,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: U.primary, shape: BoxShape.circle)),
                            const SizedBox(width: 2),
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: U.primary.withValues(alpha: 0.4), shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingCalendarPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    const handleTouchWidth = 36.0;
    final panelWidth = screenWidth * 0.90;
    final contentWidth = panelWidth - handleTouchWidth;
    final progress = _calendarController.value;
    final left = screenWidth - handleTouchWidth - contentWidth * progress;

    return Positioned(
      top: 0,
      bottom: 0,
      left: left,
      width: panelWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onHorizontalDragStart: (_) => _calendarController.stop(),
              onHorizontalDragUpdate: (d) {
                // Increased responsiveness to 1.6x finger speed
                _calendarController.value = (_calendarController.value - (d.delta.dx * 1.6) / contentWidth).clamp(0.0, 1.0);
              },
              onHorizontalDragEnd: (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! < -140) {
                  _calendarController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                } else if (d.primaryVelocity != null && d.primaryVelocity! > 140) {
                  _calendarController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                } else if (_calendarController.value > 0.18) {
                  _calendarController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                } else {
                  _calendarController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
                }
              },
              onTap: _toggleCalendar,
              child: Container(
                width: handleTouchWidth,
                height: 240,
                alignment: Alignment.centerRight,
                color: Colors.transparent,
                child: Container(
                  width: 3,
                  height: 200,
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: U.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: U.bg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 25,
                    spreadRadius: 2,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: true,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                      child: _buildCalendarBody(),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: GestureDetector(
                        onTap: _closeCalendar,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                U.primary.withValues(alpha: 0.12),
                                U.primary.withValues(alpha: 0.04),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: U.primary.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: U.primary.withValues(alpha: 0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward_rounded, color: U.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Slide Back',
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: UtopiaLoader(scale: 0.7));
  }

  Widget _buildNoteBody() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      children: [
        _buildHabitsSection(),
        _buildTasksSection(),
        _buildJournalSection(),
      ],
    );
  }

  Widget _buildHabitsSection() {
    final title = 'Habits';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.blue;
    final icon = Icons.track_changes_rounded;

    final habits = _note?.habitsState.keys.toList() ?? [];
    if (habits.isEmpty) {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final compareDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final isPast = compareDate.isBefore(todayDate);

      return Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 12),
        child: Row(
          children: [
            Icon(icon, color: U.sub, size: 20),
            const SizedBox(width: 12),
            Text(
              isPast ? 'No habits tracked on this day' : 'No habits configured', 
              style: GoogleFonts.outfit(color: U.sub, fontSize: 15)
            ),
            const Spacer(),
            if (!isPast)
              TextButton(
                onPressed: _editHabits, 
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('Setup', style: GoogleFonts.outfit(color: accent, fontWeight: FontWeight.w600))
              ),
          ],
        ),
      );
    }

    int doneCount = 0;
    for (final h in habits) {
      if (_note?.habitsState[h] == true) doneCount++;
    }

    return _SectionWrapper(
      title: title,
      icon: icon,
      accent: accent,
      isCollapsed: isCollapsed,
      onToggle: () => setState(() {
        isCollapsed ? _collapsedSections.remove(title) : _collapsedSections.add(title);
      }),
      subtitle: habits.isEmpty ? '0 habits' : '$doneCount/${habits.length}',
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
              onTextTap: null,
            ),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    final title = 'Tasks';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.teal;
    final icon = Icons.checklist_rounded;

    final tasks = _note?.tasks ?? [];
    int doneCount = 0;
    for (final t in tasks) {
      if (t['completed'] == true) doneCount++;
    }

    return _SectionWrapper(
      title: title,
      icon: icon,
      accent: accent,
      isCollapsed: isCollapsed,
      onToggle: () => setState(() {
        isCollapsed ? _collapsedSections.remove(title) : _collapsedSections.add(title);
      }),
      subtitle: tasks.isEmpty ? '0 tasks' : '$doneCount/${tasks.length}',
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
              onTextTap: () => _showEditTaskSheet(i, tasks[i]['label']),
              onDelete: () => _deleteTask(i),
            ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent.withValues(alpha: 0.45), width: 2)),
            ),
            padding: const EdgeInsets.only(left: 12),
            child: TextSelectionTheme(
              data: TextSelectionThemeData(
                cursorColor: accent,
                selectionColor: accent.withValues(alpha: 0.15),
                selectionHandleColor: accent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,
                      style: GoogleFonts.inter(color: U.text, fontSize: 17),
                      cursorColor: accent,
                      cursorWidth: 1.5,
                      cursorRadius: const Radius.circular(10),
                      decoration: InputDecoration(
                        hintText: 'Add a task...',
                        hintStyle: GoogleFonts.inter(color: U.text.withValues(alpha: 0.35), fontSize: 17),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onSubmitted: (val) => _addTask(val),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _taskController,
                    builder: (context, value, child) {
                      final showButton = value.text.trim().isNotEmpty;
                      return AnimatedOpacity(
                        opacity: showButton ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: AnimatedScale(
                          scale: showButton ? 1.0 : 0.8,
                          duration: const Duration(milliseconds: 150),
                          child: IgnorePointer(
                            ignoring: !showButton,
                            child: IconButton(
                              icon: Icon(Icons.arrow_upward_rounded, color: accent, size: 22),
                              splashColor: accent.withValues(alpha: 0.1),
                              highlightColor: Colors.transparent,
                              onPressed: () {
                                _addTask(_taskController.text);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalSection() {
    final title = 'Journal';
    final isCollapsed = _collapsedSections.contains(title);
    final accent = U.peach;
    final icon = Icons.edit_rounded;

    return _SectionWrapper(
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
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent.withValues(alpha: 0.45), width: 2)),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: TextSelectionTheme(
            data: TextSelectionThemeData(
              cursorColor: accent,
              selectionColor: accent.withValues(alpha: 0.15),
              selectionHandleColor: accent,
            ),
            child: TextField(
              controller: _journalController,
              maxLines: null,
              minLines: 4,
              style: GoogleFonts.inter(color: U.text, fontSize: 17, height: 1.8),
              cursorColor: accent,
              cursorWidth: 1.5,
              cursorRadius: const Radius.circular(10),
              decoration: InputDecoration(
                hintText: 'Write your thoughts...',
                hintStyle: GoogleFonts.inter(color: U.text.withValues(alpha: 0.35), fontSize: 17),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required String label,
    required bool checked,
    required bool isTask,
    required VoidCallback onTap,
    required VoidCallback? onTextTap,
    VoidCallback? onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AnimatedCheckbox(checked: checked, enabled: true, onTap: onTap),
          Expanded(
            child: GestureDetector(
              onTap: onTextTap,
              behavior: HitTestBehavior.opaque,
              child: _StrikeThroughText(
                text: label,
                checked: checked,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: U.text,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (isTask && onDelete != null && _allowDeleteEnabled)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 4, bottom: 4),
                child: Text(
                  'x',
                  style: GoogleFonts.inter(
                    color: U.text.withValues(alpha: 0.45),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (isTask && onDelete == null)
            Text(
              'habit',
              style: GoogleFonts.inter(
                color: U.text.withValues(alpha: 0.35),
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionWrapper extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Widget child;
  final String? subtitle;
  final double? progress;

  const _SectionWrapper({
    required this.title,
    required this.icon,
    required this.accent,
    required this.isCollapsed,
    required this.onToggle,
    required this.child,
    this.subtitle,
    this.progress,
  });

  @override
  State<_SectionWrapper> createState() => _SectionWrapperState();
}

class _SectionWrapperState extends State<_SectionWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOutCubic));
    _fadeAnimation = _controller.drive(CurveTween(curve: Curves.easeInOutCubic));
    _rotationAnimation = _controller.drive(
      Tween<double>(begin: -0.25, end: 0.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
    );

    if (!widget.isCollapsed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _SectionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCollapsed != oldWidget.isCollapsed) {
      if (widget.isCollapsed) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    color: U.text.withValues(alpha: 0.85),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (widget.subtitle != null) ...[
                  Text(
                    widget.subtitle!,
                    style: GoogleFonts.inter(
                      color: U.text.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                RotationTransition(
                  turns: _rotationAnimation,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.accent,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: _heightFactor.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: child,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 0, top: 4, bottom: 24),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _AnimatedCheckbox extends StatefulWidget {
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  const _AnimatedCheckbox({required this.checked, required this.enabled, required this.onTap});

  @override
  State<_AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<_AnimatedCheckbox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _checkScale = Tween<double>(begin: 10, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.checked) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      if (widget.checked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isChecked = _controller.value > 0;
          return Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFFDDDDDD), const Color(0xFF08BB68), _controller.value),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Transform.scale(
                scale: isChecked ? _checkScale.value : 10,
                child: Opacity(
                  opacity: isChecked ? 1 : 0,
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _CheckPainter(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.3, size.height * 0.55);
    path.lineTo(size.width * 0.45, size.height * 0.7);
    path.lineTo(size.width * 0.75, size.height * 0.35);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _StrikeThroughText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool checked;

  const _StrikeThroughText({
    required this.text,
    required this.style,
    required this.checked,
  });

  @override
  State<_StrikeThroughText> createState() => _StrikeThroughTextState();
}

class _StrikeThroughTextState extends State<_StrikeThroughText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    if (widget.checked) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _StrikeThroughText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      if (widget.checked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final textColor = Color.lerp(
          widget.style.color ?? U.text,
          (widget.style.color ?? U.text).withValues(alpha: 0.35),
          _animation.value,
        )!;
        return CustomPaint(
          foregroundPainter: _StrikeThroughPainter(
            progress: _animation.value,
            color: textColor,
          ),
          child: Text(
            widget.text,
            style: widget.style.copyWith(
              color: textColor,
            ),
          ),
        );
      },
    );
  }
}

class _StrikeThroughPainter extends CustomPainter {
  final double progress;
  final Color color;

  _StrikeThroughPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final y = size.height * 0.52; // centered vertically for single-line text
    final endX = size.width * progress;

    canvas.drawLine(Offset(0, y), Offset(endX, y), paint);
  }

  @override
  bool shouldRepaint(covariant _StrikeThroughPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
