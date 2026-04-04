import 'package:flutter/material.dart';

import '../services/writer_github_service.dart';
import '../widgets/utopia_snackbar.dart';

class TimetableEditorScreen extends StatefulWidget {
  const TimetableEditorScreen({super.key});

  @override
  State<TimetableEditorScreen> createState() => _TimetableEditorScreenState();
}

class _TimetableEditorScreenState extends State<TimetableEditorScreen>
    with TickerProviderStateMixin {
  static const _dayKeys = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  bool _loading = true;
  bool _saving = false;
  late final TabController _tabController;
  late final Map<String, _DayScheduleState> _schedules;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dayKeys.length, vsync: this);
    _schedules = {
      for (final day in _dayKeys) day: _DayScheduleState.empty(),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTimetable();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final schedule in _schedules.values) {
      schedule.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    try {
      final data = await WriterGitHubService.fetchRawJson('timetable.json');
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      if (data is Map<String, dynamic>) {
        for (final day in _dayKeys) {
          final schedule = _extractDaySchedule(data, day);
          _schedules[day]?.replaceWith(schedule);
        }
        if (mounted) {
          setState(() {});
        }
      } else {
        throw Exception('Unexpected timetable format.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      showUtopiaSnackBar(
        context,
        message: 'Could not load timetable',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  _DayScheduleState _extractDaySchedule(Map<String, dynamic> data, String day) {
    final raw = _pickDayMap(data, day);
    final morning = _extractClassList(raw['morning']);
    final afternoon = _extractClassList(raw['afternoon']);
    final mustCarry = _extractStringList(raw['must_carry']);
    return _DayScheduleState.fromData(
      morning: morning,
      afternoon: afternoon,
      mustCarry: mustCarry,
    );
  }

  Map<String, dynamic> _pickDayMap(Map<String, dynamic> data, String day) {
    final direct = data[day];
    if (direct is Map<String, dynamic>) {
      return Map<String, dynamic>.from(direct);
    }
    return <String, dynamic>{};
  }

  List<_ClassEntryData> _extractClassList(dynamic rawList) {
    if (rawList is! List) {
      return [];
    }
    return rawList.map<_ClassEntryData>((item) {
      if (item is Map<String, dynamic>) {
        return _ClassEntryData(
          subject: (item['subject'] ?? '').toString(),
          time: (item['time'] ?? '').toString(),
        );
      }
      return _ClassEntryData(subject: '', time: '');
    }).toList();
  }

  List<String> _extractStringList(dynamic rawList) {
    if (rawList is! List) {
      return [];
    }
    return rawList.map((item) => item.toString()).toList();
  }

  Future<void> _saveTimetable() async {
    setState(() {
      _saving = true;
    });

    try {
      final json = <String, dynamic>{};
      for (final day in _dayKeys) {
        final schedule = _schedules[day]!;
        json[day] = {
          'morning': schedule.morning
              .map((entry) => entry.toJson())
              .where((entry) =>
                  (entry['subject'] ?? '').trim().isNotEmpty ||
                  (entry['time'] ?? '').trim().isNotEmpty)
              .toList(),
          'afternoon': schedule.afternoon
              .map((entry) => entry.toJson())
              .where((entry) =>
                  (entry['subject'] ?? '').trim().isNotEmpty ||
                  (entry['time'] ?? '').trim().isNotEmpty)
              .toList(),
          'must_carry': schedule.mustCarry
              .map((controller) => controller.text.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        };
      }

      await WriterGitHubService.updateJsonFile(
        filename: 'timetable.json',
        jsonData: json,
        commitMessage: 'Updated timetable via UTOPIA app',
      );

      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Timetable saved',
        tone: UtopiaSnackBarTone.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not save timetable',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _addMorningClass(String day) {
    setState(() {
      _schedules[day]!.morning.add(_ClassEntryController.empty());
    });
  }

  void _addAfternoonClass(String day) {
    setState(() {
      _schedules[day]!.afternoon.add(_ClassEntryController.empty());
    });
  }

  void _addCarryItem(String day) {
    setState(() {
      _schedules[day]!.mustCarry.add(TextEditingController());
    });
  }

  void _removeMorningClass(String day, int index) {
    setState(() {
      _schedules[day]!.removeMorningAt(index);
    });
  }

  void _removeAfternoonClass(String day, int index) {
    setState(() {
      _schedules[day]!.removeAfternoonAt(index);
    });
  }

  void _removeCarryItem(String day, int index) {
    setState(() {
      _schedules[day]!.removeCarryAt(index);
    });
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: const Color(0xFFCBA6F7),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _classRow({
    required _ClassEntryController controller,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller.subject,
              style: const TextStyle(color: Color(0xFFCDD6F4)),
              decoration: _inputDecoration('Subject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller.time,
              style: const TextStyle(color: Color(0xFFCDD6F4)),
              decoration: _inputDecoration('Time'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Color(0xFFF38BA8)),
          ),
        ],
      ),
    );
  }

  Widget _carryRow({
    required TextEditingController controller,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFFCDD6F4)),
              decoration: _inputDecoration('Item'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Color(0xFFF38BA8)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFCDD6F4)),
      filled: true,
      fillColor: const Color(0xFF313244),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF45475A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBA6F7)),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFFA6ADC8)),
      ),
    );
  }

  Widget _dayEditor(String day) {
    final schedule = _schedules[day]!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Morning Classes'),
        if (schedule.morning.isEmpty) _emptyHint('No morning classes yet.'),
        ...schedule.morning.asMap().entries.map(
          (entry) => _classRow(
            controller: entry.value,
            onDelete: () => _removeMorningClass(day, entry.key),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addMorningClass(day),
            icon: const Icon(Icons.add, color: Color(0xFFCBA6F7)),
            label: const Text(
              'Add Morning Class',
              style: TextStyle(color: Color(0xFFCBA6F7)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Afternoon Classes'),
        if (schedule.afternoon.isEmpty) _emptyHint('No afternoon classes yet.'),
        ...schedule.afternoon.asMap().entries.map(
          (entry) => _classRow(
            controller: entry.value,
            onDelete: () => _removeAfternoonClass(day, entry.key),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addAfternoonClass(day),
            icon: const Icon(Icons.add, color: Color(0xFFCBA6F7)),
            label: const Text(
              'Add Afternoon Class',
              style: TextStyle(color: Color(0xFFCBA6F7)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('Must Carry'),
        if (schedule.mustCarry.isEmpty) _emptyHint('No carry items yet.'),
        ...schedule.mustCarry.asMap().entries.map(
          (entry) => _carryRow(
            controller: entry.value,
            onDelete: () => _removeCarryItem(day, entry.key),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addCarryItem(day),
            icon: const Icon(Icons.add, color: Color(0xFFCBA6F7)),
            label: const Text(
              'Add Item',
              style: TextStyle(color: Color(0xFFCBA6F7)),
            ),
          ),
        ),
        const SizedBox(height: 96),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        foregroundColor: const Color(0xFFCDD6F4),
        title: const Text('Edit Timetable'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFCBA6F7),
          labelColor: const Color(0xFFCBA6F7),
          unselectedLabelColor: const Color(0xFFA6ADC8),
          tabs: _dayLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFCBA6F7)),
            )
          : TabBarView(
              controller: _tabController,
              children: _dayKeys.map(_dayEditor).toList(),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _saveTimetable,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCBA6F7),
                foregroundColor: const Color(0xFF11111B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF11111B),
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayScheduleState {
  _DayScheduleState({
    required this.morning,
    required this.afternoon,
    required this.mustCarry,
  });

  factory _DayScheduleState.empty() {
    return _DayScheduleState(morning: [], afternoon: [], mustCarry: []);
  }

  factory _DayScheduleState.fromData({
    required List<_ClassEntryData> morning,
    required List<_ClassEntryData> afternoon,
    required List<String> mustCarry,
  }) {
    return _DayScheduleState(
      morning: morning.map(_ClassEntryController.fromData).toList(),
      afternoon: afternoon.map(_ClassEntryController.fromData).toList(),
      mustCarry: mustCarry
          .map((item) => TextEditingController(text: item))
          .toList(),
    );
  }

  final List<_ClassEntryController> morning;
  final List<_ClassEntryController> afternoon;
  final List<TextEditingController> mustCarry;

  void replaceWith(_DayScheduleState other) {
    dispose();
    morning
      ..clear()
      ..addAll(other.morning);
    afternoon
      ..clear()
      ..addAll(other.afternoon);
    mustCarry
      ..clear()
      ..addAll(other.mustCarry);
  }

  void removeMorningAt(int index) {
    morning.removeAt(index).dispose();
  }

  void removeAfternoonAt(int index) {
    afternoon.removeAt(index).dispose();
  }

  void removeCarryAt(int index) {
    mustCarry.removeAt(index).dispose();
  }

  void dispose() {
    for (final entry in morning) {
      entry.dispose();
    }
    for (final entry in afternoon) {
      entry.dispose();
    }
    for (final item in mustCarry) {
      item.dispose();
    }
  }
}

class _ClassEntryController {
  _ClassEntryController({required this.subject, required this.time});

  factory _ClassEntryController.empty() {
    return _ClassEntryController(
      subject: TextEditingController(),
      time: TextEditingController(),
    );
  }

  factory _ClassEntryController.fromData(_ClassEntryData data) {
    return _ClassEntryController(
      subject: TextEditingController(text: data.subject),
      time: TextEditingController(text: data.time),
    );
  }

  final TextEditingController subject;
  final TextEditingController time;

  Map<String, String> toJson() => {
        'subject': subject.text.trim(),
        'time': time.text.trim(),
      };

  void dispose() {
    subject.dispose();
    time.dispose();
  }
}

class _ClassEntryData {
  _ClassEntryData({required this.subject, required this.time});

  final String subject;
  final String time;
}
