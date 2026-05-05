import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/user_timetable.dart';
import '../services/gas_timetable_service.dart';
import '../services/secure_storage_service.dart';
import '../services/user_timetable_service.dart';
import '../services/notification_service.dart';
import '../widgets/utopia_snackbar.dart';
import 'custom_timetable_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  static const _dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  late final TabController _tabController;
  UserTimetable? _userTimetable;
  bool _loading = true;
  bool _refreshing = false;

  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _dayKeys.length,
      vsync: this,
      initialIndex: _initialDayIndex(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _initialDayIndex() {
    final weekday = DateTime.now().weekday;
    if (weekday >= DateTime.monday && weekday <= DateTime.saturday) {
      return weekday - 1;
    }
    return 0; // default to Monday if Sunday
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) setState(() => _refreshing = true);

    try {
      _userTimetable = await UserTimetableService.getTimetable();

      final prefs = await SharedPreferences.getInstance();
      _notifEnabled = prefs.getBool('timetable_notif_enabled') ?? false;
      final h = prefs.getInt('timetable_notif_hour') ?? 7;
      final m = prefs.getInt('timetable_notif_minute') ?? 0;
      _notifTime = TimeOfDay(hour: h, minute: m);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      showUtopiaSnackBar(
        context,
        message: 'Could not load timetable',
        tone: UtopiaSnackBarTone.error,
      );
    } finally {
      if (mounted && refresh) setState(() => _refreshing = false);
    }
  }

  Future<void> _fetchFromCollege() async {
    setState(() => _loading = true);
    try {
      final creds = await SecureStorageService.getCredentials();
      if (creds == null) {
        showUtopiaSnackBar(
          context,
          message: 'Please login to attendance first to fetch timetable.',
          tone: UtopiaSnackBarTone.error,
        );
        setState(() => _loading = false);
        return;
      }
      final rawData = await GasTimetableService.fetchTimetable(
        creds['rollNumber'] ?? '',
        creds['password'] ?? '',
        creds['college'] ?? 'aus',
      );
      final newTimetable = UserTimetable.fromJson(rawData);
      await UserTimetableService.saveTimetable(newTimetable);

      showUtopiaSnackBar(
        context,
        message: 'Timetable fetched successfully!',
        tone: UtopiaSnackBarTone.success,
      );
      _loadData();
    } catch (e) {
      setState(() => _loading = false);
      showUtopiaSnackBar(
        context,
        message: 'Failed to fetch timetable: $e',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  Future<void> _toggleNotif(bool val) async {
    if (val) {
      final success =
          await NotificationService.scheduleDailyTimetableNotification(
            hour: _notifTime.hour,
            minute: _notifTime.minute,
          );
      if (!success && mounted) {
        showUtopiaSnackBar(
          context,
          message: 'Failed to schedule notification. Please try again.',
          tone: UtopiaSnackBarTone.error,
        );
        return;
      }
    } else {
      await NotificationService.cancelTimetableNotification();
    }
    setState(() => _notifEnabled = val);
  }

  Future<void> _pickNotifTime() async {
    final t = await showTimePicker(context: context, initialTime: _notifTime);
    if (t != null && mounted) {
      setState(() => _notifTime = t);
      if (_notifEnabled) {
        final success =
            await NotificationService.scheduleDailyTimetableNotification(
              hour: t.hour,
              minute: t.minute,
            );
        if (!success && mounted) {
          showUtopiaSnackBar(
            context,
            message: 'Failed to schedule notification. Please try again.',
            tone: UtopiaSnackBarTone.error,
          );
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timetable_notif_hour', t.hour);
      await prefs.setInt('timetable_notif_minute', t.minute);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child:
            Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_calendar_rounded,
                        size: 48,
                        color: U.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Timetable Found',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: U.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You can fetch your personal timetable directly from your college portal, or create a custom one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: U.sub,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: U.primary,
                          foregroundColor: U.bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _fetchFromCollege,
                        icon: const Icon(Icons.cloud_download_outlined),
                        label: Text(
                          'Fetch from College',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: U.primary,
                          side: BorderSide(
                            color: U.primary.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomTimetableScreen(),
                            ),
                          );
                          if (result == true) {
                            _loadData();
                          }
                        },
                        icon: const Icon(Icons.dashboard_customize_outlined),
                        label: Text(
                          'Create Custom',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildSettingsSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timetable Settings',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: U.text,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.notifications_active_outlined,
              color: U.primary,
            ),
            title: Text(
              'Daily Notification',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: U.text,
              ),
            ),
            subtitle: Text(
              'Get alerted about your classes',
              style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
            ),
            trailing: Switch(
              value: _notifEnabled,
              activeColor: U.primary,
              onChanged: (val) {
                _toggleNotif(val);
                Navigator.pop(context);
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.access_time_rounded,
              color: _notifEnabled ? U.primary : U.dim,
            ),
            title: Text(
              'Notification Time',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _notifEnabled ? U.text : U.dim,
              ),
            ),
            subtitle: Text(
              _notifTime.format(context),
              style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            enabled: _notifEnabled,
            onTap: () async {
              Navigator.pop(context);
              await _pickNotifTime();
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: U.red),
            title: Text(
              'Delete Timetable',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: U.text,
              ),
            ),
            subtitle: Text(
              'Remove your saved timetable',
              style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
            ),
            onTap: () async {
              Navigator.pop(context);
              await UserTimetableService.deleteTimetable();
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(String dayLabel) {
    if (_userTimetable == null) return const SizedBox.shrink();

    final dayData = _userTimetable!.week.firstWhere(
      (d) => d.day.toLowerCase().startsWith(dayLabel.toLowerCase()),
      orElse: () => const TimetableDay(day: '', slots: []),
    );

    if (dayData.slots.isEmpty || dayData.slots.every((s) => s.trim().isEmpty)) {
      return Center(
        child: Text(
          'No classes today!',
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: U.sub,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: dayData.slots.length,
      itemBuilder: (context, index) {
        final subject = dayData.slots[index].trim();
        if (subject.isEmpty)
          return const SizedBox.shrink(); // skip free periods

        TimetablePeriod? period;
        if (index < _userTimetable!.periods.length) {
          period = _userTimetable!.periods[index];
        }

        return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? U.card : U.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: U.border.withValues(alpha: 0.9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 70),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: U.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'P${period?.period ?? index + 1}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: U.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          period != null
                              ? '${period.start.split(' ').first}\n${period.end.split(' ').first}'
                              : '--',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: U.primary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      subject,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: U.text,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(delay: (index * 50).ms, duration: 400.ms)
            .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
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
        title: const Text('Timetable'),
        actions: [
          if (_userTimetable != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => _buildSettingsSheet(),
                );
              },
            ),
        ],
        bottom: _userTimetable == null
            ? null
            : PreferredSize(
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
                      tabs: _dayLabels
                          .map((label) => Tab(text: label))
                          .toList(),
                    ),
                  ),
                ),
              ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: U.primary))
          : _userTimetable == null
          ? _buildEmptyState()
          : TabBarView(
              controller: _tabController,
              children: _dayLabels.map(_buildDayView).toList(),
            ),
    );
  }
}
