import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'create_event_screen.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  List<EventModel> _myEvents = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        EventService.instance.getEventsByOrganizer(uid),
        EventService.instance.getOrganizerAnalytics(uid),
      ]);
      if (mounted) {
        setState(() {
          _myEvents = results[0] as List<EventModel>;
          _analytics = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Organizer Dashboard',
          style: GoogleFonts.outfit(color: U.text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: UtopiaLoader(scale: 0.7))
          : RefreshIndicator(
              color: U.primary,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(user),
                      const SizedBox(height: 32),
                      Text(
                        'Analytics Overview',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticsGrid(),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Events',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
                              _loadData();
                            },
                            icon: Icon(Icons.add_rounded, color: U.primary, size: 18),
                            label: Text('Create New', style: GoogleFonts.outfit(color: U.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _myEvents.isEmpty
                          ? _buildEmptyState()
                          : _buildManageEventsList(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: U.primary.withValues(alpha: 0.2),
            backgroundImage: user?.photoURL != null ? CachedNetworkImageProvider(user!.photoURL!) : null,
            child: user?.photoURL == null ? Icon(Icons.business_center_rounded, color: U.primary, size: 32) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user?.displayName ?? 'Organizer',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_myEvents.length} Events • ${_analytics['total_registrations'] ?? 0} Registrations',
                  style: GoogleFonts.outfit(fontSize: 13, color: U.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildAnalyticsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total Registrations', '${_analytics['total_registrations'] ?? 0}', Icons.how_to_reg_rounded, U.primary),
        _buildStatCard('Event Views', '${_analytics['total_views'] ?? 0}', Icons.visibility_rounded, U.teal),
        _buildStatCard('Engagement', _analytics['engagement'] ?? '0%', Icons.auto_graph_rounded, U.peach),
        _buildStatCard('Total Shares', '${_analytics['total_shares'] ?? 0}', Icons.share_rounded, U.blue),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: GoogleFonts.outfit(fontSize: 12, color: U.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: U.text)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_note_rounded, size: 48, color: U.dim),
            const SizedBox(height: 12),
            Text('No events yet', style: GoogleFonts.outfit(fontSize: 16, color: U.sub)),
            const SizedBox(height: 4),
            Text('Create your first event!', style: GoogleFonts.outfit(fontSize: 13, color: U.dim)),
          ],
        ),
      ),
    );
  }

  Widget _buildManageEventsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myEvents.length,
      itemBuilder: (context, index) {
        final event = _myEvents[index];
        return _buildManageEventItem(event);
      },
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildManageEventItem(EventModel event) {
    Color statusColor = U.primary;
    if (event.status == EventStatus.liveNow) statusColor = U.red;
    if (event.status == EventStatus.upcoming) statusColor = U.teal;
    if (event.status == EventStatus.completed) statusColor = U.dim;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text)),
                    const SizedBox(height: 4),
                    Text(_formatDate(event.date), style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(event.status.label, style: GoogleFonts.outfit(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  if (!event.isApproved) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: U.peach.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Pending', style: GoogleFonts.outfit(color: U.peach, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: U.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${event.participantCount} registered${event.participantLimit > 0 ? ' / ${event.participantLimit}' : ''}',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: U.text),
              ),
              Row(
                children: [
                  _buildIconBtn(Icons.people_outline_rounded, 'Participants', () async {
                    if (event.id == null) return;
                    final regs = await EventService.instance.getRegistrations(event.id!);
                    if (mounted) {
                      _showParticipantsDialog(event.title, regs);
                    }
                  }),
                  _buildIconBtn(Icons.visibility_rounded, '${event.viewCount} views', null),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, color: U.primary, size: 20),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }

  void _showParticipantsDialog(String eventTitle, List<EventRegistration> regs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$eventTitle — Participants', style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: regs.isEmpty
              ? Center(child: Text('No registrations yet', style: GoogleFonts.outfit(color: U.sub)))
              : ListView.builder(
                  itemCount: regs.length,
                  itemBuilder: (context, index) {
                    final r = regs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: U.primary.withValues(alpha: 0.1),
                        child: Text(
                          r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      title: Text(r.userName, style: GoogleFonts.outfit(color: U.text)),
                      subtitle: Text(r.ticketId ?? '', style: GoogleFonts.outfit(color: U.dim, fontSize: 11)),
                      trailing: r.checkedIn
                          ? Icon(Icons.check_circle_rounded, color: U.teal, size: 20)
                          : Icon(Icons.circle_outlined, color: U.dim, size: 20),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: U.primary)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
