import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/attendance_cache_service.dart';
import '../services/attendance_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/utopia_snackbar.dart';
import '../widgets/utopia_loader.dart';
import '../services/attendance_server_preference.dart';
import '../models/user_timetable.dart';
import '../services/user_timetable_service.dart';

enum _AttendanceViewState { initial, loading, loaded, error }

typedef _AttendanceRangeMode = AttendanceRangeMode;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedCollege = 'aus';
  String _selectedServer = AttendanceServerPreference.kServer1;

  late final AnimationController _glowController;
  _AttendanceViewState _state = _AttendanceViewState.loading;
  bool _obscurePassword = true;
  String? _errorMessage;
  Map<String, dynamic>? _attendanceData;
  Map<String, String>? _savedCredentials;
  UserTimetable? _userTimetable;
  bool _isFromCache = false;
  String? _cacheAgeLabel;
  int _currentTabIndex = 0;
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    unawaited(_loadSavedCredentials());
    unawaited(_loadServerPreference());
  }

  Future<void> _loadServerPreference() async {
    final server = await AttendanceServerPreference.getServer();
    if (mounted) {
      setState(() {
        _selectedServer = server;
      });
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rollController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final credentials = await SecureStorageService.getCredentials();
      if (!mounted) {
        return;
      }
      if (credentials == null) {
        setState(() => _state = _AttendanceViewState.initial);
        return;
      }

      _savedCredentials = credentials;
      _rollController.text = credentials['rollNumber'] ?? '';
      _passwordController.text = credentials['password'] ?? '';
      final timetable = await UserTimetableService.getTimetable();
      setState(() {
        _selectedCollege = credentials['college'] ?? 'aus';
        _userTimetable = timetable;
      });
      await _fetchAttendance(
        rollNumber: _rollController.text,
        password: _passwordController.text,
        college: _selectedCollege,
        saveCredentials: false,
        keepFormOnFailure: false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Could not load saved attendance credentials';
        _state = _AttendanceViewState.error;
      });
    }
  }

  Future<void> _fetchAttendance({
    required String rollNumber,
    required String password,
    required String college,
    required bool saveCredentials,
    required bool keepFormOnFailure,
    _AttendanceRangeMode mode = _AttendanceRangeMode.tillNow,
  }) async {
    final trimmedRoll = rollNumber.trim();
    if (trimmedRoll.isEmpty || password.isEmpty) {
      showUtopiaSnackBar(
        context,
        message: 'Enter your roll number and portal password',
        tone: UtopiaSnackBarTone.error,
      );
      return;
    }

    setState(() {
      _errorMessage = null;
      _state = _AttendanceViewState.loading;
    });

    try {
      final serviceMode = college == 'acet'
          ? (mode == _AttendanceRangeMode.tillNow
                ? AttendanceRangeMode.tillNow
                : AttendanceRangeMode.period)
          : AttendanceRangeMode.period;

      final result = await AttendanceService.fetchAttendance(
        trimmedRoll,
        password,
        college: college,
        mode: serviceMode,
      );
      if (saveCredentials) {
        await SecureStorageService.saveCredentials(
          trimmedRoll,
          password,
          college,
        );
      }
      _savedCredentials = {
        'rollNumber': trimmedRoll,
        'password': password,
        'college': college,
      };
      if (!mounted) {
        return;
      }
      setState(() {
        _attendanceData = result;
        _isFromCache = result['fromCache'] as bool? ?? false;
        _cacheAgeLabel = result['cacheAgeLabel'] as String?;
        _state = _AttendanceViewState.loaded;
      });
    } catch (e) {
      final message = _friendlyErrorMessage(e);
      if (!mounted) {
        return;
      }

      if (keepFormOnFailure) {
        setState(() => _state = _AttendanceViewState.initial);
        showUtopiaSnackBar(
          context,
          message: message,
          tone: UtopiaSnackBarTone.error,
        );
        return;
      }

      setState(() {
        _errorMessage = message;
        _state = _AttendanceViewState.error;
      });
    }
  }

  Future<void> _refresh() async {
    final credentials = _savedCredentials;
    if (credentials == null) {
      return;
    }
    final timetable = await UserTimetableService.getTimetable();
    if (mounted) {
      setState(() {
        _userTimetable = timetable;
      });
    }
    await _fetchAttendance(
      rollNumber: credentials['rollNumber'] ?? '',
      password: credentials['password'] ?? '',
      college: credentials['college'] ?? 'aus',
      saveCredentials: false,
      keepFormOnFailure: false,
      mode: _AttendanceRangeMode.tillNow, // full semester, same as initial load
    );
  }

  Future<void> _disconnect() async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          'Disconnect portal',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove your attendance credentials from this device?',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: U.red.withValues(alpha: 0.16),
              foregroundColor: U.red,
            ),
            child: Text(
              'Disconnect',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (shouldDisconnect != true) {
      return;
    }

    await SecureStorageService.clearCredentials();
    final roll = _savedCredentials?['rollNumber'] ?? '';
    if (roll.isNotEmpty) {
      unawaited(AttendanceCacheService.clear(roll));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _savedCredentials = null;
      _attendanceData = null;
      _errorMessage = null;
      _isFromCache = false;
      _cacheAgeLabel = null;
      _rollController.clear();
      _passwordController.clear();
      _selectedCollege = 'aus';
      _state = _AttendanceViewState.initial;
    });
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Something went wrong while fetching attendance';
    }
    return message;
  }

  Color _percentageColor(double value) {
    if (value >= 75) {
      return U.green;
    }
    if (value >= 65) {
      return U.peach;
    }
    return U.red;
  }

  IconData _subjectIcon(String subject) {
    final key = subject.toLowerCase();
    if (key.contains('devc') || key.contains('ppsuc')) {
      return Icons.code_rounded;
    }
    if (key.contains('beee') || key.contains('e.')) {
      return Icons.electrical_services_rounded;
    }
    if (key.contains('iot')) return Icons.memory_rounded;
    if (key.contains('dtai')) return Icons.auto_awesome_rounded;
    if (key.contains('env')) return Icons.eco_rounded;
    if (key.contains('emp')) return Icons.psychology_alt_rounded;
    return Icons.book_rounded;
  }

  String _headlineFor(double overall) {
    if (overall >= 85) {
      return 'Locked in';
    }
    if (overall >= 75) {
      return 'On track';
    }
    if (overall >= 65) {
      return 'Recoverable';
    }
    return 'Needs attention';
  }

  static const double _attendanceTarget = 0.75;

  int _missableClasses(int attended, int held) {
    if (held <= 0 || attended <= 0) {
      return 0;
    }
    return ((attended / _attendanceTarget) - held).floor().clamp(0, 9999);
  }

  int _classesNeededToRecover(int attended, int held) {
    if (held <= 0) {
      return 0;
    }
    final needed =
        ((_attendanceTarget * held) - attended) / (1 - _attendanceTarget);
    return needed.ceil().clamp(0, 9999);
  }

  String _heroStatusText(int belowTargetCount) {
    if (belowTargetCount > 0) {
      return '$belowTargetCount subject${belowTargetCount == 1 ? '' : 's'} need attention';
    }
    return 'All subjects are on track';
  }

  String _formatPortalDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _showTodaySheet() async {
    debugPrint('[DEBUG][Attendance] _showTodaySheet called');
    final credentials = _savedCredentials;
    debugPrint(
      '[DEBUG][Attendance] credentials: ${credentials != null ? "found" : "null"}',
    );
    if (credentials == null) {
      return;
    }
    final now = DateTime.now();
    final todayLabel = _formatPortalDate(now);
    final portalDate = _formatPortalDateForPortal(now);
    debugPrint(
      '[DEBUG][Attendance] Today: label=$todayLabel, portalDate=$portalDate',
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AttendanceDateSheet(
        title: 'Today',
        dateLabel: todayLabel,
        date: now,
        credentials: credentials,
        onRefresh: _refresh,
        portalDateLabel: portalDate,
        mode: _AttendanceRangeMode.period,
      ),
    );
    debugPrint('[DEBUG][Attendance] _showTodaySheet completed');
  }



  String _formatPortalDateForPortal(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day-$month-${dt.year}';
  }

  String _formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoadedActions = _state == _AttendanceViewState.loaded;
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: GoogleFonts.outfit(
                color: U.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _currentTabIndex == 1
                  ? 'Calendar'
                  : _currentTabIndex == 2
                      ? 'Insights'
                      : 'Overview',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (showLoadedActions)
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: Icon(Icons.refresh_rounded, color: U.text),
            ),
          if (showLoadedActions)
            IconButton(
              onPressed: _disconnect,
              tooltip: 'Disconnect',
              icon: Icon(Icons.logout_rounded, color: U.text),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: switch (_state) {
            _AttendanceViewState.initial => _buildInitialState(),
            _AttendanceViewState.loading => _buildLoadingState(),
            _AttendanceViewState.loaded => _buildLoadedState(),
            _AttendanceViewState.error => _buildErrorState(),
          },
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      key: const ValueKey('attendance_initial'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.fact_check_rounded,
                        color: U.primary,
                        size: 28,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 12),
                Text(
                      'Connect Attendance',
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 500.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      delay: 100.ms,
                      duration: 500.ms,
                    ),
                const SizedBox(height: 6),
                Text(
                  'Your data stays on this device only',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: U.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: U.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCollege = 'aus'),
                            child: Container(
                              height: 44,
                              color: _selectedCollege == 'aus'
                                  ? U.primary
                                  : U.surface,
                              child: Center(
                                child: Text(
                                  'AUS',
                                  style: GoogleFonts.outfit(
                                    color: _selectedCollege == 'aus'
                                        ? U.bg
                                        : U.sub,
                                    fontSize: 14,
                                    fontWeight: _selectedCollege == 'aus'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCollege = 'acet'),
                            child: Container(
                              height: 44,
                              color: _selectedCollege == 'acet'
                                  ? U.primary
                                  : U.surface,
                              child: Center(
                                child: Text(
                                  'ACET',
                                  style: GoogleFonts.outfit(
                                    color: _selectedCollege == 'acet'
                                        ? U.bg
                                        : U.sub,
                                    fontSize: 14,
                                    fontWeight: _selectedCollege == 'acet'
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Server',
                        style: GoogleFonts.outfit(
                          color: U.sub,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    await AttendanceServerPreference.setServer(
                                      AttendanceServerPreference.kServer1,
                                    );
                                    setState(
                                      () => _selectedServer =
                                          AttendanceServerPreference.kServer1,
                                    );
                                  },
                                  child: Container(
                                    height: 32,
                                    color:
                                        _selectedServer ==
                                            AttendanceServerPreference.kServer1
                                        ? U.primary
                                        : U.surface,
                                    child: Center(
                                      child: Text(
                                        'In-App',
                                        style: GoogleFonts.outfit(
                                          color:
                                              _selectedServer ==
                                                  AttendanceServerPreference
                                                      .kServer1
                                              ? U.bg
                                              : U.sub,
                                          fontSize: 12,
                                          fontWeight:
                                              _selectedServer ==
                                                  AttendanceServerPreference
                                                      .kServer1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    await AttendanceServerPreference.setServer(
                                      AttendanceServerPreference.kServer2,
                                    );
                                    setState(
                                      () => _selectedServer =
                                          AttendanceServerPreference.kServer2,
                                    );
                                  },
                                  child: Container(
                                    height: 32,
                                    color:
                                        _selectedServer ==
                                            AttendanceServerPreference.kServer2
                                        ? U.primary
                                        : U.surface,
                                    child: Center(
                                      child: Text(
                                        'Cloud',
                                        style: GoogleFonts.outfit(
                                          color:
                                              _selectedServer ==
                                                  AttendanceServerPreference
                                                      .kServer2
                                              ? U.bg
                                              : U.sub,
                                          fontSize: 12,
                                          fontWeight:
                                              _selectedServer ==
                                                  AttendanceServerPreference
                                                      .kServer2
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _rollController,
                    hintText: _selectedCollege == 'aus'
                        ? 'e.g. 25B11ME038'
                        : 'e.g. 24P31A42F2',
                    labelText: 'Roll Number',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _passwordController,
                    hintText: 'Your portal password',
                    labelText: 'Password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      color: U.sub,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _state == _AttendanceViewState.loading
                          ? null
                          : () => _fetchAttendance(
                              rollNumber: _rollController.text,
                              password: _passwordController.text,
                              college: _selectedCollege,
                              saveCredentials: true,
                              keepFormOnFailure: true,
                            ),
                      icon: const Icon(Icons.sync_lock_rounded, size: 18),
                      label: Text(
                        'Connect',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: U.primary,
                        foregroundColor: U.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      key: const ValueKey('attendance_loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UtopiaLoader(scale: 0.8),
          const SizedBox(height: 24),
          Text(
            'Fetching live attendance...',
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Syncing your report',
            style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: () {
          switch (_currentTabIndex) {
            case 1:
              return _buildCalendarTab();
            case 2:
              return _buildInsightsTab();
            case 0:
            default:
              return _buildOverviewTab();
          }
        }(),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      height: 74,
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.donut_large_rounded, 'Overview'),
          _buildNavItem(1, Icons.calendar_month_rounded, 'Calendar'),
          _buildNavItem(2, Icons.bar_chart_rounded, 'Insights'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    final color = isSelected ? U.green : U.sub;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 12 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: U.green,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final data = _attendanceData ?? const <String, dynamic>{};
    final subjects = (data['subjects'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final studentName = (data['studentName'] as String? ?? '').trim();
    final overall = (data['overallPercentage'] as num?)?.toDouble() ?? 0;
    final overallColor = _percentageColor(overall);
    final belowTarget = subjects.where((subject) {
      final percentage = (subject['percentage'] as num?)?.toDouble() ?? 0;
      return percentage < 75;
    }).length;

    return Stack(
      children: [
        RefreshIndicator(
          color: U.primary,
          backgroundColor: U.card,
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const ValueKey('attendance_loaded'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_isFromCache)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: U.peach.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: U.peach.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: U.peach, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Portal unreachable — showing cached data'
                            '${_cacheAgeLabel != null ? ' from $_cacheAgeLabel' : ''}. Pull to retry.',
                            style: GoogleFonts.outfit(
                              color: U.peach,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GradientHero(
                        icon: Icons.timeline_rounded,
                        eyebrow: _headlineFor(overall),
                        title: '${overall.toStringAsFixed(1)}%',
                        subtitle: _heroStatusText(belowTarget),
                        detail: studentName.isEmpty ? null : studentName,
                        accent: overallColor,
                        subtitleColor: belowTarget > 0 ? U.red : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subjects',
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subject-wise attendance snapshot',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == subjects.length - 1 ? 0 : 12,
                      ),
                      child: _buildSubjectCard(subjects[index]),
                    ),
                    childCount: subjects.length,
                  ),
                ),
              ),
              // Footnote for server type at the end of the scrollview instead of floating overlay
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: U.sub),
                        const SizedBox(width: 6),
                        Text(
                          'Fetched via ${data['serverUsed'] == 'server2'
                              ? 'Cloud'
                              : data['serverUsed'] == 'server1'
                              ? 'In-App'
                              : 'Cache'}',
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Today floating button positioned snuggly above the bottom navigation bar
        Positioned(
          right: 24,
          bottom: 20,
          child: _TodayPulseButton(
            animation: _glowController,
            onTap: _showTodaySheet,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    final credentials = _savedCredentials;
    if (credentials == null) {
      return Center(
        child: Text(
          'No credentials active',
          style: GoogleFonts.outfit(color: U.sub),
        ),
      );
    }

    final portalDate = _formatPortalDateForPortal(_selectedCalendarDate);
    final serviceMode = credentials['college'] == 'acet'
        ? AttendanceRangeMode.period
        : AttendanceRangeMode.period;

    final Future<Map<String, dynamic>> calendarFuture = AttendanceService.fetchAttendance(
      credentials['rollNumber'] ?? '',
      credentials['password'] ?? '',
      college: credentials['college'] ?? 'aus',
      fromDate: portalDate,
      toDate: portalDate,
      mode: serviceMode,
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: U.border),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: U.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayDate(_selectedCalendarDate),
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily class-by-class records',
                      style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final now = DateTime.now();
                   final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedCalendarDate,
                    firstDate: DateTime(2020),
                    lastDate: now,
                    builder: (context, child) {
                      final theme = Theme.of(context);
                      return Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: U.green,
                          ),
                          datePickerTheme: theme.datePickerTheme.copyWith(
                            todayForegroundColor: WidgetStateProperty.all(U.green),
                            todayBorder: BorderSide(color: U.green, width: 1.5),
                            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return U.green;
                              }
                              return null;
                            }),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _selectedCalendarDate = picked);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: U.green.withValues(alpha: 0.1),
                  foregroundColor: U.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: Text(
                  'Change Date',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: calendarFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: UtopiaLoader(scale: 0.7));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded, color: U.red, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load records',
                          style: GoogleFonts.outfit(color: U.text, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _friendlyErrorMessage(snapshot.error ?? ''),
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final dateData = snapshot.data ?? const <String, dynamic>{};
              final periods = (dateData['periods'] as List<dynamic>? ?? const [])
                  .cast<Map<String, dynamic>>();

              if (periods.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: U.green.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event_busy_rounded, color: U.green, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Classes Scheduled',
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No class records exist for this day',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: periods.length,
                itemBuilder: (context, index) {
                  final period = periods[index];
                  final name = period['subject'] ?? 'Unknown Subject';
                  final status = period['status'] ?? 'Absent';
                  final duration = period['duration'] ?? '';
                  final isPresent = status.toString().trim().toLowerCase() == 'present';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: U.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: U.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: U.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: U.border),
                          ),
                          child: Text(
                            'Period ${index + 1}',
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (duration.toString().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  duration,
                                  style: GoogleFonts.outfit(color: U.sub, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPresent ? U.green.withValues(alpha: 0.12) : U.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPresent ? U.green.withValues(alpha: 0.3) : U.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.outfit(
                              color: isPresent ? U.green : U.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _weekdayKey(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
      default:
        return 'Sun';
    }
  }

  bool _isSubjectMatch(String portalSubject, String timetableSlot) {
    final p = portalSubject.trim().toLowerCase();
    final t = timetableSlot.trim().toLowerCase();
    if (p.isEmpty || t.isEmpty) return false;

    // 1. Direct match
    if (p == t) return true;

    // 2. Timetable slot is an acronym of the portal subject
    // e.g. "Discrete Mathematics" -> DM, "Digital Electronics" -> DE
    final words = p.split(RegExp(r'[\s\-]+'));
    if (words.length > 1) {
      final acronym = words.map((w) => w.isNotEmpty ? w[0] : '').join();
      if (acronym == t) return true;
    }

    // 3. Portal subject is an acronym of the timetable slot
    final tWords = t.split(RegExp(r'[\s\-]+'));
    if (tWords.length > 1) {
      final tAcronym = tWords.map((w) => w.isNotEmpty ? w[0] : '').join();
      if (tAcronym == p) return true;
    }

    // 4. Substring matching
    if (p.contains(t) || t.contains(p)) return true;

    return false;
  }

  Widget _buildTomorrowPredictor() {
    final credentials = _savedCredentials;
    if (credentials == null) return const SizedBox.shrink();

    if (_userTimetable == null) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: U.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: U.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_month_rounded, color: U.primary, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              "Tomorrow's Predictor Not Synced",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Set up your timetable in the Timetable tab to see if you can safely miss tomorrow's classes!",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowDayKey = _weekdayKey(tomorrow);

    final timetableDay = _userTimetable!.week.firstWhere(
      (d) => d.day.toLowerCase().startsWith(tomorrowDayKey.toLowerCase()),
      orElse: () => const TimetableDay(day: '', slots: []),
    );

    final tomorrowSlots = timetableDay.slots
        .where((slot) => slot.trim().isNotEmpty && slot.trim().toLowerCase() != 'free')
        .toList();

    if (tomorrowSlots.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: U.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: U.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wb_sunny_outlined, color: U.green, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              "Tomorrow: No Classes!",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Tomorrow is a free day or weekend. Sleep in and relax!",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // Parse overall subjects and build predictions
    final data = _attendanceData ?? const <String, dynamic>{};
    final subjects = (data['subjects'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    final List<Map<String, dynamic>> subjectPredictions = [];
    int totalTomorrowCount = 0;
    int totalCanMissCount = 0;
    bool hasDanger = false;

    for (final subject in subjects) {
      final name = (subject['subject'] ?? 'Subject').toString();
      final totalClasses = (subject['totalClasses'] as num?)?.toInt() ?? 0;
      final attendedClasses = (subject['attendedClasses'] as num?)?.toInt() ?? 0;
      final percentage = (subject['percentage'] as num?)?.toDouble() ?? 0;

      final tomorrowCount = tomorrowSlots.where((slot) => _isSubjectMatch(name, slot)).length;
      if (tomorrowCount == 0) continue;

      totalTomorrowCount += tomorrowCount;

      // Predictions
      final newTotal = totalClasses + tomorrowCount;
      final newAttendedIfAttendAll = attendedClasses + tomorrowCount;
      final percentageIfAttendAll = newTotal == 0 ? 0.0 : (newAttendedIfAttendAll / newTotal) * 100;
      final percentageIfMissAll = newTotal == 0 ? 0.0 : (attendedClasses / newTotal) * 100;

      int maxMissableTomorrow = 0;
      for (int m = tomorrowCount; m >= 0; m--) {
        final newAttended = attendedClasses + tomorrowCount - m;
        final pct = (newAttended / newTotal) * 100;
        if (pct >= 75.0) {
          maxMissableTomorrow = m;
          break;
        }
      }

      final isDangerTomorrow = percentageIfAttendAll < 75.0;
      if (isDangerTomorrow) {
        hasDanger = true;
      }

      totalCanMissCount += maxMissableTomorrow;

      subjectPredictions.add({
        'name': name,
        'tomorrowCount': tomorrowCount,
        'maxMissableTomorrow': maxMissableTomorrow,
        'isDangerTomorrow': isDangerTomorrow,
        'percentageIfAttendAll': percentageIfAttendAll,
        'percentageIfMissAll': percentageIfMissAll,
        'currentPercentage': percentage,
      });
    }

    // If no tomorrow subject matches, then we have classes but they aren't matched with subjects
    if (subjectPredictions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Overall verdict
    final String verdictTitle;
    final String verdictDesc;
    final Color verdictColor;
    final IconData verdictIcon;

    if (hasDanger) {
      verdictTitle = "Danger Zone!";
      verdictDesc = "You are below 75% in some of tomorrow's subjects. Even if you attend all tomorrow, you'll still be below 75%. Critical action required!";
      verdictColor = U.red;
      verdictIcon = Icons.report_problem_rounded;
    } else if (totalCanMissCount == totalTomorrowCount) {
      verdictTitle = "Safe to Skip Entire Day!";
      verdictDesc = "🎉 Incredible! You can safely miss all $totalTomorrowCount classes tomorrow without dropping below 75% in any subject!";
      verdictColor = U.green;
      verdictIcon = Icons.check_circle_rounded;
    } else if (totalCanMissCount > 0) {
      verdictTitle = "Safe to Miss Some Classes";
      verdictDesc = "You can safely miss up to $totalCanMissCount out of $totalTomorrowCount classes tomorrow. Check subject-wise details below.";
      verdictColor = U.peach;
      verdictIcon = Icons.info_outline_rounded;
    } else {
      verdictTitle = "Attendance Required Tomorrow";
      verdictDesc = "⚠️ You must attend all $totalTomorrowCount classes tomorrow to keep your attendance above 75% in all subjects.";
      verdictColor = U.primary;
      verdictIcon = Icons.event_busy_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of tomorrow section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Icon(Icons.psychology_outlined, color: U.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Tomorrow's Attendance Analyzer",
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Verdict banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: verdictColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: verdictColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(verdictIcon, color: verdictColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdictTitle,
                        style: GoogleFonts.outfit(
                          color: verdictColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        verdictDesc,
                        style: GoogleFonts.outfit(
                          color: verdictColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Subject breakdown header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "SUBJECT-WISE FORECAST",
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // List of subject details
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: subjectPredictions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pred = subjectPredictions[index];
              final name = pred['name'] as String;
              final tCount = pred['tomorrowCount'] as int;
              final maxMissable = pred['maxMissableTomorrow'] as int;
              final isDanger = pred['isDangerTomorrow'] as bool;
              final pctAll = pred['percentageIfAttendAll'] as double;
              final pctMiss = pred['percentageIfMissAll'] as double;
              final currentPct = pred['currentPercentage'] as double;

              final Color badgeColor;
              final String badgeText;

              if (isDanger) {
                badgeColor = U.red;
                badgeText = "Critical Zone";
              } else if (maxMissable == tCount) {
                badgeColor = U.green;
                badgeText = "Safe to miss all $tCount";
              } else if (maxMissable > 0) {
                badgeColor = U.peach;
                badgeText = "Can miss $maxMissable of $tCount";
              } else {
                badgeColor = U.primary;
                badgeText = "Must attend all $tCount";
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: U.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: U.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.outfit(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Current: ${currentPct.toStringAsFixed(1)}%",
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 11),
                        ),
                        Text(
                          isDanger
                              ? "Attend all: ${pctAll.toStringAsFixed(1)}% (Danger)"
                              : maxMissable == tCount
                              ? "Miss all: ${pctMiss.toStringAsFixed(1)}% (Safe)"
                              : "Attend: ${pctAll.toStringAsFixed(1)}% | Miss: ${pctMiss.toStringAsFixed(1)}%",
                          style: GoogleFonts.outfit(
                            color: isDanger
                                ? U.red
                                : maxMissable == tCount
                                ? U.green
                                : U.sub,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildInsightsTab() {
    final data = _attendanceData ?? const <String, dynamic>{};
    final overall = (data['overallPercentage'] as num?)?.toDouble() ?? 0;
    final totalClasses = (data['totalClasses'] as num?)?.toInt() ?? 0;
    final totalAttended = (data['totalAttended'] as num?)?.toInt() ?? 0;
    final studentName = (data['studentName'] as String? ?? '').trim();
    final color = _percentageColor(overall);
    final statusLabel = _headlineFor(overall);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [U.card, color.withValues(alpha: 0.14)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: U.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: color,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Overall Attendance',
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${overall.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: U.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  value: (overall / 100).clamp(0.0, 1.0),
                ),
              ),
              if (studentName.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: U.sub,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        studentName,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildInsightStatCard(
                  label: 'Classes Held',
                  value: totalClasses.toString(),
                  icon: Icons.event_note_rounded,
                  color: U.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightStatCard(
                  label: 'Classes Attended',
                  value: totalAttended.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInsightStatCard(
          label: 'Classes Missed',
          value: (totalClasses - totalAttended).clamp(0, 9999).toString(),
          icon: Icons.cancel_outlined,
          color: U.red,
          wide: true,
        ),
        _buildTomorrowPredictor(),
        const SizedBox(height: 24),
        _buildInsightTipBanner(overall: overall, attended: totalAttended, held: totalClasses),
      ],
    );
  }

  Widget _buildInsightStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool wide = false,
  }) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: U.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTipBanner({
    required double overall,
    required int attended,
    required int held,
  }) {
    const double target = 0.75;
    final int missable = (held <= 0 || attended <= 0)
        ? 0
        : ((attended / target) - held).floor().clamp(0, 9999);
    final int needed = held <= 0
        ? 0
        : (((target * held) - attended) / (1 - target)).ceil().clamp(0, 9999);

    final String message;
    final Color tint;
    final IconData icon;

    if (overall >= 75) {
      message = missable == 0
          ? 'You are exactly at the 75% threshold. Attend all upcoming classes to stay safe.'
          : 'You can miss up to $missable more class${missable == 1 ? '' : 'es'} and still stay above 75%.';
      tint = U.green;
      icon = Icons.verified_outlined;
    } else {
      message = needed == 0
          ? 'Your attendance needs attention. Attend classes regularly to improve.'
          : 'Attend $needed consecutive class${needed == 1 ? '' : 'es'} to reach the 75% target.';
      tint = overall >= 65 ? U.peach : U.red;
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: tint,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final name = (subject['subject'] ?? 'Subject').toString();
    final totalClasses = (subject['totalClasses'] as num?)?.toInt() ?? 0;
    final attendedClasses = (subject['attendedClasses'] as num?)?.toInt() ?? 0;
    final percentage = (subject['percentage'] as num?)?.toDouble() ?? 0;
    final color = _percentageColor(percentage);
    final classesNeeded = _classesNeededToRecover(
      attendedClasses,
      totalClasses,
    );
    final missableClasses = _missableClasses(attendedClasses, totalClasses);
    final bufferLine = percentage >= 75
        ? missableClasses == 0
              ? 'At the 75% line'
              : 'Can miss $missableClasses more class${missableClasses == 1 ? '' : 'es'}'
        : classesNeeded == 0
        ? 'Needs attention'
        : 'Attend $classesNeeded more class${classesNeeded == 1 ? '' : 'es'} to reach 75%';

    return Card(
      margin: EdgeInsets.zero,
      color: U.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: U.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_subjectIcon(name), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$attendedClasses / $totalClasses classes',
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: U.surface,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                value: totalClasses == 0
                    ? 0
                    : (percentage / 100).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bufferLine,
              style: GoogleFonts.outfit(
                color: percentage >= 75 ? U.sub : color,
                fontSize: 12,
                fontWeight: percentage >= 75
                    ? FontWeight.w500
                    : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('attendance_error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: U.card,
                shape: BoxShape.circle,
                border: Border.all(color: U.border),
              ),
              child: Icon(
                Icons.wifi_tethering_error_rounded,
                color: U.red,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _errorMessage ?? 'Something went wrong while loading attendance',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Try reconnecting or refresh in a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _savedCredentials == null
                  ? () => setState(() => _state = _AttendanceViewState.initial)
                  : _refresh,
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      enableInteractiveSelection: true,
      enableSuggestions: !obscureText,
      autocorrect: false,
      style: GoogleFonts.outfit(color: U.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        hintStyle: GoogleFonts.outfit(
          color: U.sub.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        filled: true,
        fillColor: U.surface,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: U.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: U.primary),
        ),
      ),
    );
  }
}

class _GradientHero extends StatelessWidget {
  const _GradientHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.accent,
    this.subtitleColor,
    this.detail,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color? accent;
  final Color? subtitleColor;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? U.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [U.card, accentColor.withValues(alpha: 0.18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            eyebrow,
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              color: subtitleColor ?? U.sub,
              fontSize: 14,
              height: 1.45,
              fontWeight: subtitleColor == null
                  ? FontWeight.w500
                  : FontWeight.w700,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, color: U.sub, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    detail!,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


class _TodayStatusCard extends StatelessWidget {
  const _TodayStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: U.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPulseButton extends StatelessWidget {
  const _TodayPulseButton({required this.animation, required this.onTap});

  final AnimationController animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Container(
          decoration: BoxDecoration(
            color: U.card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: U.border,
              width: 0.8,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today_rounded,
                      color: U.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Today',
                      style: GoogleFonts.plusJakartaSans(
                        color: U.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodaySubjectRow extends StatelessWidget {
  const _TodaySubjectRow({
    required this.name,
    required this.totalClasses,
    required this.attendedClasses,
    required this.percentage,
    required this.icon,
    required this.color,
  });

  final String name;
  final int totalClasses;
  final int attendedClasses;
  final double percentage;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$attendedClasses / $totalClasses classes',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceDateSheet extends StatefulWidget {
  const _AttendanceDateSheet({
    required this.title,
    required this.dateLabel,
    required this.date,
    required this.credentials,
    required this.onRefresh,
    this.portalDateLabel,
    this.mode = _AttendanceRangeMode.period,
  });

  final String title;
  final String dateLabel;
  final DateTime date;
  final Map<String, String> credentials;
  final VoidCallback onRefresh;
  final String? portalDateLabel;
  final _AttendanceRangeMode mode;

  @override
  State<_AttendanceDateSheet> createState() => _AttendanceDateSheetState();
}

class _AttendanceDateSheetState extends State<_AttendanceDateSheet> {
  late Future<Map<String, dynamic>> _future;

  String _formatPortalDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day-$month-${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG][Sheet] initState called for: ${widget.title}');
    _loadData();
  }

  void _loadData() {
    final portalDate = widget.portalDateLabel ?? _formatPortalDate(widget.date);
    debugPrint(
      '[DEBUG][Sheet] _loadData: title=${widget.title}, portalDate=$portalDate, mode=${widget.mode}',
    );

    final serviceMode = widget.credentials['college'] == 'acet'
        ? (widget.mode == _AttendanceRangeMode.tillNow
              ? AttendanceRangeMode.tillNow
              : AttendanceRangeMode.period)
        : AttendanceRangeMode.period;

    debugPrint(
      '[DEBUG][Sheet] serviceMode=$serviceMode, college=${widget.credentials['college']}',
    );

    if (serviceMode == AttendanceRangeMode.tillNow) {
      debugPrint('[DEBUG][Sheet] Calling fetchAttendance (tillNow mode)');
      _future = AttendanceService.fetchAttendance(
        widget.credentials['rollNumber'] ?? '',
        widget.credentials['password'] ?? '',
        college: widget.credentials['college'] ?? 'aus',
        mode: serviceMode,
      );
    } else {
      debugPrint(
        '[DEBUG][Sheet] Calling fetchAttendance (period mode): fromDate=$portalDate, toDate=$portalDate',
      );
      _future = AttendanceService.fetchAttendance(
        widget.credentials['rollNumber'] ?? '',
        widget.credentials['password'] ?? '',
        college: widget.credentials['college'] ?? 'aus',
        fromDate: portalDate,
        toDate: portalDate,
        mode: serviceMode,
      );
    }
  }

  Color _percentageColor(double value) {
    if (value >= 75) {
      return U.green;
    }
    if (value >= 65) {
      return U.peach;
    }
    return U.red;
  }

  IconData _subjectIcon(String subject) {
    final key = subject.toLowerCase();
    if (key.contains('devc') || key.contains('ppsuc')) {
      return Icons.code_rounded;
    }
    if (key.contains('beee') || key.contains('e.')) {
      return Icons.electrical_services_rounded;
    }
    if (key.contains('iot')) return Icons.memory_rounded;
    if (key.contains('dtai')) return Icons.auto_awesome_rounded;
    if (key.contains('env')) return Icons.eco_rounded;
    if (key.contains('emp')) return Icons.psychology_alt_rounded;
    return Icons.book_rounded;
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Something went wrong while fetching attendance';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: U.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: U.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Attendance for ${widget.dateLabel}',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
              ),
              const SizedBox(height: 18),
              StatefulBuilder(
                builder: (context, setSheetState) {
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _future,
                    builder: (context, snapshot) {
                      debugPrint(
                        '[DEBUG][Sheet] FutureBuilder state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}',
                      );

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        debugPrint('[DEBUG][Sheet] Loading... showing spinner');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Transform.scale(
                              scale: 0.6,
                              child: const UtopiaLoader(scale: 0.6),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        debugPrint('[DEBUG][Sheet] Error: ${snapshot.error}');
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TodayStatusCard(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load attendance',
                              subtitle: _friendlyErrorMessage(
                                snapshot.error ?? 'Something went wrong',
                              ),
                              tint: U.red,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  setSheetState(() {
                                    _loadData();
                                  });
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: U.primary,
                                  foregroundColor: U.bg,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(
                                  'Try again',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      debugPrint('[DEBUG][Sheet] Data loaded successfully');
                      final dateData =
                          snapshot.data ?? const <String, dynamic>{};
                      final totalClasses =
                          (dateData['totalClasses'] as num?)?.toInt() ?? 0;
                      final totalAttended =
                          (dateData['totalAttended'] as num?)?.toInt() ?? 0;
                      final overall =
                          (dateData['overallPercentage'] as num?)?.toDouble() ??
                          0;
                      final subjects =
                          (dateData['subjects'] as List<dynamic>? ?? const [])
                              .cast<Map<String, dynamic>>();
                      final activeSubjects = subjects.where((subject) {
                        final held =
                            (subject['totalClasses'] as num?)?.toInt() ?? 0;
                        return held > 0;
                      }).toList();
                      final overallColor = _percentageColor(overall);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TodayStatusCard(
                            icon: totalClasses == 0
                                ? Icons.event_available_rounded
                                : Icons.calendar_today_rounded,
                            title: totalClasses == 0
                                ? 'No classes recorded'
                                : '$totalAttended of $totalClasses classes attended',
                            subtitle: totalClasses == 0
                                ? 'Nothing has been marked for this day.'
                                : '${overall.toStringAsFixed(1)}% attendance',
                            tint: totalClasses == 0 ? U.primary : overallColor,
                          ),
                          if (activeSubjects.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Subjects',
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...activeSubjects.map(
                              (subject) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TodaySubjectRow(
                                  name: subject['subject'].toString(),
                                  totalClasses:
                                      (subject['totalClasses'] as num?)
                                          ?.toInt() ??
                                      0,
                                  attendedClasses:
                                      (subject['attendedClasses'] as num?)
                                          ?.toInt() ??
                                      0,
                                  percentage:
                                      (subject['percentage'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  icon: _subjectIcon(
                                    subject['subject'].toString(),
                                  ),
                                  color: _percentageColor(
                                    (subject['percentage'] as num?)
                                            ?.toDouble() ??
                                        0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                setSheetState(() {
                                  _loadData();
                                });
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: U.primary,
                                foregroundColor: U.bg,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                'Refresh',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
