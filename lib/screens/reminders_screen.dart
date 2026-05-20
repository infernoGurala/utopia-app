import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/focus_models.dart';
import '../services/focus_supabase_service.dart';
import '../widgets/utopia_snackbar.dart';
import '../services/notification_service.dart';
import '../widgets/utopia_loader.dart';
import '../theme/image_overlay_colors.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with WidgetsBindingObserver {
  final _service = FocusSupabaseService();
  List<FocusReminder> _reminders = [];
  bool _loading = true;
  DateTime _selectedDay = DateTime.now();
  DateTime _weekStart = _getWeekStart(DateTime.now());
  bool _filterActive = false;
  bool _showPast = false;

  bool _hasNotificationPermission = true;
  bool _hasAlarmPermission = true;
  bool _checkingPermissionState = true;

  bool _reminderAppliesToDay(FocusReminder r, DateTime day) {
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    if (r.type == 'one_time') {
      return r.remindDate == dateStr;
    } else if (r.type == 'weekly') {
      final index = day.weekday - 1;
      return r.weekdays != null && r.weekdays!.contains(index);
    } else if (r.type == 'monthly_date') {
      if (r.monthDay != day.day) return false;
      if (r.activeMonths == null || r.activeMonths!.isEmpty) return true;
      return r.activeMonths!.contains(day.month);
    }
    return false;
  }

  static DateTime _getWeekStart(DateTime d) {
    final diff = d.weekday - 1;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notifEnabled = await NotificationService.areNotificationPermissionsEnabled();
    final alarmEnabled = await NotificationService.canScheduleExactNotifications();
    if (mounted) {
      setState(() {
        _hasNotificationPermission = notifEnabled;
        _hasAlarmPermission = alarmEnabled;
        _checkingPermissionState = false;
      });
    }
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
      if (mounted) {
        showUtopiaSnackBar(context, message: 'Reminder deleted', tone: UtopiaSnackBarTone.info);
      }
      _load();
    }
  }

  void _showReminderSheet({FocusReminder? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => _ReminderForm(
        existing: existing,
        onSave: (r) async {
          Navigator.pop(ctx);
          await _service.saveReminder(r);
          if (mounted) {
            showUtopiaSnackBar(context, message: 'Reminder saved successfully!', tone: UtopiaSnackBarTone.success);
          }
          _load();
        },
        onDelete: existing != null ? () async {
          Navigator.pop(ctx);
          if (existing.id != null) {
            await _service.deleteReminder(existing.id!);
            if (mounted) {
              showUtopiaSnackBar(context, message: 'Reminder deleted', tone: UtopiaSnackBarTone.info);
            }
            _load();
          }
        } : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final topPadding = MediaQuery.paddingOf(context).top;

    final timeSlot = ImageOverlayColors.getTimeSlot();
    final bgImagePath = 'assets/welcome_bg/one_light/$timeSlot.png';
    final themeKey = appThemeNotifier.value.key;
    final isDarkTheme = appThemeNotifier.value.isDark;

    // In dark themes, the background image is dimmed down to 0.38 opacity, 
    // blending with the dark theme scaffold background. Therefore, the text 
    // and headers must always be high-contrast light text/icons.
    final Color onImageTitleColor = isDarkTheme 
        ? U.text 
        : ImageOverlayColors.titleColor(themeKey, timeSlot);
    final Color onImageSubtitleColor = isDarkTheme 
        ? U.sub 
        : ImageOverlayColors.subtitleColor(themeKey, timeSlot);

    final isDarkSky = timeSlot == 'evening' || timeSlot == 'night';
    final useLightStatusBarIcons = isDarkSky || isDarkTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useLightStatusBarIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness: useLightStatusBarIcons ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: U.bg,
        systemNavigationBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        body: Stack(
          children: [
            // ── Background Cover Image ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.55,
              child: Opacity(
                opacity: isDarkTheme ? 0.38 : 0.88,
                child: Image.asset(
                  bgImagePath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),

            // ── Gradient Overlay ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      U.bg.withValues(alpha: 0.0),
                      U.bg.withValues(alpha: 0.2),
                      U.bg,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // ── Main Content ──
            Positioned.fill(
              child: _checkingPermissionState
                  ? const Center(child: UtopiaLoader(scale: 0.7))
                  : (!_hasNotificationPermission || !_hasAlarmPermission)
                      ? _buildPermissionBlockedScreen(topPadding, onImageTitleColor, onImageSubtitleColor, isDarkTheme)
                      : _buildMainContent(topPadding, onImageTitleColor, onImageSubtitleColor, isDarkTheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(double topPadding, Color onImageTitleColor, Color onImageSubtitleColor, bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + 8),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: onImageTitleColor, size: 20),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: onImageTitleColor,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage scheduled alerts',
                      style: GoogleFonts.outfit(
                        color: onImageSubtitleColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await NotificationService.sendPersonalTestNotification(
                    message: 'Utopia reminders are working perfectly!',
                  );
                  if (mounted) {
                    showUtopiaSnackBar(
                      context,
                      message: 'Test notification triggered!',
                      tone: UtopiaSnackBarTone.info,
                    );
                  }
                },
                icon: Icon(Icons.notifications_active_outlined, color: onImageTitleColor, size: 22),
                tooltip: 'Test Instant Notification',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showReminderSheet(),
                icon: Icon(Icons.add_rounded, color: onImageTitleColor, size: 26),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0, duration: 500.ms),

        // Month Header + Week strip in a gorgeous glass container!
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Month Navigation Header
                    Builder(
                      builder: (context) {
                        final middleOfWeek = _weekStart.add(const Duration(days: 3));
                        const monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
                        final monthStr = '${monthNames[middleOfWeek.month]} ${middleOfWeek.year}';
                        return Row(
                          children: [
                            Text(
                              monthStr,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: U.text,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(Icons.chevron_left_rounded, color: U.sub, size: 20),
                              onPressed: () => _shiftWeek(-1),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDay = DateTime.now();
                                  _weekStart = _getWeekStart(DateTime.now());
                                  _filterActive = true;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: U.primary.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Today',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: U.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.chevron_right_rounded, color: U.sub, size: 20),
                              onPressed: () => _shiftWeek(1),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Colors.transparent),
                    // Week Strip
                    _buildWeekStrip(),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms, duration: 550.ms).slideY(begin: 0.08, end: 0, delay: 100.ms, duration: 550.ms),

        // List
        Expanded(
          child: _loading
              ? const Center(child: UtopiaLoader(scale: 0.7))
              : _reminders.isEmpty
                  ? Center(
                      child: Text(
                        'No reminders yet. Tap + to add one.',
                        style: GoogleFonts.outfit(color: U.dim, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    )
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildPermissionBlockedScreen(double topPadding, Color onImageTitleColor, Color onImageSubtitleColor, bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding + 8),
        // App header with Back button so they can leave the screen
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: onImageTitleColor, size: 20),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(
                'Reminders',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: onImageTitleColor,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: U.border.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notification_important_rounded,
                        color: U.primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enable Permissions',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: U.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Utopia requires notification and exact alarm permissions to trigger your focus reminders at the precise scheduled time.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: U.sub,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _buildPermissionStatusRow(
                      title: 'Notification Alert Permission',
                      description: 'Allows showing reminder alerts on your screen.',
                      isGranted: _hasNotificationPermission,
                      onRequest: () async {
                        await NotificationService.requestNotificationPermissionOnly();
                        await _checkPermissions();
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildPermissionStatusRow(
                      title: 'Exact Alarm Permission',
                      description: 'Allows firing notifications precisely on schedule.',
                      isGranted: _hasAlarmPermission,
                      onRequest: () async {
                        await NotificationService.openExactAlarmSettings();
                        await _checkPermissions();
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _checkPermissions,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: U.border),
                          foregroundColor: U.text,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 18, color: U.text),
                            const SizedBox(width: 8),
                            Text(
                              'I have granted permissions',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionStatusRow({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: U.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isGranted ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: isGranted ? U.green : U.gold,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: U.dim,
              height: 1.3,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                onPressed: onRequest,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: U.primary,
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Grant Permission',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: appThemeNotifier.value.isDark ? U.bg : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? U.primary.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNames[i], 
                        style: GoogleFonts.outfit(
                          fontSize: 10, 
                          fontWeight: FontWeight.w700, 
                          color: isSelected ? U.primary : U.dim, 
                          letterSpacing: 0.5
                        )
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${day.day}', 
                        style: GoogleFonts.outfit(
                          fontSize: 14, 
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500, 
                          color: isSelected ? U.primary : (isToday ? U.primary : U.sub)
                        )
                      ),
                      if (isToday && !isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: U.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
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
    if (_filterActive) {
      final filtered = _reminders.where((r) => _reminderAppliesToDay(r, _selectedDay)).toList();
      const monthNames = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final dateFormatted = '${_selectedDay.day} ${monthNames[_selectedDay.month]} ${_selectedDay.year}';

      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Text(
                  'Reminders for $dateFormatted',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: U.primary,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _filterActive = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Clear',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: U.primary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.close, size: 10, color: U.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No reminders scheduled for this day.',
                  style: GoogleFonts.outfit(color: U.dim, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ...filtered.map((r) => _reminderTile(r)),
        ],
      );
    }

    final upcoming = _upcoming;
    final recurring = _recurring;
    final past = _past;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
      physics: const BouncingScrollPhysics(),
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
              padding: const EdgeInsets.only(top: 20, bottom: 12),
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
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: U.dim, letterSpacing: 1.5)),
    );
  }

  Widget _reminderTile(FocusReminder r) {
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(r.id),
        direction: DismissDirection.endToStart,
        background: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: U.red.withValues(alpha: 0.15),
            child: Icon(Icons.delete_outline_rounded, color: U.red),
          ),
        ),
        confirmDismiss: (_) async {
          await _deleteReminder(r);
          return false; // handled by reload
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: U.border.withValues(alpha: isDarkTheme ? 0.3 : 0.7),
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showReminderSheet(existing: r),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        // Left dynamic badge based on type
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDarkTheme
                                ? Color.lerp(U.primary, Colors.black, 0.72)!.withValues(alpha: 0.85)
                                : Color.lerp(U.primary, Colors.white, 0.84)!,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            r.type == 'one_time'
                                ? Icons.event_rounded
                                : (r.type == 'weekly' ? Icons.loop_rounded : Icons.calendar_month_rounded),
                            color: U.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.label,
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                r.scheduleSummary,
                                style: GoogleFonts.outfit(
                                  color: U.sub.withValues(alpha: 0.8),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: U.sub.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
  late final TextEditingController _monthDayController;
  String _type = 'one_time';
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  Set<int> _weekdays = {};
  int _monthDay = 1;
  Set<int> _activeMonths = {};
  bool _allMonths = true;
  String? _errorText;

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
    _monthDayController = TextEditingController(text: '$_monthDay');
  }

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _timeStr => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _save() {
    if (_labelController.text.trim().isEmpty) {
      setState(() {
        _errorText = 'Please enter what you want to be reminded about';
      });
      return;
    }
    if (_type == 'weekly' && _weekdays.isEmpty) {
      setState(() {
        _errorText = 'Please select at least one day of the week';
      });
      return;
    }
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
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: U.bg.withValues(alpha: isDarkTheme ? 0.72 : 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: U.border.withValues(alpha: isDarkTheme ? 0.25 : 0.65),
                width: 1.0,
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: U.text.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: U.surface.withValues(alpha: isDarkTheme ? 0.4 : 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _errorText != null
                            ? U.red
                            : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _labelController,
                      onChanged: (v) {
                        setState(() {
                          if (_errorText != null) {
                            _errorText = null;
                          }
                        });
                      },
                      style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        hintText: 'What should we remind you about?',
                        hintStyle: GoogleFonts.outfit(color: U.sub.withValues(alpha: 0.55), fontSize: 14.5),
                        suffixIcon: _labelController.text.trim().isNotEmpty
                            ? Icon(Icons.check_circle_outline_rounded, color: U.green, size: 20)
                            : null,
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _errorText!,
                        style: GoogleFonts.outfit(color: U.red, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Label "REPEAT TYPE"
                  Text(
                    'REPEAT TYPE',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: U.sub.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
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
                  const SizedBox(height: 24),
                  
                  // Config details
                  if (_type == 'one_time') ...[
                    Text(
                      'DATE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: U.sub.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDatePicker(),
                    const SizedBox(height: 20),
                  ],
                  if (_type == 'weekly') ...[
                    Text(
                      'REPEAT WEEKDAYS',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: U.sub.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildWeekdaySelector(),
                    const SizedBox(height: 20),
                  ],
                  if (_type == 'monthly_date') ...[
                    Text(
                      'MONTHLY RECURRENCE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: U.sub.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMonthlyConfig(),
                    const SizedBox(height: 20),
                  ],
                  
                  Text(
                    'TIME',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: U.sub.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTimePicker(),
                  const SizedBox(height: 28),
                  
                  // Summary in card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: U.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: U.primary.withValues(alpha: 0.12), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: U.primary, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _buildSummary(),
                            style: GoogleFonts.outfit(
                              color: U.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: U.primary,
                        foregroundColor: appThemeNotifier.value.isDark ? U.bg : Colors.white,
                        shadowColor: U.primary.withValues(alpha: 0.25),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save Reminder',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onDelete != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: widget.onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: U.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Delete Reminder',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typePill(String label, String value) {
    final selected = _type == value;
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? U.primary.withValues(alpha: 0.16)
                : U.surface.withValues(alpha: isDarkTheme ? 0.35 : 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? U.primary
                  : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: selected ? U.primary : U.sub,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final isDarkTheme = appThemeNotifier.value.isDark;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: U.primary,
                  primary: U.primary,
                  onPrimary: isDarkTheme ? U.bg : Colors.white,
                  surface: U.surface,
                  onSurface: U.text,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _date = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: U.primary),
            const SizedBox(width: 12),
            Text(
              '${_date.day} ${months[_date.month]} ${_date.year}',
              style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    final hour = _time.hourOfPeriod == 0 ? 12 : _time.hourOfPeriod;
    final ampm = _time.period == DayPeriod.am ? 'AM' : 'PM';
    final isDarkTheme = appThemeNotifier.value.isDark;
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: U.primary,
                  primary: U.primary,
                  onPrimary: isDarkTheme ? U.bg : Colors.white,
                  surface: U.surface,
                  onSurface: U.text,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _time = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 18, color: U.primary),
            const SizedBox(width: 12),
            Text(
              '$hour:${_time.minute.toString().padLeft(2, '0')} $ampm',
              style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdaySelector() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(7, (i) {
        final selected = _weekdays.contains(i);
        return GestureDetector(
          onTap: () => setState(() { selected ? _weekdays.remove(i) : _weekdays.add(i); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? U.primary.withValues(alpha: 0.16)
                  : U.surface.withValues(alpha: isDarkTheme ? 0.35 : 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? U.primary
                    : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
              ),
            ),
            child: Text(
              days[i],
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? U.primary : U.sub,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthlyConfig() {
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Day of month:', style: GoogleFonts.outfit(color: U.sub, fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            Container(
              width: 68,
              decoration: BoxDecoration(
                color: U.surface.withValues(alpha: isDarkTheme ? 0.45 : 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: TextField(
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(color: U.text, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '1', 
                  hintStyle: GoogleFonts.outfit(color: U.dim),
                  border: InputBorder.none,
                ),
                controller: _monthDayController,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null && n >= 1 && n <= 31) {
                    setState(() {
                      _monthDay = n;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Text('(1–31)', style: GoogleFonts.outfit(color: U.dim, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _allMonths = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _allMonths ? U.primary.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _allMonths ? U.primary : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
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
                  color: !_allMonths ? U.primary.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: !_allMonths ? U.primary : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65)),
                ),
                child: Text('Specific', style: GoogleFonts.outfit(color: !_allMonths ? U.primary : U.sub, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        if (!_allMonths) ...[
          const SizedBox(height: 16),
          _buildMonthSelector(),
        ],
      ],
    );
  }

  Widget _buildMonthSelector() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final isDarkTheme = appThemeNotifier.value.isDark;
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: List.generate(12, (i) {
        final m = i + 1;
        final selected = _activeMonths.contains(m);
        return GestureDetector(
          onTap: () => setState(() { selected ? _activeMonths.remove(m) : _activeMonths.add(m); }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? U.primary.withValues(alpha: 0.16)
                  : U.surface.withValues(alpha: isDarkTheme ? 0.35 : 0.55),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? U.primary
                    : U.border.withValues(alpha: isDarkTheme ? 0.35 : 0.65),
              ),
            ),
            child: Text(
              months[i],
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? U.primary : U.sub,
              ),
            ),
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
    _monthDayController.dispose();
    super.dispose();
  }
}
