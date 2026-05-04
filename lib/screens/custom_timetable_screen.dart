import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/user_timetable.dart';
import '../services/user_timetable_service.dart';
import '../widgets/utopia_snackbar.dart';

class CustomTimetableScreen extends StatefulWidget {
  const CustomTimetableScreen({super.key});

  @override
  State<CustomTimetableScreen> createState() => _CustomTimetableScreenState();
}

class _CustomTimetableScreenState extends State<CustomTimetableScreen> with SingleTickerProviderStateMixin {
  static const _dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _defaultPeriods = [
    TimetablePeriod(period: 1, start: '09:30 AM', end: '10:20 AM'),
    TimetablePeriod(period: 2, start: '10:20 AM', end: '11:10 AM'),
    TimetablePeriod(period: 3, start: '11:10 AM', end: '12:00 PM'),
    TimetablePeriod(period: 4, start: '12:00 PM', end: '01:00 PM'),
    TimetablePeriod(period: 5, start: '01:00 PM', end: '01:50 PM'),
    TimetablePeriod(period: 6, start: '01:50 PM', end: '02:40 PM'),
    TimetablePeriod(period: 7, start: '02:40 PM', end: '03:30 PM'),
    TimetablePeriod(period: 8, start: '03:30 PM', end: '04:20 PM'),
  ];

  late final TabController _tabController;
  final Map<String, List<TextEditingController>> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _dayKeys.length, vsync: this);
    for (final day in _dayKeys) {
      _controllers[day] = List.generate(8, (_) => TextEditingController());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final list in _controllers.values) {
      for (final controller in list) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _saveTimetable() async {
    setState(() => _saving = true);
    try {
      final List<TimetableDay> week = [];
      for (final day in _dayKeys) {
        final slots = _controllers[day]!.map((c) => c.text.trim()).toList();
        week.add(TimetableDay(day: day, slots: slots));
      }

      final customTimetable = UserTimetable(
        periods: _defaultPeriods,
        week: week,
      );

      await UserTimetableService.saveTimetable(customTimetable);
      
      if (!mounted) return;
      showUtopiaSnackBar(context, message: 'Custom Timetable Saved!', tone: UtopiaSnackBarTone.success);
      Navigator.pop(context, true); // true indicates it was saved
    } catch (e) {
      showUtopiaSnackBar(context, message: 'Failed to save timetable', tone: UtopiaSnackBarTone.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildDayEditor(String day) {
    final controllers = _controllers[day]!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 8,
      itemBuilder: (context, index) {
        final p = _defaultPeriods[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? U.card : U.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: U.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'P${p.period}',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: U.primary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controllers[index],
                  style: GoogleFonts.outfit(fontSize: 16, color: U.text, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Free Period',
                    hintStyle: GoogleFonts.outfit(fontSize: 16, color: U.sub),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        foregroundColor: U.text,
        title: const Text('Custom Timetable'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: U.border),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: U.bg,
                unselectedLabelColor: U.sub,
                indicator: BoxDecoration(
                  color: U.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(999),
                labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: _dayKeys.map((label) => Tab(text: label)).toList(),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _dayKeys.map(_buildDayEditor).toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _saveTimetable,
              child: _saving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: U.bg, strokeWidth: 2))
                  : Text('Save Timetable', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}
