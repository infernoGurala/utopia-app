import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import 'heatmap_home_screen.dart';


class DailyNoteScreen extends StatefulWidget {
  const DailyNoteScreen({super.key});
  @override
  State<DailyNoteScreen> createState() => _DailyNoteScreenState();
}

class _DailyNoteScreenState extends State<DailyNoteScreen> {
  final _service = FocusSupabaseService();
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _editMode = false;
  bool _loading = true;
  FocusNote? _note;
  String _content = '';
  final _editController = TextEditingController();
  final _scrollController = ScrollController();
  Set<String> _noteDates = {};



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
    await _loadNote();
    await _loadMonthDots();
  }

  Future<void> _loadNote() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final dateStr = _dateStr(_selectedDate);
    final note = await _service.loadNote(dateStr);
    if (!mounted) return;
    setState(() {
      _note = note;
      _content = note?.content ?? '';
      _editController.text = _content;
      _loading = false;
    });
  }

  Future<void> _loadMonthDots() async {
    final start = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final end = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0); // last day
    final dates = await _service.getNoteDates(_dateStr(start), _dateStr(end));
    if (mounted) setState(() => _noteDates = dates);
  }



  Future<void> _saveNote() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final dateStr = _dateStr(_selectedDate);
    final note = FocusNote(
      id: _note?.id,
      userId: userId,
      date: dateStr,
      content: _content,
    );
    await _service.saveNote(note);
    await _loadNote();
    await _loadMonthDots();
  }

  void _toggleEditMode() {
    if (_editMode) {
      // Switching to read mode — save
      _content = _editController.text;
      _saveNote();
    } else {
      _editController.text = _content;
    }
    setState(() => _editMode = !_editMode);
  }

  void _onCheckboxToggle(String line, bool? value) {
    final lines = _content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == line.trim()) {
        if (value == true) {
          lines[i] = lines[i].replaceFirst('- [ ]', '- [x]');
        } else {
          lines[i] = lines[i].replaceFirst('- [x]', '- [ ]');
        }
        break;
      }
    }
    _content = lines.join('\n');
    _saveNote();
    setState(() {});
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadNote();
  }



  Future<void> _createFromTemplate() async {
    final template = await _service.getTemplate();
    _content = template;
    _editController.text = _content;
    setState(() => _editMode = true);
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 32, height: 4, decoration: BoxDecoration(color: U.dim, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            _menuItem(Icons.edit_note_rounded, 'Edit Template', () {
              Navigator.pop(ctx);
              _editTemplate();
            }),
            _menuItem(Icons.restart_alt_rounded, 'Reset Note to Template', () {
              Navigator.pop(ctx);
              _resetCurrentNote();
            }),
            if (_note != null)
              _menuItem(Icons.delete_outline_rounded, 'Delete Note', () {
                Navigator.pop(ctx);
                _confirmDeleteNote();
              }, isDestructive: true),
            const SizedBox(height: 16),
          ],
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

  Future<void> _editTemplate() async {
    final template = await _service.getTemplate();
    final controller = TextEditingController(text: template);
    if (!mounted) return;
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
                    Text('Edit Template', style: GoogleFonts.playfairDisplay(color: U.text, fontSize: 20, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: U.sub, size: 20),
                      tooltip: 'Reset to Default',
                      onPressed: () {
                        controller.text = FocusSupabaseService.defaultTemplate;
                      },
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text('Save', style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
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
    if (result != null) {
      await _service.saveTemplate(result);
    }
  }

  Future<void> _resetCurrentNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Reset Note?', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Text('This will replace the current note with your saved template.', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Reset', style: GoogleFonts.outfit(color: U.red))),
        ],
      ),
    );
    if (confirmed == true) {
      _content = await _service.getTemplate();
      _editController.text = _content;
      await _saveNote();
      setState(() {});
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
      await _loadNote();
      await _loadMonthDots();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      endDrawer: _buildCalendarDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Expanded(child: _loading ? _buildLoading() : _buildNoteBody()),
              ],
            ),
            // The Ribbon
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Builder(
                builder: (ctx) => GestureDetector(
                  onPanUpdate: (details) {
                    if (details.delta.dx < -5) {
                      Scaffold.of(ctx).openEndDrawer();
                    }
                  },
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, U.primary.withValues(alpha: 0.15)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 48,
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded, color: U.text),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minWidth: 32),
              ),
              Text('Daily Note', style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
              const Spacer(),
              IconButton(
                onPressed: _toggleEditMode,
                icon: Icon(_editMode ? Icons.visibility_outlined : Icons.edit_outlined, color: U.sub, size: 22),
              ),
              Builder(
                builder: (ctx) => IconButton(
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  icon: Icon(Icons.calendar_today_rounded, color: U.sub, size: 20),
                ),
              ),
              IconButton(onPressed: _showMenu, icon: Icon(Icons.more_vert_rounded, color: U.sub, size: 22)),
            ],
          ),
          const SizedBox(height: 8),
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
                      if (isSelected) textColor = U.primary;
                      else if (isToday) textColor = U.text;
                      else if (date.isBefore(today) || isToday) textColor = const Color(0xFF88A0B0); // past days tint

                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          if (hasNote) {
                            _selectDate(date);
                          } else {
                            // Ask user if they want to create a note
                            final create = await showDialog<bool>(
                              context: this.context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: U.surface,
                                title: Text('Create Note?', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
                                content: Text(
                                  'No note exists for ${date.day}/${date.month}/${date.year}. Create one from your template?',
                                  style: GoogleFonts.outfit(color: U.sub),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Just View', style: GoogleFonts.outfit(color: U.sub))),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Create', style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600))),
                                ],
                              ),
                            );
                            _selectDate(date);
                            if (create == true) {
                              final template = await _service.getTemplate();
                              _content = template;
                              _editController.text = _content;
                              await _saveNote();
                              setState(() {});
                            }
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
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
                                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF00B4D8), shape: BoxShape.circle)),
                                    const SizedBox(width: 2),
                                    Container(width: 4, height: 4, decoration: BoxDecoration(color: const Color(0xFF00B4D8).withValues(alpha: 0.4), shape: BoxShape.circle)),
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
    if (_editMode) return _buildEditMode();
    if (_content.isEmpty) return _buildEmptyState();
    return _buildReadMode();
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: _createFromTemplate,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDateLabel(),
              const SizedBox(height: 32),
              Text('Tap the pencil to start writing.', style: GoogleFonts.outfit(color: U.dim, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateLabel() {
    const dayFull = ['', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dayFull[_selectedDate.weekday], style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: U.primary, letterSpacing: 2)),
        const SizedBox(height: 2),
        Text('${_selectedDate.day} ${monthNames[_selectedDate.month]} ${_selectedDate.year}',
          style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
      ],
    );
  }

  Widget _buildEditMode() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _editController,
        maxLines: null,
        expands: true,
        style: GoogleFonts.jetBrainsMono(color: U.text, fontSize: 14, height: 1.7),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildReadMode() {
    final sections = _parseSections(_content);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        _buildDateLabel(),
        const SizedBox(height: 24),
        ...sections,
      ],
    );
  }

  List<Widget> _parseSections(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('## ')) {
        final heading = trimmed.substring(3);
        currentSection = heading.toLowerCase();
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(heading, style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, color: U.primary)),
        ));
        continue;
      }

      // Checkbox items
      final checkedMatch = RegExp(r'^- \[x\] (.+)$', caseSensitive: false).firstMatch(trimmed);
      final uncheckedMatch = RegExp(r'^- \[ \] (.+)$').firstMatch(trimmed);

      if (checkedMatch != null) {
        final label = checkedMatch.group(1)!.trim();
        widgets.add(_buildCheckItem(label, true, true, line));
      } else if (uncheckedMatch != null) {
        final label = uncheckedMatch.group(1)!.trim();
        widgets.add(_buildCheckItem(label, false, true, line));
      } else if (trimmed.isNotEmpty) {
        // Plain text (journal)
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildMarkdownText(trimmed),
        ));
      }
    }

    return widgets;
  }

  Widget _buildCheckItem(String label, bool checked, bool isTask, String rawLine) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _onCheckboxToggle(rawLine, !checked),
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
        ],
      ),
    );
  }

  Widget _buildMarkdownText(String text) {
    // Simple markdown rendering for journal section
    TextStyle style = GoogleFonts.outfit(color: U.text, fontSize: 15, height: 1.6);

    // Bold
    if (text.contains('**')) {
      return Text.rich(_parseInlineMarkdown(text), style: style);
    }

    return Text(text, style: style);
  }

  TextSpan _parseInlineMarkdown(String text) {
    final spans = <InlineSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        spans.add(TextSpan(text: parts[i], style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: U.text)));
      } else {
        // Handle italic within non-bold parts
        final italicParts = parts[i].split('_');
        for (int j = 0; j < italicParts.length; j++) {
          if (j.isOdd) {
            spans.add(TextSpan(text: italicParts[j], style: GoogleFonts.outfit(fontStyle: FontStyle.italic, color: U.text)));
          } else {
            spans.add(TextSpan(text: italicParts[j]));
          }
        }
      }
    }
    return TextSpan(children: spans);
  }
}
