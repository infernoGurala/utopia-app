import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
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
  final List<String> _categories = [
    'Tech', 'Sports', 'Workshops', 'Clubs', 'Cultural', 
    'Gaming', 'Music', 'Startup', 'Hackathons'
  ];
  
  String _selectedCategory = 'Tech';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      floatingActionButton: _buildUploadFAB(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                  _buildSectionTitle('Trending Events'),
                  const SizedBox(height: 16),
                  _buildTrendingCarousel(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Upcoming Events'),
                  const SizedBox(height: 16),
                  _buildVerticalList(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Nearby Campus Events'),
                  const SizedBox(height: 16),
                  _buildVerticalList(),
                  const SizedBox(height: 100), // padding for FAB
                ],
              ),
            ),
          ],
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
            Row(
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
                Column(
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
                    ),
                    Text(
                      'Discover what\'s happening',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: U.sub,
                      ),
                    ),
                  ],
                ),
              ],
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
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: U.primary.withOpacity(0.1),
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
              onTap: () => setState(() => _selectedCategory = category),
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
          Text(
            'See All',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: U.primary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildTrendingCarousel() {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildEventCard(
              isLarge: true,
              title: index == 0 ? 'HackTheFuture 2026' : (index == 1 ? 'Startup Mixer' : 'AI Summit'),
              category: index == 0 ? 'Hackathons' : (index == 1 ? 'Startup' : 'Tech'),
              date: 'May 20, 2026',
              time: '10:00 AM',
              venue: 'Main Auditorium',
              organizer: 'Computer Science Club',
              status: index == 0 ? 'Live Now' : 'Upcoming',
            ),
          ).animate().fadeIn(duration: 400.ms, delay: (300 + (index * 100)).ms).slideX(begin: 0.2, end: 0);
        },
      ),
    );
  }

  Widget _buildVerticalList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildEventCard(
            isLarge: false,
            title: index == 0 ? 'Robotics Workshop' : (index == 1 ? 'Cultural Fest Auditions' : 'Esports Tournament'),
            category: index == 0 ? 'Workshops' : (index == 1 ? 'Cultural' : 'Gaming'),
            date: 'May ${22 + index}, 2026',
            time: '2:00 PM',
            venue: 'Lab ${3 + index}',
            organizer: 'Robotics Society',
            status: 'Registration Open',
          ),
        ).animate().fadeIn(duration: 400.ms, delay: (400 + (index * 100)).ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildEventCard({
    required bool isLarge,
    required String title,
    required String category,
    required String date,
    required String time,
    required String venue,
    required String organizer,
    required String status,
  }) {
    final width = isLarge ? 300.0 : double.infinity;
    final imageHeight = isLarge ? 140.0 : 100.0;
    
    // Determine colors based on status
    Color statusColor = U.primary;
    if (status == 'Live Now') statusColor = U.red;
    if (status == 'Upcoming') statusColor = U.teal;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailsScreen(
              title: title,
              category: category,
              date: date,
              time: time,
              venue: venue,
              organizer: organizer,
              status: status,
            ),
          ),
        );
      },
      child: Container(
        width: width,
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
          // Banner Image Area
          Stack(
            children: [
              Hero(
                tag: 'event_banner_$title',
                child: Container(
                  height: imageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [U.primary.withOpacity(0.5), U.teal.withOpacity(0.5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.event_rounded, size: 48, color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    category,
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
          
          // Details Area
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
                        title,
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
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.outfit(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: U.dim),
                    const SizedBox(width: 6),
                    Text(
                      '$date • $time',
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
                        venue,
                        style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildUploadFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: U.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: U.primary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateEventScreen()),
        ),
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
}
