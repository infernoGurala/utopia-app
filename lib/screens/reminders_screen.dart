
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _service = FocusSupabaseService();
  List<FocusReminder> _reminders = [];
  bool _loading = true;
  DateTime _selectedDay = DateTime.now();
  DateTime _weekStart = _getWeekStart(DateTime.now());
  bool _filterActive = false;
  bool _showPast = false;

  static DateTime _getWeekStart(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await _service.getReminders();
    if (mounted) setState(() { _reminders = reminders; _loading = false; });
  }

  List<FocusReminder> get _upcoming {
    final now = DateTime.now();
    return _reminders.where((r) {
      if (r.type == 'one_time' && r.remindDate != null) {
        return !DateTime.parse(r.remindDate!).isBefore(DateTime(now.year, now.month, now.day));
      }
      return false;
    }).toList()
      ..sort((a, b) => (a.remindDate ?? '').compareTo(b.remindDate ?? ''));
  }

  List<FocusReminder> get _recurring {
    return _reminders.where((r) => r.type == 'weekly' || r.type == 'monthly_date').toList();
  }

  List<FocusReminder> get _past {
    final now = DateTime.now();
    return _reminders.where((r) {
      if (r.type == 'one_time' && r.remindDate != null) {
        return DateTime.parse(r.remindDate!).isBefore(DateTime(now.year, now.month, now.day));
      }
      return false;
    }).toList();
  }

  void _shiftWeek(int dir) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * dir)));
  }

  void _onDayTap(DateTime day) {
    if (day == _selectedDay && _filterActive) {
      setState(() => _filterActive = false);
    } else {
      setState(() { _selectedDay = day; _filterActive = true; });
    }
  }

  Future<void> _deleteReminder(FocusReminder r) async {
    if (r.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Delete Reminder?', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Text('Delete "${r.label}"?', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.outfit(color: U.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteReminder(r.id!);
      _load();
    }
  }

  void _showReminderSheet({FocusReminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ReminderForm(
        existing: existing,
        onSave: (r) async {
          Navigator.pop(ctx);
          await _service.saveReminder(r);
          _load();
        },
        onDelete: existing != null ? () async {
          Navigator.pop(ctx);
          if (existing.id != null) {
            await _service.deleteReminder(existing.id!);
            _load();
          }
        } : null,
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: U.text)),
                  const SizedBox(width: 4),
                  Text('Reminders', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic, color: U.text)),
                  const Spacer(),
                  IconButton(onPressed: () => _showReminderSheet(), icon: Icon(Icons.add_rounded, color: U.primary, size: 26)),
                ],
              ),
            ),
            // Week strip
            _buildWeekStrip(),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: U.primary))
                  : _reminders.isEmpty
                      ? Center(child: Text('No reminders yet. Tap + to add one.', style: GoogleFonts.outfit(color: U.dim, fontSize: 14)))
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStrip() {
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final today = DateTime.now();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity != null) _shiftWeek(d.primaryVelocity! < 0 ? 1 : -1);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = _weekStart.add(Duration(days: i));
              final isSelected = _filterActive && day.year == _selectedDay.year && day.month == _selectedDay.month && day.day == _selectedDay.day;
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;

              return GestureDetector(
                onTap: () => _onDayTap(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? U.primary.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(dayNames[i], style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? U.primary : U.dim, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text('${day.day}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? U.primary : (isToday ? U.text : U.sub))),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final upcoming = _upcoming;
    final recurring = _recurring;
    final past = _past;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      children: [
        if (upcoming.isNotEmpty) ...[
          _sectionLabel('UPCOMING'),
          ...upcoming.map((r) => _reminderTile(r)),
        ],
        if (recurring.isNotEmpty) ...[
          _sectionLabel('RECURRING'),
          ...recurring.map((r) => _reminderTile(r)),
        ],
        if (past.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _showPast = !_showPast),
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(
                children: [
                  Text('PAST', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: U.dim, letterSpacing: 1.5)),
                  const SizedBox(width: 4),
                  Icon(_showPast ? Icons.expand_less : Icons.chevron_right, size: 16, color: U.dim),
                ],
              ),
            ),
          ),
          if (_showPast) ...past.map((r) => _reminderTile(r)),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: U.dim, letterSpacing: 1.5)),
    );
  }

  Widget _reminderTile(FocusReminder r) {
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete_outline, color: U.red),
      ),
      confirmDismiss: (_) async {
        await _deleteReminder(r);
        return false; // handled by reload
      },
      child: InkWell(
        onTap: () => _showReminderSheet(existing: r),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label, style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w400)),
              const SizedBox(height: 2),
              Text(r.scheduleSummary, style: GoogleFonts.outfit(color: U.dim, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────── Reminder Form ────────────────────────────

class _ReminderForm extends StatefulWidget {
  final FocusReminder? existing;
  final Future<void> Function(FocusReminder) onSave;
  final VoidCallback? onDelete;

  const _ReminderForm({this.existing, required this.onSave, this.onDelete});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late final TextEditingController _labelController;
  String _type = 'one_time';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _weekdays = {};
  int _monthDay = 1;
  Set<int> _activeMonths = {};
  bool _allMonths = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelController = TextEditingController(text: e?.label ?? '');
    if (e != null) {
      _type = e.type;
      if (e.remindDate != null) _date = DateTime.parse(e.remindDate!);
      final timeParts = e.reminderTime.split(':');
      _time = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      _weekdays = Set.from(e.weekdays ?? []);
      _monthDay = e.monthDay ?? 1;
      _activeMonths = Set.from(e.activeMonths ?? []);
      _allMonths = e.activeMonths == null || e.activeMonths!.isEmpty;
    }
  }

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _timeStr => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _save() {
    if (_labelController.text.trim().isEmpty) return;
    final sortedWeekdays = _type == 'weekly' ? (_weekdays.toList()..sort()) : null;
    final sortedMonths = (_type == 'monthly_date' && !_allMonths) ? (_activeMonths.toList()..sort()) : null;
    final reminder = FocusReminder(
      id: widget.existing?.id ?? const Uuid().v4(),
      userId: _userId,
      label: _labelController.text.trim(),
      type: _type,
      reminderTime: _timeStr,
      remindDate: _type == 'one_time' ? _dateStr(_date) : null,
      weekdays: sortedWeekdays,
      monthDay: _type == 'monthly_date' ? _monthDay : null,
      activeMonths: sortedMonths,
      isActive: true,
    );
    widget.onSave(reminder);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 32, height: 4, decoration: BoxDecoration(color: U.dim, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            // Label
            TextField(
              controller: _labelController,
              style: GoogleFonts.outfit(color: U.text, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What do you want to be reminded about?',
                hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            // Type pills
            Row(
              children: [
                _typePill('One-time', 'one_time'),
                const SizedBox(width: 8),
                _typePill('Weekly', 'weekly'),
                const SizedBox(width: 8),
                _typePill('Monthly', 'monthly_date'),
              ],
            ),
            const SizedBox(height: 20),
            // Config
            if (_type == 'one_time') _buildDatePicker(),
            if (_type == 'weekly') _buildWeekdaySelector(),
            if (_type == 'monthly_date') _buildMonthlyConfig(),
            const SizedBox(height: 12),
            _buildTimePicker(),
            const SizedBox(height: 24),
            // Summary
            Text(_buildSummary(), style: GoogleFonts.outfit(color: U.sub, fontSize: 13, fontStyle: FontStyle.italic)),
            const SizedBox(height: 20),
            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _save, child: Text('Save Reminder', style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: widget.onDelete,
                  child: Text('Delete Reminder', style: GoogleFonts.outfit(color: U.red, fontSize: 14)),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _typePill(String label, String value) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? U.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? U.primary : U.border),
        ),
        child: Text(label, style: GoogleFonts.outfit(color: selected ? U.primary : U.sub, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDatePicker() {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: U.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: U.border)),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: U.sub),
            const SizedBox(width: 12),
            Text('${_date.day} ${months[_date.month]} ${_date.year}', style: GoogleFonts.outfit(color: U.text, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final ampm = _time.period == DayPeriod.am ? 'AM' : 'PM';
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: _time);
        if (picked != null) setState(() => _time = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: U.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: U.border)),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: U.sub),
            const SizedBox(width: 12),
            Text('$hour:${_time.minute.toString().padLeft(2, '0')} $ampm', style: GoogleFonts.outfit(color: U.text, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(7, (i) {
        final selected = _weekdays.contains(i);
        return GestureDetector(
          onTap: () => setState(() { selected ? _weekdays.remove(i) : _weekdays.add(i); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? U.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? U.primary : U.border),
            ),
            child: Text(days[i], style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? U.primary : U.sub)),
          ),
        );
      }),
    );
  }

  Widget _buildMonthlyConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day number
        Row(
          children: [
            Text('Day of month:', style: GoogleFonts.outfit(color: U.sub, fontSize: 14)),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: TextField(
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                decoration: InputDecoration(hintText: '1', hintStyle: GoogleFonts.outfit(color: U.dim)),
                controller: TextEditingController(text: '$_monthDay'),
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1 && n <= 28) _monthDay = n;
                },
              ),
            ),
            const SizedBox(width: 8),
            Text('(1–28)', style: GoogleFonts.outfit(color: U.dim, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        // Month scope
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _allMonths = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _allMonths ? U.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _allMonths ? U.primary : U.border),
                ),
                child: Text('All months', style: GoogleFonts.outfit(color: _allMonths ? U.primary : U.sub, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _allMonths = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: !_allMonths ? U.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: !_allMonths ? U.primary : U.border),
                ),
                child: Text('Specific', style: GoogleFonts.outfit(color: !_allMonths ? U.primary : U.sub, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        if (!_allMonths) ...[
          const SizedBox(height: 12),
          _buildMonthSelector(),
        ],
      ],
    );
  }

  Widget _buildMonthSelector() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(12, (i) {
        final m = i + 1;
        final selected = _activeMonths.contains(m);
        return GestureDetector(
          onTap: () => setState(() { selected ? _activeMonths.remove(m) : _activeMonths.add(m); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? U.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? U.primary : U.border),
            ),
            child: Text(months[i], style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? U.primary : U.sub)),
          ),
        );
      }),
    );
  }

  String _buildSummary() {
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final ampm = _time.period == DayPeriod.am ? 'AM' : 'PM';
    final timeStr = '$hour:${_time.minute.toString().padLeft(2, '0')} $ampm';
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    switch (_type) {
      case 'one_time':
        return '${_date.day} ${months[_date.month]} ${_date.year} at $timeStr';
      case 'weekly':
        if (_weekdays.isEmpty) return 'Select days';
        final days = (_weekdays.toList()..sort()).map((d) => dayNames[d]).join(', ');
        return 'Every $days at $timeStr';
      case 'monthly_date':
        if (_allMonths) return 'Every ${_monthDay}${_ordinal(_monthDay)} at $timeStr';
        if (_activeMonths.isEmpty) return 'Select months';
        final ms = (_activeMonths.toList()..sort()).map((m) => months[m]).join(', ');
        return 'Every ${_monthDay}${_ordinal(_monthDay)} of $ms at $timeStr';
      default:
        return '';
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }
}
