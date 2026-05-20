import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/role_service.dart';
import 'event_notifications_screen.dart';
import 'admin_events_panel.dart';
import 'organizer_dashboard_screen.dart';
import 'event_certificates_screen.dart';
import 'saved_events_screen.dart';
import '../widgets/event_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_support.dart';
import '../services/notification_service.dart';
import '../widgets/utopia_snackbar.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _categories = [
    'All', 'Tech', 'Sports', 'Workshops', 'Clubs', 'Cultural',
    'Gaming', 'Music', 'Startup', 'Hackathons', 'AI', 'Robotics', 'Competitions',
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  List<EventModel> _trendingEvents = [];
  List<EventModel> _upcomingEvents = [];
  List<EventModel> _liveEvents = [];
  List<EventModel> _endingSoonEvents = [];
  List<EventModel> _filteredEvents = [];
  bool _isLoading = true;
  bool _isSuperUser = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _checkRole();
    _checkForNewCertificates();
  }

  Future<void> _checkRole() async {
    final isSuper = await RoleService().isSuperUser();
    if (mounted) setState(() => _isSuperUser = isSuper);
  }

  Future<void> _checkForNewCertificates() async {
    try {
      final certs = await EventService.instance.getMyCertificates();
      if (certs.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final knownCertIds = prefs.getStringList('known_certificate_ids') ?? [];
      final newCerts = certs.where((c) => c.id != null && !knownCertIds.contains(c.id)).toList();
      if (newCerts.isNotEmpty) {
        final updatedIds = List<String>.from(knownCertIds)..addAll(newCerts.map((c) => c.id!));
        await prefs.setStringList('known_certificate_ids', updatedIds);
        if (mounted) {
          for (final cert in newCerts) {
            if (PlatformSupport.supportsNotifications) {
              await NotificationService.sendCertificateNotification(
                title: '🏆 Certificate Received!',
                body: 'You received a certificate for "${cert.eventTitle}"!',
              );
            }
            showUtopiaSnackBar(
              context,
              message: '🏆 New Certificate: "${cert.eventTitle}"!',
              tone: UtopiaSnackBarTone.success,
              actionLabel: 'View',
              onActionPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventCertificatesScreen()),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check for new certificates: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        EventService.instance.getTrendingEvents(limit: 5),
        EventService.instance.getUpcomingEvents(limit: 10),
        EventService.instance.getLiveEvents(limit: 5),
        EventService.instance.getEndingSoonEvents(limit: 5),
      ]);
      if (mounted) {
        setState(() {
          _trendingEvents = results[0];
          _upcomingEvents = results[1];
          _liveEvents = results[2];
          _endingSoonEvents = results[3];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyFilters() async {
    final category = _selectedCategory == 'All' ? null : _selectedCategory;
    final events = await EventService.instance.getEvents(
      category: category,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) setState(() => _filteredEvents = events);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          // ── Beautiful dynamic light leak backdrops ──
          Positioned(
            top: -100,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    U.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    U.teal.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content ──
          SafeArea(
            child: RefreshIndicator(
              color: U.primary,
              backgroundColor: U.card,
              onRefresh: _loadEvents,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 20),
                        _buildCategories(),
                        const SizedBox(height: 32),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(child: UtopiaLoader(scale: 0.7)),
                          )
                        else if (_searchQuery.isNotEmpty || _selectedCategory != 'All') ...[
                          _buildSectionTitle('Results'),
                          const SizedBox(height: 16),
                          _filteredEvents.isEmpty
                              ? _buildEmptyState('No events found')
                              : _buildVerticalList(_filteredEvents),
                        ] else ...[
                          if (_liveEvents.isNotEmpty) ...[
                            _buildSectionTitle('Live Now', isLive: true),
                            const SizedBox(height: 16),
                            _buildHorizontalCarousel(_liveEvents),
                            const SizedBox(height: 32),
                          ],
                          _buildSectionTitle('Trending Events'),
                          const SizedBox(height: 16),
                          _trendingEvents.isEmpty
                              ? _buildEmptyState('No trending events yet')
                              : _buildHorizontalCarousel(_trendingEvents),
                          const SizedBox(height: 32),
                          _buildSectionTitle('Upcoming Events'),
                          const SizedBox(height: 16),
                          _upcomingEvents.isEmpty
                              ? _buildEmptyState('No upcoming events')
                              : _buildVerticalList(_upcomingEvents),
                          if (_endingSoonEvents.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionTitle('Ending Soon', isUrgent: true),
                            const SizedBox(height: 16),
                            _buildHorizontalCarousel(_endingSoonEvents),
                          ],
                        ],
                        const SizedBox(height: 110),
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

  Widget _buildHeader() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (Navigator.canPop(context))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [U.primary, U.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'Campus Events',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.outfit(fontSize: 12, color: U.sub, letterSpacing: 0.2, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),
            _buildHeaderIcon(
              icon: Icons.notifications_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventNotificationsScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _buildMenuIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: U.card.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: U.border.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: U.text, size: 20),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildMenuIcon() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: U.border.withValues(alpha: 0.8)),
          ),
          color: U.surface,
          elevation: 8,
          onSelected: (value) {
            if (value == 'organizer') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()));
            } else if (value == 'admin') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEventsPanel()));
            } else if (value == 'certificates') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EventCertificatesScreen()));
            } else if (value == 'saved') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedEventsScreen()));
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('organizer', Icons.business_center_outlined, 'Organizer Dashboard'),
            if (_isSuperUser)
              _buildMenuItem('admin', Icons.admin_panel_settings_outlined, 'Admin Panel'),
            const PopupMenuDivider(),
            _buildMenuItem('saved', Icons.bookmark_outline_rounded, 'Saved Events'),
            _buildMenuItem('certificates', Icons.workspace_premium_outlined, 'My Certificates'),
          ],
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: U.card.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: U.border.withValues(alpha: 0.6)),
            ),
            child: Icon(Icons.more_vert_rounded, color: U.text, size: 20),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).scale(begin: const Offset(0.9, 0.9));
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: U.text, size: 18),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: U.card.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: U.border.withValues(alpha: 0.6), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: U.primary.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() { _searchQuery = ''; _filteredEvents = []; });
                    },
                    child: Icon(Icons.close_rounded, color: U.dim, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideY(begin: 0.15, end: 0),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                if (category != 'All') {
                  _applyFilters();
                } else if (_searchQuery.isEmpty) {
                  setState(() => _filteredEvents = []);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [U.primary, U.primary.withValues(alpha: 0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : U.card.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : U.border.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: U.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  category,
                  style: GoogleFonts.outfit(
                    color: isSelected ? U.bg : U.sub,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: (200 + index * 40).ms).slideX(begin: 0.15, end: 0);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isLive = false, bool isUrgent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (isLive) ...[
            _PulsingDot(color: U.red),
            const SizedBox(width: 8),
          ],
          if (isUrgent) ...[
            Text('⏰ ', style: GoogleFonts.outfit(fontSize: 16)),
          ],
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: U.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            width: 28, height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [U.primary, U.teal]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHorizontalCarousel(List<EventModel> events) {
    return SizedBox(
      height: 292,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: events.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: EventCard(event: events[index], isLarge: true, onReturn: _loadEvents),
          ).animate().fadeIn(duration: 400.ms, delay: (250 + index * 80).ms).slideX(begin: 0.15, end: 0);
        },
      ),
    );
  }

  Widget _buildVerticalList(List<EventModel> events) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: EventCard(event: events[index], isLarge: false, onReturn: _loadEvents),
        ).animate().fadeIn(duration: 400.ms, delay: (350 + index * 70).ms).slideY(begin: 0.08, end: 0);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [U.primary.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
              child: Icon(Icons.event_busy_rounded, size: 36, color: U.primary.withValues(alpha: 0.5)),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -8, duration: 2000.ms, curve: Curves.easeInOut),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.outfit(fontSize: 15, color: U.sub, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing dot widget for Live Now ──
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _animation.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _animation.value * 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
