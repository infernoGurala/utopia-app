import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import '../services/notification_service.dart';
import '../widgets/utopia_snackbar.dart';

class HabitEditorScreen extends StatefulWidget {
  final FocusHabit? habit; // Null in creation mode, active in edit mode

  const HabitEditorScreen({super.key, this.habit});

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  final _service = FocusSupabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _targetController;
  late TextEditingController _unitController;
  late TextEditingController _frequencyValController;

  late String _type; // 'binary' or 'measurable'
  late String _frequencyType; // 'daily', 'days_of_week', 'weekly', 'monthly', 'interval'
  late List<bool> _daysOfWeekSelect; // Mon=0 ... Sun=6
  late String _selectedColorHex;
  
  bool _reminderActive = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  final List<String> _colors = const [
    '#08BB68', // Mint Green
    '#1D9BF0', // Ocean Blue
    '#FD3D61', // Coral Pink
    '#9D4EDD', // Rich Lavender
    '#FF7E47', // Sunset Orange
    '#FFB703', // Golden Yellow
    '#00AFB9', // Soft Teal
    '#E07A5F', // Deep Peach
  ];

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isEdit => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;

    _nameController = TextEditingController(text: h?.name ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _targetController = TextEditingController(text: h?.targetValue.toStringAsFixed(0) ?? '1');
    _unitController = TextEditingController(text: h?.unit ?? '');
    _frequencyValController = TextEditingController(text: h?.frequencyValue.toString() ?? '1');

    _type = h?.type ?? 'binary';
    _frequencyType = h?.frequencyType ?? 'daily';
    
    _daysOfWeekSelect = List.generate(7, (i) {
      if (h?.daysOfWeek != null) {
        return h!.daysOfWeek!.contains(i);
      }
      return false;
    });

    _selectedColorHex = h?.color ?? '#08BB68';

    if (h?.reminderTime != null) {
      _reminderActive = true;
      try {
        final parts = h!.reminderTime!.split(':');
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _frequencyValController.dispose();
    super.dispose();
  }

  Color _colorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return U.primary;
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _colorFromHex(_selectedColorHex),
              onPrimary: Colors.white,
              surface: U.surface,
              onSurface: U.text,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: U.surface,
              dialBackgroundColor: U.bg,
              dialHandColor: _colorFromHex(_selectedColorHex),
              dialTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return U.bg;
                }
                return U.text;
              }),
              hourMinuteColor: U.bg,
              hourMinuteTextColor: U.text,
              entryModeIconColor: _colorFromHex(_selectedColorHex),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: _colorFromHex(_selectedColorHex),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: U.sub,
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descController.text.trim();
    final target = double.tryParse(_targetController.text) ?? 1.0;
    final unit = _unitController.text.trim();
    final freqVal = int.tryParse(_frequencyValController.text) ?? 1;

    final List<int> daysOfWeek = [];
    for (int i = 0; i < 7; i++) {
      if (_daysOfWeekSelect[i]) daysOfWeek.add(i);
    }

    if (_frequencyType == 'days_of_week' && daysOfWeek.isEmpty) {
      showUtopiaSnackBar(
        context,
        message: 'Please select at least one day of the week.',
        tone: UtopiaSnackBarTone.error,
      );
      return;
    }

    final reminderStr = _reminderActive
        ? '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}'
        : null;

    final id = _isEdit ? widget.habit!.id : '';
    final createdAt = _isEdit ? widget.habit!.createdAt : DateTime.now();

    final habit = FocusHabit(
      id: id,
      userId: _userId,
      name: name,
      description: description.isEmpty ? null : description,
      type: _type,
      targetValue: _type == 'binary' ? 1.0 : target,
      unit: _type == 'binary' ? null : (unit.isEmpty ? null : unit),
      frequencyType: _frequencyType,
      frequencyValue: _frequencyType == 'daily' ? 1 : freqVal,
      daysOfWeek: _frequencyType == 'days_of_week' ? daysOfWeek : null,
      reminderTime: reminderStr,
      color: _selectedColorHex,
      isArchived: _isEdit ? widget.habit!.isArchived : false,
      syncStatus: 'pending',
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      final saved = await _service.saveHabit(habit);
      
      // Handle local push alarm updates!
      if (reminderStr != null) {
        // Build FocusReminder helper model
        final reminderModel = FocusReminder(
          id: saved.id,
          userId: _userId,
          label: saved.name,
          description: saved.description,
          habitId: saved.id,
          type: saved.frequencyType == 'daily' ? 'daily' : 'weekly',
          reminderTime: reminderStr,
          weekdays: saved.daysOfWeek,
          isActive: true,
        );
        await NotificationService.scheduleFocusReminder(reminderModel);
      } else {
        await NotificationService.cancelFocusReminder(saved.id);
      }

      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: _isEdit ? 'Habit updated successfully!' : 'Habit created successfully!',
          tone: UtopiaSnackBarTone.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Save habit failed: $e');
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Error saving habit: $e',
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _archiveHabit() async {
    if (!_isEdit) return;
    
    final h = widget.habit!;
    final isArchived = h.isArchived;
    final updated = h.copyWith(isArchived: !isArchived, syncStatus: 'pending', updatedAt: DateTime.now());
    
    try {
      await _service.saveHabit(updated);
      if (updated.isArchived) {
        await NotificationService.cancelFocusReminder(updated.id);
      }
      
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message: updated.isArchived ? 'Habit archived successfully!' : 'Habit unarchived successfully!',
          tone: UtopiaSnackBarTone.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Archive habit failed: $e');
    }
  }

  Future<void> _deleteHabit() async {
    if (!_isEdit) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Delete Habit?', style: GoogleFonts.plusJakartaSans(color: U.text, fontWeight: FontWeight.bold)),
        content: Text('This will permanently delete this habit and all its historical records.', style: GoogleFonts.plusJakartaSans(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.plusJakartaSans(color: U.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteHabit(widget.habit!.id);
        await NotificationService.cancelFocusReminder(widget.habit!.id);
        
        if (mounted) {
          showUtopiaSnackBar(
            context,
            message: 'Habit deleted permanently.',
            tone: UtopiaSnackBarTone.success,
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint('Delete habit failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _colorFromHex(_selectedColorHex);
    final isDark = appThemeNotifier.value.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(themeColor),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _buildFormFields(themeColor),
                      const SizedBox(height: 24),
                      _buildTypeSelector(themeColor),
                      const SizedBox(height: 24),
                      _buildScheduleSelector(themeColor),
                      const SizedBox(height: 24),
                      _buildColorSelector(),
                      const SizedBox(height: 24),
                      _buildReminderSelector(themeColor),
                      const SizedBox(height: 36),
                      _buildActionButtons(themeColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
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
              child: Icon(Icons.close_rounded, color: U.primary, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _isEdit ? 'Edit Habit' : 'New Habit',
              style: GoogleFonts.newsreader(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: U.text,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.check_rounded, color: themeColor, size: 28),
            onPressed: _saveHabit,
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HABIT DETAILS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: U.dim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        TextSelectionTheme(
          data: TextSelectionThemeData(cursorColor: themeColor, selectionColor: themeColor.withValues(alpha: 0.15), selectionHandleColor: themeColor),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Habit name (e.g. Read Books)',
                  fillColor: U.surface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border, width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border, width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 1.2)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Question/Description (e.g. Did you read today?)',
                  fillColor: U.surface,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border, width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border, width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HABIT GOAL TYPE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: U.dim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                'binary',
                'Yes / No',
                'Simply complete or fail daily',
                Icons.check_circle_outline_rounded,
                themeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeCard(
                'measurable',
                'Measurable',
                'Log quantities like ml, pages, km',
                Icons.analytics_outlined,
                themeColor,
              ),
            ),
          ],
        ),
        if (_type == 'measurable') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(cursorColor: themeColor, selectionHandleColor: themeColor),
                  child: TextFormField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (_type != 'measurable') return null;
                      final v = double.tryParse(val ?? '');
                      if (v == null || v <= 0) return 'Invalid target';
                      return null;
                    },
                    style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Target value (e.g. 50)',
                      fillColor: U.surface,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(cursorColor: themeColor, selectionHandleColor: themeColor),
                  child: TextFormField(
                    controller: _unitController,
                    style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Unit of measurement (e.g. pages)',
                      fillColor: U.surface,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTypeCard(String typeKey, String label, String sub, IconData icon, Color themeColor) {
    final isSelected = _type == typeKey;
    return GestureDetector(
      onTap: () => setState(() => _type = typeKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.1) : U.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? themeColor : U.border.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isSelected ? themeColor : U.sub, size: 24),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSelector(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FREQUENCY SCHEDULE',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: U.dim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _frequencyType,
          dropdownColor: U.surface,
          decoration: InputDecoration(
            fillColor: U.surface,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border, width: 0.5)),
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _frequencyType = val;
              });
            }
          },
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Every single day')),
            DropdownMenuItem(value: 'days_of_week', child: Text('Specific days of the week')),
            DropdownMenuItem(value: 'weekly', child: Text('Specific times per week')),
            DropdownMenuItem(value: 'monthly', child: Text('Specific times per month')),
            DropdownMenuItem(value: 'interval', child: Text('Custom interval (Every X days)')),
          ],
        ),
        if (_frequencyType == 'days_of_week') ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final weekLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final isSelected = _daysOfWeekSelect[i];
              return GestureDetector(
                onTap: () => setState(() {
                  _daysOfWeekSelect[i] = !_daysOfWeekSelect[i];
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? themeColor : U.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? themeColor : U.border.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    weekLetters[i],
                    style: GoogleFonts.plusJakartaSans(
                      color: isSelected ? Colors.white : U.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
        if (_frequencyType == 'weekly' || _frequencyType == 'monthly' || _frequencyType == 'interval') ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _frequencyType == 'weekly'
                      ? 'Times per week:'
                      : _frequencyType == 'monthly'
                          ? 'Times per month:'
                          : 'Interval cycle (e.g. Every 3 days):',
                  style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextSelectionTheme(
                  data: TextSelectionThemeData(cursorColor: themeColor),
                  child: TextFormField(
                    controller: _frequencyValController,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (_frequencyType == 'daily' || _frequencyType == 'days_of_week') return null;
                      final v = int.tryParse(val ?? '');
                      if (v == null || v <= 0) return 'Invalid';
                      if (_frequencyType == 'weekly' && v > 7) return '<= 7';
                      if (_frequencyType == 'monthly' && v > 31) return '<= 31';
                      return null;
                    },
                    style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 16),
                    decoration: InputDecoration(
                      fillColor: U.surface,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildColorSelector() {
    final isDark = appThemeNotifier.value.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HABIT ACCENT COLOR',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: U.dim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _colors.length,
            itemBuilder: (ctx, i) {
              final hex = _colors[i];
              final isSelected = _selectedColorHex == hex;
              final col = _colorFromHex(hex);
              return GestureDetector(
                onTap: () => setState(() => _selectedColorHex = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2.2)
                        : Border.all(color: Colors.transparent),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSelector(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REMINDERS',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: U.dim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: U.border.withValues(alpha: 0.4), width: 0.8),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: _reminderActive ? themeColor : U.sub),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Reminder Alarm',
                      style: GoogleFonts.plusJakartaSans(color: U.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (_reminderActive) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: _selectTime,
                        child: Text(
                          _reminderTime.format(context),
                          style: GoogleFonts.plusJakartaSans(color: themeColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: _reminderActive,
                activeThumbColor: themeColor,
                activeTrackColor: themeColor.withValues(alpha: 0.5),
                onChanged: (v) {
                  setState(() {
                    _reminderActive = v;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color themeColor) {
    if (!_isEdit) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _saveHabit,
          child: Text(
            'Create Habit',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      );
    }

    final isArchived = widget.habit!.isArchived;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _saveHabit,
            child: Text(
              'Save Changes',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: U.text,
                    side: BorderSide(color: U.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _archiveHabit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text(isArchived ? 'Unarchive' : 'Archive', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: U.red,
                    side: BorderSide(color: U.red.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _deleteHabit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
