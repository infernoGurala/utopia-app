import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/writer_firestore_service.dart';
import '../widgets/utopia_snackbar.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  static const _dayKeys = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
  ];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  late final TabController _tabController;
  final Map<String, _DaySchedule> _schedules = {
    for (final day in _dayKeys) day: const _DaySchedule(),
  };

  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _dayKeys.length,
      vsync: this,
      initialIndex: _initialDayIndex(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTimetable();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _initialDayIndex() {
    final weekday = DateTime.now().weekday;
    if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
      return weekday - 1;
    }
    return 0;
  }

  Future<void> _loadTimetable({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final raw = await WriterFirestoreService.fetchConfig('timetable');
      if (raw is! Map<String, dynamic>) {
        throw Exception('Unexpected timetable format.');
      }

      for (final day in _dayKeys) {
        _schedules[day] = _parseDay(raw, day);
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
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
    } finally {
      if (mounted && refresh) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  _DaySchedule _parseDay(Map<String, dynamic> raw, String dayKey) {
    final direct = raw[dayKey];
    final lower = raw[dayKey.toLowerCase()];
    final source = direct ?? lower;
    if (source is! Map) {
      return const _DaySchedule();
    }

    final data = Map<String, dynamic>.from(source);
    return _DaySchedule(
      morning: _parseEntries(data['morning']),
      afternoon: _parseEntries(data['afternoon']),
      mustCarry: _parseCarry(data['must_carry']),
    );
  }

  List<_ClassEntry> _parseEntries(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw.map<_ClassEntry>((item) {
      if (item is Map) {
        final data = Map<String, dynamic>.from(item);
        return _ClassEntry(
          subject: (data['subject'] ?? '').toString(),
          time: (data['time'] ?? '').toString(),
        );
      }
      return const _ClassEntry(subject: '', time: '');
    }).where((entry) {
      return entry.subject.trim().isNotEmpty || entry.time.trim().isNotEmpty;
    }).toList();
  }

  List<String> _parseCarry(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: U.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: U.primary.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: U.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: U.text,
          ),
        ),
      ],
    );
  }

  Widget _buildClassSection({
    required String title,
    required IconData icon,
    required List<_ClassEntry> entries,
    required String emptyText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? U.card : U.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: U.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, icon),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Text(
              emptyText,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: U.sub,
              ),
            )
          else
            ...List.generate(entries.length, (index) {
              final entry = entries[index];
              final isLast = index == entries.length - 1;
              return Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: U.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        entry.time.trim().isEmpty ? '--' : entry.time.trim(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: U.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        entry.subject.trim().isEmpty
                            ? 'Class'
                            : entry.subject.trim(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: U.text,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCarrySection(List<String> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? U.card : U.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: U.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Must Carry', Icons.backpack_outlined),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'No carry items listed for this day.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: U.sub,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF223049).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF324A72)),
                      ),
                      child: Text(
                        item,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD9E7FF),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDayView(String dayKey) {
    final schedule = _schedules[dayKey] ?? const _DaySchedule();
    final dayLabel = _dayLabels[_dayKeys.indexOf(dayKey)];
    final isToday = _dayKeys[_initialDayIndex()] == dayKey;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                U.primary.withValues(alpha: 0.22),
                isDark ? U.card : U.surface,
                U.bg,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: U.border.withValues(alpha: 0.95)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  isToday ? '$dayLabel • Today' : dayLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: U.text.withValues(alpha: 0.82),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Daily Timetable',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: U.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Custom timetables coming in v3.2',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: U.primary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOut),
        const SizedBox(height: 16),
        _buildClassSection(
          title: 'Morning',
          icon: Icons.wb_sunny_outlined,
          entries: schedule.morning,
          emptyText: 'No morning classes listed.',
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 500.ms)
        .slideY(begin: 0.05, end: 0, delay: 100.ms, duration: 500.ms, curve: Curves.easeOut),
        const SizedBox(height: 16),
        _buildClassSection(
          title: 'Afternoon',
          icon: Icons.wb_twilight_outlined,
          entries: schedule.afternoon,
          emptyText: 'No afternoon classes listed.',
        )
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms)
        .slideY(begin: 0.05, end: 0, delay: 200.ms, duration: 500.ms, curve: Curves.easeOut),
        const SizedBox(height: 16),
        _buildCarrySection(schedule.mustCarry)
        .animate()
        .fadeIn(delay: 300.ms, duration: 500.ms)
        .slideY(begin: 0.05, end: 0, delay: 300.ms, duration: 500.ms, curve: Curves.easeOut),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeNotifier,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: U.bg,
          appBar: AppBar(
            backgroundColor: U.bg,
            foregroundColor: U.text,
            title: const Text('Timetable'),
            actions: [
              IconButton(
                onPressed: _refreshing ? null : () => _loadTimetable(refresh: true),
                tooltip: 'Refresh',
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
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
                    labelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: _dayLabels.map((label) => Tab(text: label)).toList(),
                  ),
                ),
              ),
            ),
          ),
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCBA6F7)),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _dayKeys.map(_buildDayView).toList(),
                ),
        );
      },
    );
  }
}

class _DaySchedule {
  const _DaySchedule({
    this.morning = const [],
    this.afternoon = const [],
    this.mustCarry = const [],
  });

  final List<_ClassEntry> morning;
  final List<_ClassEntry> afternoon;
  final List<String> mustCarry;
}

class _ClassEntry {
  const _ClassEntry({
    required this.subject,
    required this.time,
  });

  final String subject;
  final String time;
}
