import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/utopia_loader.dart';
import '../widgets/utopia_snackbar.dart';
import 'certificate_preview_screen.dart';

// ── Palette ──
const _kGold = Color(0xFFF59E0B);
const _kTeal = Color(0xFF0D9488);
const _kPurple = Color(0xFF7C3AED);
const _kRed = Color(0xFFEF4444);

class OrganizerCertificateDashboard extends StatefulWidget {
  final EventModel event;
  const OrganizerCertificateDashboard({super.key, required this.event});

  @override
  State<OrganizerCertificateDashboard> createState() =>
      _OrganizerCertificateDashboardState();
}

class _OrganizerCertificateDashboardState
    extends State<OrganizerCertificateDashboard>
    with SingleTickerProviderStateMixin {
  List<EventRegistration> _registrations = [];
  List<EventCertificate> _certificates = [];
  bool _isLoading = true;
  bool _isAwarding = false;

  final Set<String> _selected = {};
  String _searchQuery = '';
  bool _onlyAttended = false;

  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final regs = await EventService.instance.getRegistrations(widget.event.id!);
      final certs = await EventService.instance.getEventCertificates(widget.event.id!);
      if (mounted) {
        setState(() {
          _registrations = regs;
          _certificates = certs;
          _isLoading = false;
          _selected.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _hasCertificate(String userId) =>
      _certificates.any((c) => c.userId == userId);

  List<EventRegistration> get _filtered {
    var list = _registrations;
    if (_onlyAttended) list = list.where((r) => r.checkedIn).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((r) =>
              r.userName.toLowerCase().contains(q) ||
              (r.ticketId ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  List<EventRegistration> get _pending =>
      _filtered.where((r) => !_hasCertificate(r.userId)).toList();
  List<EventRegistration> get _awarded =>
      _filtered.where((r) => _hasCertificate(r.userId)).toList();

  void _toggleAll() {
    final pendingIds = _pending.map((r) => r.userId).toSet();
    if (pendingIds.every(_selected.contains)) {
      setState(() => _selected.removeAll(pendingIds));
    } else {
      setState(() => _selected.addAll(pendingIds));
    }
  }

  Future<void> _awardSelected() async {
    if (_selected.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final toAward =
        _registrations.where((r) => _selected.contains(r.userId)).toList();

    final confirmed = await _showConfirmDialog(toAward.length);
    if (!confirmed) return;

    setState(() => _isAwarding = true);
    try {
      final futures = toAward.map((r) => EventService.instance.issueCertificate(
            eventId: widget.event.id!,
            eventTitle: widget.event.title,
            userId: r.userId,
            issuerName: widget.event.organizerName.isNotEmpty
                ? widget.event.organizerName
                : 'Utopia Organizer',
          ));
      await Future.wait(futures);
      await _loadData();
      if (mounted) {
        showUtopiaSnackBar(
          context,
          message:
              '🎓 Certificates awarded to ${toAward.length} participant${toAward.length > 1 ? 's' : ''}!',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        showUtopiaSnackBar(context,
            message: 'Failed: $e', tone: UtopiaSnackBarTone.error);
      }
    } finally {
      if (mounted) setState(() => _isAwarding = false);
    }
  }

  Future<bool> _showConfirmDialog(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: U.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              Icon(Icons.workspace_premium_rounded, color: _kGold, size: 22),
              const SizedBox(width: 10),
              Text('Award Certificates',
                  style: GoogleFonts.outfit(
                      color: U.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ]),
            content: Text(
              'Award certificates to $count participant${count > 1 ? 's' : ''}?\n\nThis action cannot be undone.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child:
                      Text('Cancel', style: GoogleFonts.outfit(color: U.dim))),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Award',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      backgroundColor: U.bg,
      body: Column(
        children: [
          // ── Premium Header ──
          _buildHeader(event),
          // ── Tabs ──
          _buildTabBar(),
          // ── Body ──
          Expanded(
            child: _isLoading
                ? const Center(child: UtopiaLoader(scale: 0.7))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _buildParticipantsTab(),
                      _buildAwardedTab(),
                    ],
                  ),
          ),
          // ── Bottom action bar ──
          if (_selected.isNotEmpty) _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(EventModel event) {
    final awarded = _certificates.length;
    final total = _registrations.length;
    final attended = _registrations.where((r) => r.checkedIn).length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPurple.withValues(alpha: 0.9),
            const Color(0xFF4F46E5).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Certificate Dashboard',
                        style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Refresh
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(children: [
                _statChip('Total', '$total', Icons.people_rounded),
                const SizedBox(width: 10),
                _statChip('Attended', '$attended', Icons.how_to_reg_rounded,
                    color: _kTeal),
                const SizedBox(width: 10),
                _statChip('Awarded', '$awarded',
                    Icons.workspace_premium_rounded,
                    color: _kGold),
              ]),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _statChip(String label, String value, IconData icon,
      {Color color = Colors.white}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.outfit(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text(label,
                  style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: U.surface,
      child: TabBar(
        controller: _tabs,
        labelColor: _kPurple,
        unselectedLabelColor: U.sub,
        indicatorColor: _kPurple,
        indicatorWeight: 2.5,
        labelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(text: 'Participants (${_registrations.length})'),
          Tab(text: 'Awarded (${_certificates.length})'),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _pending.isEmpty && _awarded.isEmpty
              ? _buildEmptyState('No participants yet')
              : RefreshIndicator(
                  color: _kPurple,
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (_pending.isNotEmpty) ...[
                        _sectionHeader(
                            'Pending (${_pending.length})', _kGold, () {
                          // select all pending
                          final ids = _pending.map((r) => r.userId).toSet();
                          final allSelected = ids.every(_selected.contains);
                          setState(() {
                            if (allSelected) {
                              _selected.removeAll(ids);
                            } else {
                              _selected.addAll(ids);
                            }
                          });
                        }, selectLabel: 'Select All'),
                        ..._pending.map((r) => _buildParticipantRow(r)),
                      ],
                      if (_awarded.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionHeader(
                            'Already Awarded (${_awarded.length})', _kTeal,
                            null),
                        ..._awarded.map((r) => _buildParticipantRow(r,
                            isAwarded: true)),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: U.bg,
      child: Row(children: [
        // Search
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: U.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: U.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.search_rounded, color: U.dim, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search participants...',
                    hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        // Attended filter
        GestureDetector(
          onTap: () => setState(() => _onlyAttended = !_onlyAttended),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _onlyAttended
                  ? _kTeal.withValues(alpha: 0.15)
                  : U.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _onlyAttended
                      ? _kTeal.withValues(alpha: 0.5)
                      : U.border),
            ),
            child: Row(children: [
              Icon(Icons.how_to_reg_rounded,
                  color: _onlyAttended ? _kTeal : U.dim, size: 16),
              const SizedBox(width: 6),
              Text('Attended',
                  style: GoogleFonts.outfit(
                      color: _onlyAttended ? _kTeal : U.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, Color color, VoidCallback? onAction,
      {String? selectLabel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Container(
            width: 4, height: 16,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: GoogleFonts.outfit(
                  color: U.text, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (onAction != null && selectLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(selectLabel,
                style: GoogleFonts.outfit(
                    color: _kPurple, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _buildParticipantRow(EventRegistration r, {bool isAwarded = false}) {
    final isSelected = _selected.contains(r.userId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? _kPurple.withValues(alpha: 0.06)
            : U.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isSelected
                ? _kPurple.withValues(alpha: 0.3)
                : U.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: isAwarded
            ? Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kTeal.withValues(alpha: 0.12)),
                child: Icon(Icons.verified_rounded, color: _kTeal, size: 20),
              )
            : GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selected.remove(r.userId);
                    } else {
                      _selected.add(r.userId);
                    }
                  });
                },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _kPurple.withValues(alpha: 0.12)
                          : U.bg),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? _kPurple : U.dim,
                    size: 22,
                  ),
                ),
              ),
        title: Text(
          r.userName.isNotEmpty ? r.userName : 'Unknown',
          style: GoogleFonts.outfit(
              color: isAwarded
                  ? U.text.withValues(alpha: 0.6)
                  : U.text,
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
        subtitle: Row(children: [
          Text(
            r.ticketId ?? r.userId.substring(0, 10),
            style: GoogleFonts.outfit(color: U.dim, fontSize: 11),
          ),
          const SizedBox(width: 8),
          if (r.checkedIn)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: _kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5)),
              child: Text('Attended',
                  style: GoogleFonts.outfit(
                      color: _kTeal,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                  color: U.dim.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5)),
              child: Text('Not Attended',
                  style: GoogleFonts.outfit(
                      color: U.dim,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        trailing: isAwarded
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _kTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Issued',
                    style: GoogleFonts.outfit(
                        color: _kTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              )
            : null,
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _buildAwardedTab() {
    if (_certificates.isEmpty) {
      return _buildEmptyState('No certificates issued yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _certificates.length,
      itemBuilder: (context, index) {
        final cert = _certificates[index];
        final reg = _registrations
            .where((r) => r.userId == cert.userId)
            .firstOrNull;
        return _buildAwardedCard(cert, reg, index);
      },
    );
  }

  Widget _buildAwardedCard(
      EventCertificate cert, EventRegistration? reg, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kTeal.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: _kTeal.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _kGold.withValues(alpha: 0.8),
                  _kTeal.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )),
          child:
              const Center(child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reg?.userName ?? cert.userId.substring(0, 8),
                style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                reg?.ticketId ?? cert.id?.substring(0, 12) ?? '—',
                style: GoogleFonts.outfit(color: U.dim, fontSize: 11),
              ),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            cert.issuedAt != null ? _formatDate(cert.issuedAt!) : '—',
            style: GoogleFonts.outfit(color: U.sub, fontSize: 11),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CertificatePreviewScreen(
                          cert: cert,
                          participantName: reg?.userName ?? '',
                          isOrganizer: true,
                        ))),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Preview',
                  style: GoogleFonts.outfit(
                      color: _kPurple,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 60).ms);
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: U.surface,
        border: Border(top: BorderSide(color: U.border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        // Count indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: _kPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPurple.withValues(alpha: 0.2))),
          child: Text(
            '${_selected.length} selected',
            style: GoogleFonts.outfit(
                color: _kPurple, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 10),
        // Clear
        GestureDetector(
          onTap: () => setState(() => _selected.clear()),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: U.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: U.border)),
            child: Text('Clear',
                style: GoogleFonts.outfit(
                    color: U.sub, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ),
        const Spacer(),
        // Award button
        FilledButton.icon(
          onPressed: _isAwarding ? null : _awardSelected,
          style: FilledButton.styleFrom(
            backgroundColor: _kGold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isAwarding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.workspace_premium_rounded, size: 18),
          label: Text(
            _isAwarding
                ? 'Awarding...'
                : 'Award ${_selected.length}',
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ]),
    ).animate().slideY(begin: 1, end: 0, duration: 250.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.workspace_premium_outlined, size: 56, color: U.dim),
        const SizedBox(height: 12),
        Text(msg, style: GoogleFonts.outfit(color: U.sub, fontSize: 16)),
      ]),
    );
  }

  String _formatDate(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}
