import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/models/google_calendar_models.dart';
import 'package:utopia_app/services/calendar_cache_service.dart';
import 'package:utopia_app/services/google_calendar_service.dart';
import 'calendar_manage_drawer.dart';
import 'event_editor_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum CalendarViewMode { month, week, day, agenda }

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _isConnected = false;
  bool _loading = true;
  bool _searching = false;
  List<GoogleCalendarEvent> _events = [];
  List<GoogleCalendarEvent> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  final PageController _monthPageController = PageController(initialPage: 500);
  int _monthPageIndex = 500;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _monthPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncInBackground();
    }
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _isConnected = await GoogleCalendarService.instance.isConnected();
    if (_isConnected) {
      await _loadEvents();
      unawaited(_syncInBackground());
    }
    setState(() => _loading = false);
  }

  Future<void> _syncInBackground() async {
    if (!_isConnected) return;
    await GoogleCalendarService.instance.syncAll();
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    final now = _focusedDate;
    final start = DateTime(now.year, now.month - 1, 1);
    final end = DateTime(now.year, now.month + 2, 0);
    final events = await CalendarCacheService.instance.getEvents(start: start, end: end);
    if (mounted) setState(() => _events = events);
  }

  Future<void> _connectAccount() async {
    setState(() => _loading = true);
    final success = await GoogleCalendarService.instance.connect();
    if (success) {
      _isConnected = true;
      await _loadEvents();
    }
    setState(() => _loading = false);
  }

  void _goToToday() {
    setState(() {
      _focusedDate = DateTime.now();
      _selectedDate = DateTime.now();
    });
    _loadEvents();
    // Reset month page controller
    if (_viewMode == CalendarViewMode.month) {
      _monthPageController.jumpToPage(500);
      _monthPageIndex = 500;
    }
  }

  void _openSearch() {
    setState(() {
      _searching = true;
      _searchResults = [];
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await CalendarCacheService.instance.searchEvents(query);
    if (mounted) setState(() => _searchResults = results);
  }

  void _openManageCalendars() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.80,
        expand: false,
        builder: (_, controller) => CalendarManageDrawer(
          onRefresh: () {
            _loadEvents();
          },
        ),
      ),
    );
  }

  Future<void> _openEventEditor({GoogleCalendarEvent? event, DateTime? initialDate}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(event: event, initialDate: initialDate),
      ),
    );
    if (result == true) {
      await _loadEvents();
    }
  }

  List<GoogleCalendarEvent> _eventsForDate(DateTime date) {
    return _events.where((e) {
      if (e.startTime == null) return false;
      if (e.isAllDay) {
        final startDay = DateTime(e.startTime!.year, e.startTime!.month, e.startTime!.day);
        final endDay = e.endTime != null
            ? DateTime(e.endTime!.year, e.endTime!.month, e.endTime!.day)
            : startDay;
        final checkDay = DateTime(date.year, date.month, date.day);
        return !checkDay.isBefore(startDay) && checkDay.isBefore(endDay.add(const Duration(days: 1)));
      }
      return e.startTime!.year == date.year &&
          e.startTime!.month == date.month &&
          e.startTime!.day == date.day;
    }).toList()
      ..sort((a, b) {
        if (a.isAllDay && !b.isAllDay) return -1;
        if (!a.isAllDay && b.isAllDay) return 1;
        return (a.startTime ?? DateTime(0)).compareTo(b.startTime ?? DateTime(0));
      });
  }

  Color _eventColor(GoogleCalendarEvent event) {
    final colorMap = {
      '1': const Color(0xFF7986CB),
      '2': const Color(0xFF33B679),
      '3': const Color(0xFF8E24AA),
      '4': const Color(0xFFE67C73),
      '5': const Color(0xFFF6BF26),
      '6': const Color(0xFFF4511E),
      '7': const Color(0xFF039BE5),
      '8': const Color(0xFF616161),
      '9': const Color(0xFF3F51B5),
      '10': const Color(0xFF0B8043),
      '11': const Color(0xFFD50000),
    };
    if (event.colorId != null && colorMap.containsKey(event.colorId)) {
      return colorMap[event.colorId]!;
    }
    return U.gold;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = appThemeNotifier.value.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        floatingActionButton: _isConnected
            ? FloatingActionButton(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                onPressed: () => _openEventEditor(initialDate: _selectedDate),
                child: const Icon(Icons.add),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              // ── App Bar ──
              _buildAppBar(),
              // ── Content ──
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: U.primary))
                    : !_isConnected
                        ? _buildConnectPrompt()
                        : _searching
                            ? _buildSearchResults()
                            : _buildCalendarBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAppBar() {
    if (_searching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: U.text),
              onPressed: _closeSearch,
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.plusJakartaSans(color: U.text),
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: U.dim),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: _performSearch,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: U.card,
                shape: BoxShape.circle,
                border: Border.all(color: U.border, width: 0.5),
              ),
              child: Icon(Icons.arrow_back_rounded, color: U.text, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Calendar',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: U.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (_isConnected) ...[
            IconButton(
              icon: Icon(Icons.today_rounded, color: U.primary, size: 22),
              tooltip: 'Go to today',
              onPressed: _goToToday,
            ),
            IconButton(
              icon: Icon(Icons.search_rounded, color: U.text, size: 22),
              onPressed: _openSearch,
            ),
            IconButton(
              icon: Icon(Icons.tune_rounded, color: U.text, size: 22),
              onPressed: _openManageCalendars,
            ),
          ],
        ],
      ),
    ).animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  // ═══════════════════════════════════════════════════════════════
  //  CONNECT PROMPT
  // ═══════════════════════════════════════════════════════════════

  Widget _buildConnectPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: U.gold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_month_rounded, color: U.gold, size: 48),
            ),
            const SizedBox(height: 28),
            Text(
              'Connect Google Calendar',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: U.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in with your Google account to sync your calendars, events, and reminders directly into UTOPIA.',
              style: GoogleFonts.plusJakartaSans(color: U.sub, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _connectAccount,
              icon: const Icon(Icons.login_rounded),
              label: Text('Connect Account', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.08, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  // ═══════════════════════════════════════════════════════════════
  //  SEARCH RESULTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          'Type to search events by title, description, or location.',
          style: GoogleFonts.plusJakartaSans(color: U.dim),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No events found.',
          style: GoogleFonts.plusJakartaSans(color: U.dim),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) => _buildEventTile(_searchResults[i]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CALENDAR BODY (VIEW SWITCHER)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCalendarBody() {
    return Column(
      children: [
        // View mode selector chips
        _buildViewSelector(),
        const SizedBox(height: 4),
        // Active view
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: switch (_viewMode) {
              CalendarViewMode.month => _buildMonthView(),
              CalendarViewMode.week => _buildWeekView(),
              CalendarViewMode.day => _buildDayView(),
              CalendarViewMode.agenda => _buildAgendaView(),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildViewSelector() {
    final modes = [
      (CalendarViewMode.month, 'Month', Icons.calendar_view_month_rounded),
      (CalendarViewMode.week, 'Week', Icons.view_week_rounded),
      (CalendarViewMode.day, 'Day', Icons.view_day_rounded),
      (CalendarViewMode.agenda, 'Agenda', Icons.view_agenda_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: modes.map((m) {
          final selected = _viewMode == m.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = m.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? U.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? U.primary.withValues(alpha: 0.3) : U.border.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(m.$3, size: 16, color: selected ? U.primary : U.dim),
                    const SizedBox(height: 4),
                    Text(
                      m.$2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        color: selected ? U.primary : U.dim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MONTH VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMonthView() {
    return Column(
      key: const ValueKey('month'),
      children: [
        const SizedBox(height: 8),
        // Month header with navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: U.text),
                onPressed: () {
                  _monthPageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_focusedDate),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: U.text,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: U.text),
                onPressed: () {
                  _monthPageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            ],
          ),
        ),
        // Day-of-week headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: U.dim,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Month grid (swipeable pages)
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _monthPageController,
            onPageChanged: (page) {
              final diff = page - _monthPageIndex;
              _monthPageIndex = page;
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + diff, 1);
              });
              _loadEvents();
            },
            itemBuilder: (ctx, pageIndex) {
              final diff = pageIndex - 500;
              final now = DateTime.now();
              final month = DateTime(now.year, now.month + diff, 1);
              return _buildMonthGrid(month);
            },
          ),
        ),
        const Divider(height: 1),
        // Selected day event list
        Expanded(child: _buildSelectedDayEventList()),
      ],
    );
  }

  Widget _buildMonthGrid(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon
    final daysInMonth = lastDay.day;

    final today = DateTime.now();
    final cells = <Widget>[];

    // Leading empty cells for alignment
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isSelected = date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final dayEvents = _eventsForDate(date);

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? U.primary.withValues(alpha: 0.15)
                  : isToday
                      ? U.gold.withValues(alpha: 0.08)
                      : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: U.gold.withValues(alpha: 0.4), width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? U.primary
                        : isToday
                            ? U.gold
                            : U.text,
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dayEvents.take(3).map((e) {
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _eventColor(e),
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1.1,
        children: cells,
      ),
    );
  }

  Widget _buildSelectedDayEventList() {
    final dayEvents = _eventsForDate(_selectedDate);
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Text(
            isToday ? 'Today' : DateFormat('EEE, MMM d').format(_selectedDate),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: U.text,
            ),
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty
              ? Center(
                  child: Text(
                    'No events',
                    style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: dayEvents.length,
                  itemBuilder: (ctx, i) => _buildEventTile(dayEvents[i]),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WEEK VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWeekView() {
    // Determine current week's Monday
    final weekStart = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final today = DateTime.now();
    final dayFmt = DateFormat('EEE');
    final dateFmt = DateFormat('d');

    return Column(
      key: const ValueKey('week'),
      children: [
        const SizedBox(height: 12),
        // Week day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: List.generate(7, (i) {
              final date = weekStart.add(Duration(days: i));
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
              final isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = date);
                    _loadEvents();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? U.primary.withValues(alpha: 0.15)
                          : isToday
                              ? U.gold.withValues(alpha: 0.08)
                              : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayFmt.format(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? U.primary : U.dim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFmt.format(date),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected
                                ? U.primary
                                : isToday
                                    ? U.gold
                                    : U.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        // Hourly timeline for selected day
        Expanded(child: _buildHourlyTimeline(_selectedDate)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DAY VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDayView() {
    return Column(
      key: const ValueKey('day'),
      children: [
        // Day navigation header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: U.text),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                  _loadEvents();
                },
              ),
              Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDate),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: U.text,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: U.sub),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: U.text),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                  _loadEvents();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildHourlyTimeline(_selectedDate)),
      ],
    );
  }

  Widget _buildHourlyTimeline(DateTime date) {
    final dayEvents = _eventsForDate(date);
    final allDayEvents = dayEvents.where((e) => e.isAllDay).toList();
    final timedEvents = dayEvents.where((e) => !e.isAllDay).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: 25 + (allDayEvents.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, index) {
        // All-day events section at the top
        if (allDayEvents.isNotEmpty && index == 0) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            color: U.surface.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALL DAY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: U.dim,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                ...allDayEvents.map((e) => _buildCompactEventChip(e)),
              ],
            ),
          );
        }

        final hour = allDayEvents.isNotEmpty ? index - 1 : index;
        if (hour < 0 || hour > 23) return const SizedBox();

        final hourEvents = timedEvents.where((e) {
          if (e.startTime == null) return false;
          return e.startTime!.hour == hour;
        }).toList();

        return Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: U.border.withValues(alpha: 0.15), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  hour == 0
                      ? '12 AM'
                      : hour < 12
                          ? '$hour AM'
                          : hour == 12
                              ? '12 PM'
                              : '${hour - 12} PM',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.dim, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: hourEvents.isEmpty
                    ? const SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: hourEvents.map((e) => _buildCompactEventChip(e)).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactEventChip(GoogleCalendarEvent event) {
    final color = _eventColor(event);
    final timeStr = event.isAllDay
        ? 'All day'
        : event.startTime != null
            ? DateFormat('hh:mm a').format(event.startTime!)
            : '';

    return GestureDetector(
      onTap: () => _openEventEditor(event: event),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                event.summary ?? 'Untitled',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: U.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeStr,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.dim),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  AGENDA VIEW
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAgendaView() {
    // Show upcoming events grouped by date
    final upcoming = _events
        .where((e) => e.startTime != null && !e.startTime!.isBefore(DateTime.now().subtract(const Duration(hours: 1))))
        .toList()
      ..sort((a, b) => (a.startTime ?? DateTime(0)).compareTo(b.startTime ?? DateTime(0)));

    if (upcoming.isEmpty) {
      return Center(
        key: const ValueKey('agenda'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 48, color: U.dim),
            const SizedBox(height: 16),
            Text(
              'No upcoming events',
              style: GoogleFonts.plusJakartaSans(color: U.dim, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<GoogleCalendarEvent>>{};
    for (final e in upcoming) {
      final key = DateFormat('yyyy-MM-dd').format(e.startTime!);
      grouped.putIfAbsent(key, () => []).add(e);
    }

    return ListView.builder(
      key: const ValueKey('agenda'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      itemCount: grouped.length,
      itemBuilder: (ctx, index) {
        final dateKey = grouped.keys.toList()[index];
        final events = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);
        final today = DateTime.now();
        final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
        final isTomorrow = date.year == today.year && date.month == today.month && date.day == today.day + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                isToday
                    ? 'Today'
                    : isTomorrow
                        ? 'Tomorrow'
                        : DateFormat('EEE, MMM d').format(date),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isToday ? U.gold : U.text,
                ),
              ),
            ),
            ...events.map((e) => _buildEventTile(e)),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  SHARED EVENT TILE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEventTile(GoogleCalendarEvent event) {
    final color = _eventColor(event);
    final timeStr = event.isAllDay
        ? 'All day'
        : event.startTime != null
            ? '${DateFormat('hh:mm a').format(event.startTime!)}${event.endTime != null ? ' – ${DateFormat('hh:mm a').format(event.endTime!)}' : ''}'
            : '';

    return GestureDetector(
      onTap: () => _openEventEditor(event: event),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: U.border.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.summary ?? 'Untitled Event',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: U.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: U.dim),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: U.sub),
                      ),
                      if (event.location != null && event.location!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined, size: 12, color: U.dim),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: U.sub),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (event.hangoutLink != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.videocam_outlined, size: 12, color: U.gold),
                        const SizedBox(width: 4),
                        Text(
                          'Google Meet',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.gold, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (event.attendees.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: U.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 12, color: U.dim),
                    const SizedBox(width: 4),
                    Text(
                      '${event.attendees.length}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, color: U.dim, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
