import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/role_service.dart';
import 'event_details_screen.dart';
import 'create_event_screen.dart';
import 'event_notifications_screen.dart';
import 'admin_events_panel.dart';
import 'organizer_dashboard_screen.dart';
import 'event_certificates_screen.dart';

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
  }

  Future<void> _checkRole() async {
    final isSuper = await RoleService().isSuperUser();
    if (mounted) setState(() => _isSuperUser = isSuper);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyFilters() async {
    final category = _selectedCategory == 'All' ? null : _selectedCategory;
    final events = await EventService.instance.getEvents(
      category: category,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    if (mounted) {
      setState(() => _filteredEvents = events);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      floatingActionButton: _buildUploadFAB(),
      body: SafeArea(
        child: RefreshIndicator(
          color: U.primary,
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
                    const SizedBox(height: 24),
                    _buildCategories(),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: const Center(child: UtopiaLoader(scale: 0.7)),
                      )
                    else if (_searchQuery.isNotEmpty || _selectedCategory != 'All') ...[
                      _buildSectionTitle('Results'),
                      const SizedBox(height: 16),
                      _filteredEvents.isEmpty
                          ? _buildEmptyState('No events found')
                          : _buildVerticalList(_filteredEvents),
                    ] else ...[
                      if (_liveEvents.isNotEmpty) ...[
                        _buildSectionTitle('🔴 Live Now'),
                        const SizedBox(height: 16),
                        _buildHorizontalCarousel(_liveEvents),
                        const SizedBox(height: 32),
                      ],
                      _buildSectionTitle('🔥 Trending Events'),
                      const SizedBox(height: 16),
                      _trendingEvents.isEmpty
                          ? _buildEmptyState('No trending events yet')
                          : _buildHorizontalCarousel(_trendingEvents),
                      const SizedBox(height: 32),
                      _buildSectionTitle('📅 Upcoming Events'),
                      const SizedBox(height: 16),
                      _upcomingEvents.isEmpty
                          ? _buildEmptyState('No upcoming events')
                          : _buildVerticalList(_upcomingEvents),
                      if (_endingSoonEvents.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle('⏰ Ending Soon'),
                        const SizedBox(height: 16),
                        _buildHorizontalCarousel(_endingSoonEvents),
                      ],
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
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
                        Text(
                          'Campus Events',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: U.primary,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Discover what\'s happening',
                          style: GoogleFonts.outfit(fontSize: 14, color: U.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
            Row(
              children: [
                _buildNotificationIcon(),
                const SizedBox(width: 8),
                _buildMenuIcon(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Container(
      decoration: BoxDecoration(
        color: U.surface,
        shape: BoxShape.circle,
        border: Border.all(color: U.border),
      ),
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_outlined, color: U.text),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: U.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: U.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventNotificationsScreen()),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).scale();
  }

  Widget _buildMenuIcon() {
    return Container(
      decoration: BoxDecoration(
        color: U.surface,
        shape: BoxShape.circle,
        border: Border.all(color: U.border),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert_rounded, color: U.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: U.surface,
        onSelected: (value) {
          if (value == 'organizer') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizerDashboardScreen()));
          } else if (value == 'admin') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEventsPanel()));
          } else if (value == 'certificates') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const EventCertificatesScreen()));
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'organizer',
            child: Row(
              children: [
                Icon(Icons.business_center_outlined, color: U.text, size: 20),
                const SizedBox(width: 12),
                Text('Organizer Dashboard', style: GoogleFonts.outfit(color: U.text)),
              ],
            ),
          ),
          if (_isSuperUser)
            PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, color: U.text, size: 20),
                  const SizedBox(width: 12),
                  Text('Admin Panel', style: GoogleFonts.outfit(color: U.text)),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'certificates',
            child: Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: U.text, size: 20),
                const SizedBox(width: 12),
                Text('My Certificates', style: GoogleFonts.outfit(color: U.text)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 150.ms).scale();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: U.dim),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(color: U.text, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 16),
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
                  setState(() {
                    _searchQuery = '';
                    _filteredEvents = [];
                  });
                },
                child: Icon(Icons.close_rounded, color: U.dim, size: 20),
              )
            else
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded, color: U.primary, size: 20),
              ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
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
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? U.primary : U.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? U.primary : U.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    category,
                    style: GoogleFonts.outfit(
                      color: isSelected ? U.bg : U.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (250 + (index * 50)).ms).slideX(begin: 0.2, end: 0);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: U.text,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildHorizontalCarousel(List<EventModel> events) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: events.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildEventCard(events[index], isLarge: true),
          ).animate().fadeIn(duration: 400.ms, delay: (300 + (index * 100)).ms).slideX(begin: 0.2, end: 0);
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
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildEventCard(events[index], isLarge: false),
        ).animate().fadeIn(duration: 400.ms, delay: (400 + (index * 100)).ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: U.dim),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.outfit(fontSize: 16, color: U.sub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(EventModel event, {required bool isLarge}) {
    final width = isLarge ? 300.0 : double.infinity;
    final imageHeight = isLarge ? 140.0 : 100.0;

    Color statusColor = U.primary;
    if (event.status == EventStatus.liveNow) {
      statusColor = U.red;
    } else if (event.status == EventStatus.upcoming) {
      statusColor = U.teal;
    } else if (event.status == EventStatus.almostFull) {
      statusColor = U.peach;
    } else if (event.status == EventStatus.completed) {
      statusColor = U.dim;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
        );
        _loadEvents(); // Refresh after returning
      },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: U.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Banner Image
            Stack(
              children: [
                Hero(
                  tag: 'event_banner_${event.id ?? event.title}',
                  child: Container(
                    height: imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [U.primary.withValues(alpha: 0.5), U.teal.withValues(alpha: 0.5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: event.bannerUrl != null && event.bannerUrl!.isNotEmpty
                        ? ColorFiltered(
                            colorFilter: (event.status == EventStatus.completed || event.status == EventStatus.cancelled)
                                ? const ColorFilter.matrix([
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0,      0,      0,      1, 0,
                                  ])
                                : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                            child: CachedNetworkImage(
                              imageUrl: event.bannerUrl!.trim().replaceFirst('http://', 'https://'),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Center(
                                child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      event.category,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: GoogleFonts.outfit(
                            fontSize: isLarge ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: U.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isLarge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: U.dim),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(event.date)} • ${event.startTime}',
                        style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: U.dim),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.venue,
                          style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!isLarge) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 14, color: U.dim),
                        const SizedBox(width: 6),
                        Text(
                          '${event.participantCount} registered',
                          style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.status.label,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: U.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: U.primary,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          _loadEvents();
        },
        icon: Icon(Icons.add_rounded, color: U.bg),
        label: Text(
          'Upload Event',
          style: GoogleFonts.outfit(
            color: U.bg,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
