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
import 'saved_events_screen.dart';
import '../widgets/event_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/platform_support.dart';
import '../services/notification_service.dart';
import '../widgets/gradient_dot_button.dart';
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
                body: 'You received a certificate for participating in "${cert.eventTitle}"!',
              );
            }
            
            showUtopiaSnackBar(
              context,
              message: '🏆 New Certificate Awarded: "${cert.eventTitle}"!',
              tone: UtopiaSnackBarTone.success,
              actionLabel: 'View',
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EventCertificatesScreen()),
                );
              },
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
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : _buildUploadFAB(),
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
                            fontSize: 26,
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
        icon: Icon(Icons.notifications_outlined, color: U.text),
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
          } else if (value == 'saved') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedEventsScreen()));
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
            value: 'saved',
            child: Row(
              children: [
                Icon(Icons.bookmark_outline_rounded, color: U.text, size: 20),
                const SizedBox(width: 12),
                Text('Saved Events', style: GoogleFonts.outfit(color: U.text)),
              ],
            ),
          ),
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
            child: EventCard(event: events[index], isLarge: true, onReturn: _loadEvents),
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
          child: EventCard(event: events[index], isLarge: false, onReturn: _loadEvents),
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



  Widget _buildUploadFAB() {
    return GradientDotButton(
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
        );
        _loadEvents();
      },
      icon: Icons.add_rounded,
      label: 'Upload Event',
    ).animate().scale(delay: 500.ms, duration: 400.ms, curve: Curves.easeOutBack);
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
