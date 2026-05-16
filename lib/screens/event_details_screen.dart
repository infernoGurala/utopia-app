import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'event_chat_screen.dart';
import 'qr_ticket_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late EventModel _event;
  bool _isRegistered = false;
  bool _isLiked = false;

  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadState();
    // Increment view count
    if (_event.id != null) {
      EventService.instance.incrementViews(_event.id!);
    }
  }

  Future<void> _loadState() async {
    if (_event.id == null) {
      return;
    }
    try {
      final results = await Future.wait([
        EventService.instance.isRegistered(_event.id!),
        EventService.instance.isLiked(_event.id!),
      ]);
      // Refresh event data
      final fresh = await EventService.instance.getEvent(_event.id!);
      if (mounted) {
        setState(() {
          _isRegistered = results[0] as bool;
          _isLiked = results[1] as bool;
          if (fresh != null) _event = fresh;

        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _toggleRegistration() async {
    if (_event.id == null) return;
    setState(() => _isRegistering = true);
    try {
      if (_isRegistered) {
        await EventService.instance.unregisterFromEvent(_event.id!);
        if (mounted) {
          setState(() => _isRegistered = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unregistered from event', style: GoogleFonts.outfit())),
          );
        }
      } else {
        final reg = await EventService.instance.registerForEvent(_event.id!);
        if (reg != null && mounted) {
          setState(() => _isRegistered = true);
          // Navigate to QR ticket
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QRTicketScreen(event: _event, registration: reg),
            ),
          );
        }
      }
      _loadState(); // Refresh counts
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.outfit()), backgroundColor: U.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_event.id == null) return;
    try {
      if (_isLiked) {
        await EventService.instance.unlikeEvent(_event.id!);
      } else {
        await EventService.instance.likeEvent(_event.id!);
      }
      if (mounted) setState(() => _isLiked = !_isLiked);
    } catch (_) {}
  }

  void _shareEvent() {
    SharePlus.instance.share(
      ShareParams(text: 'Check out ${_event.title} on Utopia! 📅 ${_formatDate(_event.date)} at ${_event.venue}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = U.primary;
    if (_event.status == EventStatus.liveNow) statusColor = U.red;
    if (_event.status == EventStatus.upcoming) statusColor = U.teal;
    if (_event.status == EventStatus.almostFull) statusColor = U.peach;

    return Scaffold(
      backgroundColor: U.bg,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(statusColor),
                      const SizedBox(height: 24),
                      _buildActionBar(),
                      const SizedBox(height: 24),
                      _buildInfoSection(),
                      const SizedBox(height: 24),
                      if (_event.prizeInfo != null && _event.prizeInfo!.isNotEmpty) ...[
                        _buildPrizeSection(),
                        const SizedBox(height: 24),
                      ],
                      if (_event.requirements != null && _event.requirements!.isNotEmpty) ...[
                        _buildRequirementsSection(),
                        const SizedBox(height: 24),
                      ],
                      _buildDescription(),
                      if (_event.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildTags(),
                      ],
                      if (_event.whatsappLink != null || _event.participationLink != null) ...[
                        const SizedBox(height: 24),
                        _buildLinks(),
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: U.bg,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Hero(
          tag: 'event_banner_${_event.id ?? _event.title}',
          child: _event.bannerUrl != null && _event.bannerUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: _event.bannerUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [U.primary.withValues(alpha: 0.8), U.teal.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(child: CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.5), strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => _buildDefaultBanner(),
                )
              : _buildDefaultBanner(),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [U.primary.withValues(alpha: 0.8), U.teal.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.event_rounded, size: 80, color: Colors.white30)),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: U.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: U.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                _event.category,
                style: GoogleFonts.outfit(color: U.primary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                _event.status.label,
                style: GoogleFonts.outfit(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        Text(
          _event.title,
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: U.text, height: 1.2),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
        if (_event.shortDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _event.shortDescription,
            style: GoogleFonts.outfit(fontSize: 15, color: U.sub),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: U.dim.withValues(alpha: 0.2),
              child: Icon(Icons.business_center_rounded, size: 16, color: U.dim),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'By ${_event.conductedBy.isNotEmpty ? _event.conductedBy : _event.organizerName}',
                style: GoogleFonts.outfit(fontSize: 14, color: U.sub, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1, end: 0),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        _buildActionItem(
          _isLiked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          _isLiked ? 'Saved' : 'Save',
          _toggleLike,
          highlight: _isLiked,
        ),
        const SizedBox(width: 12),
        _buildActionItem(Icons.chat_bubble_outline_rounded, 'Chat', () {
          if (_event.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => EventChatScreen(event: _event)),
            );
          }
        }),
        const SizedBox(width: 12),
        _buildActionItem(Icons.share_outlined, 'Share', _shareEvent),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? U.primary.withValues(alpha: 0.1) : U.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlight ? U.primary.withValues(alpha: 0.3) : U.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: highlight ? U.primary : U.text),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: highlight ? U.primary : U.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.calendar_month_rounded,
            '${_formatDate(_event.date)} • ${_event.startTime}${_event.endTime.isNotEmpty ? ' - ${_event.endTime}' : ''}',
            'Add to calendar',
          ),
          _buildDivider(),
          _buildInfoRow(Icons.location_on_rounded, _event.venue, 'View on map'),
          _buildDivider(),
          _buildInfoRow(
            Icons.groups_rounded,
            '${_event.participantCount} registered${_event.participantLimit > 0 ? ' / ${_event.participantLimit} max' : ''}',
            _event.isFull ? 'Event is full' : 'View participants',
          ),
          if (_event.contactNumbers.isNotEmpty) ...[
            _buildDivider(),
            _buildInfoRow(Icons.phone_rounded, _event.contactNumbers, 'Contact organizer'),
          ],
          if (_event.registrationDeadline != null) ...[
            _buildDivider(),
            _buildInfoRow(
              Icons.event_busy_rounded,
              'Deadline: ${_formatDate(_event.registrationDeadline!)}',
              _event.isRegistrationClosed ? 'Registration closed' : 'Register before this date',
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: U.border, height: 1),
    );
  }

  Widget _buildInfoRow(IconData icon, String primary, String secondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: U.bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: U.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(primary, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: U.text)),
              Text(secondary, style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrizeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.gold.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded, color: U.gold, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prize', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: U.text)),
                Text(_event.prizeInfo!, style: GoogleFonts.outfit(fontSize: 14, color: U.sub)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildRequirementsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: U.primary, size: 20),
              const SizedBox(width: 8),
              Text('Requirements', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_event.requirements!, style: GoogleFonts.outfit(fontSize: 14, color: U.sub, height: 1.5)),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About Event', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text)),
        const SizedBox(height: 12),
        Text(
          _event.fullDescription.isNotEmpty
              ? _event.fullDescription
              : _event.shortDescription.isNotEmpty
                  ? _event.shortDescription
                  : 'No description provided.',
          style: GoogleFonts.outfit(fontSize: 15, color: U.sub, height: 1.6),
        ),
        // Flags row
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_event.providesAttendance) _buildBadge('📋 Attendance', U.teal),
            if (_event.requiresPayment) _buildBadge('💰 Paid Entry', U.peach),
            if (_event.providesCertificate) _buildBadge('🏅 Certificate', U.primary),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _event.tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: U.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: U.border),
        ),
        child: Text('#$tag', style: GoogleFonts.outfit(fontSize: 12, color: U.sub, fontWeight: FontWeight.w500)),
      )).toList(),
    ).animate().fadeIn(delay: 450.ms);
  }

  Widget _buildLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Links', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: U.text)),
        const SizedBox(height: 8),
        if (_event.whatsappLink != null && _event.whatsappLink!.isNotEmpty)
          _buildLinkTile(Icons.chat_rounded, 'WhatsApp Group', _event.whatsappLink!, U.teal),
        if (_event.participationLink != null && _event.participationLink!.isNotEmpty)
          _buildLinkTile(Icons.open_in_new_rounded, 'Participation Link', _event.participationLink!, U.primary),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildLinkTile(IconData icon, String label, String url, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: U.text)),
                Text(url, style: GoogleFonts.outfit(fontSize: 12, color: U.sub), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: U.dim),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final canRegister = !_event.isRegistrationClosed && !_event.isFull && _event.status != EventStatus.completed && _event.status != EventStatus.cancelled;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
        decoration: BoxDecoration(
          color: U.surface.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: U.border)),
        ),
        child: ElevatedButton(
          onPressed: (_isRegistering || !canRegister) ? null : _toggleRegistration,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRegistered ? U.red : U.primary,
            foregroundColor: U.bg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            disabledBackgroundColor: U.dim.withValues(alpha: 0.3),
          ),
          child: _isRegistering
              ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: U.bg, strokeWidth: 2))
              : Text(
                  _isRegistered
                      ? 'Cancel Registration'
                      : !canRegister
                          ? (_event.isFull ? 'Event Full' : 'Registration Closed')
                          : 'Register Now',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ).animate().slideY(begin: 1, end: 0, delay: 500.ms, duration: 400.ms, curve: Curves.easeOutCubic),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
