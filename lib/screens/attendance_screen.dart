import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../models/campus.dart';
import '../services/attendance_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/utopia_snackbar.dart';

enum _AttendanceViewState { initial, loading, loaded, error }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  Campus _selectedCampus = Campus.aus;

  late final AnimationController _glowController;
  _AttendanceViewState _state = _AttendanceViewState.loading;
  bool _obscurePassword = true;
  String? _errorMessage;
  Map<String, dynamic>? _attendanceData;
  Map<String, String>? _savedCredentials;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    unawaited(_loadSavedCredentials());
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
      setState(() {
        _selectedCampus = Campus.fromName(credentials['campus']);
      });
      await _fetchAttendance(
        rollNumber: _rollController.text,
        password: _passwordController.text,
        campus: _selectedCampus,
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
    required Campus campus,
    required bool saveCredentials,
    required bool keepFormOnFailure,
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
      final result = await AttendanceService.fetchAttendance(
        trimmedRoll,
        password,
        campus: campus,
      );
      if (saveCredentials) {
        await SecureStorageService.saveCredentials(
          trimmedRoll,
          password,
          campus,
        );
      }
      _savedCredentials = {
        'rollNumber': trimmedRoll,
        'password': password,
        'campus': campus.name,
      };
      if (!mounted) {
        return;
      }
      setState(() {
        _attendanceData = result;
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
    await _fetchAttendance(
      rollNumber: credentials['rollNumber'] ?? '',
      password: credentials['password'] ?? '',
      campus: Campus.fromName(credentials['campus']),
      saveCredentials: false,
      keepFormOnFailure: false,
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
    if (!mounted) {
      return;
    }
    setState(() {
      _savedCredentials = null;
      _attendanceData = null;
      _errorMessage = null;
      _rollController.clear();
      _passwordController.clear();
      _selectedCampus = Campus.aus;
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
      return const Color(0xFFA6E3A1);
    }
    if (value >= 65) {
      return const Color(0xFFF9E2AF);
    }
    return const Color(0xFFF38BA8);
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
    final credentials = _savedCredentials;
    if (credentials == null) {
      return;
    }
    final now = DateTime.now();
    final todayLabel = _formatPortalDate(now);

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
      ),
    );
  }

  Future<void> _showYesterdaySheet() async {
    final credentials = _savedCredentials;
    if (credentials == null) {
      return;
    }
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayLabel = _formatPortalDate(yesterday);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AttendanceDateSheet(
        title: 'Yesterday',
        dateLabel: yesterdayLabel,
        date: yesterday,
        credentials: credentials,
        onRefresh: _refresh,
      ),
    );
  }

  Future<void> _showDatePickerSheet() async {
    final credentials = _savedCredentials;
    if (credentials == null) {
      return;
    }

    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: U.primary,
              surface: U.card,
              onSurface: U.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    final dateLabel = _formatPortalDate(selectedDate);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AttendanceDateSheet(
        title: _formatDisplayDate(selectedDate),
        dateLabel: dateLabel,
        date: selectedDate,
        credentials: credentials,
        onRefresh: _refresh,
      ),
    );
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
        automaticallyImplyLeading: false,
        backgroundColor: U.bg,
        elevation: 0,
        titleSpacing: 20,
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
              'Overview',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (showLoadedActions)
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          if (showLoadedActions)
            IconButton(
              onPressed: _disconnect,
              tooltip: 'Disconnect',
              icon: const Icon(Icons.logout_rounded),
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GradientHero(
            icon: Icons.fact_check_rounded,
            eyebrow: 'Semester sync',
            title: 'Bring attendance into your daily flow',
            subtitle:
                'Connect once and keep your attendance report inside Utopia.',
            trailing: _InfoPill(
              icon: Icons.shield_rounded,
              label: 'On-device only',
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: U.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: U.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.lock_person_rounded,
                          color: U.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connect your college account',
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Enter your university portal credentials.',
                              style: GoogleFonts.outfit(
                                color: U.sub,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Campus selector
                  Text(
                    'Campus',
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<Campus>(
                    segments: Campus.values
                        .map(
                          (c) => ButtonSegment<Campus>(
                            value: c,
                            label: Text(c.label),
                          ),
                        )
                        .toList(),
                    selected: {_selectedCampus},
                    onSelectionChanged: (Set<Campus> selection) {
                      setState(() => _selectedCampus = selection.first);
                    },
                    style: SegmentedButton.styleFrom(
                      backgroundColor: U.surface,
                      foregroundColor: U.sub,
                      selectedForegroundColor: U.bg,
                      selectedBackgroundColor: U.primary,
                      side: BorderSide(color: U.border),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _rollController,
                    hintText: 'e.g. 25B11ME001',
                    labelText: 'Roll Number',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
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
                    onSubmitted: (_) => _fetchAttendance(
                      rollNumber: _rollController.text,
                      password: _passwordController.text,
                      campus: _selectedCampus,
                      saveCredentials: true,
                      keepFormOnFailure: true,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _fetchAttendance(
                        rollNumber: _rollController.text,
                        password: _passwordController.text,
                        campus: _selectedCampus,
                        saveCredentials: true,
                        keepFormOnFailure: true,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: U.primary,
                        foregroundColor: U.bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.sync_lock_rounded),
                      label: Text(
                        'Connect attendance',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Privacy disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: U.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: U.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: U.sub,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'These credentials are used only to sign in to your university portal. They are stored locally on this device and never sent to any third-party server. You can clear them at any time.',
                            style: GoogleFonts.outfit(
                              color: U.sub,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: U.card,
              border: Border.all(color: U.border),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 18),
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
                        trailing: _InfoPill(
                          icon: Icons.cloud_done_rounded,
                          label: 'Till now',
                        ),
                        accent: overallColor,
                        subtitleColor: belowTarget > 0 ? U.red : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Subjects',
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showYesterdaySheet(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: U.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: U.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: U.sub,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Yesterday',
                                    style: GoogleFonts.outfit(
                                      color: U.sub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showDatePickerSheet(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: U.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: U.border),
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: U.sub,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _TodayPulseButton(
            animation: _glowController,
            onTap: _showTodaySheet,
          ),
        ),
      ],
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
    this.trailing,
    this.accent,
    this.subtitleColor,
    this.detail,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
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
              ...?(trailing != null ? [trailing!] : null),
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final resolvedTone = U.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: U.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolvedTone.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: resolvedTone, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: resolvedTone == U.primary ? U.text : resolvedTone,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [U.primary, U.primary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: U.primary.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: U.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Today',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
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
  });

  final String title;
  final String dateLabel;
  final DateTime date;
  final Map<String, String> credentials;
  final VoidCallback onRefresh;

  @override
  State<_AttendanceDateSheet> createState() => _AttendanceDateSheetState();
}

class _AttendanceDateSheetState extends State<_AttendanceDateSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _future = AttendanceService.fetchAttendance(
      widget.credentials['rollNumber'] ?? '',
      widget.credentials['password'] ?? '',
      campus: Campus.fromName(widget.credentials['campus']),
      fromDate: widget.dateLabel,
      toDate: widget.dateLabel,
    );
  }

  Color _percentageColor(double value) {
    if (value >= 75) {
      return const Color(0xFFA6E3A1);
    }
    if (value >= 65) {
      return const Color(0xFFF9E2AF);
    }
    return const Color(0xFFF38BA8);
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
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

                    final dateData = snapshot.data ?? const <String, dynamic>{};
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
                                  (subject['percentage'] as num?)?.toDouble() ??
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}
