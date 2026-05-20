import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/utopia_loader.dart';
import 'certificate_preview_screen.dart';

const _kGold = Color(0xFFF59E0B);
const _kTeal = Color(0xFF0D9488);
const _kPurple = Color(0xFF7C3AED);
const _kIndigo = Color(0xFF6366F1);

class EventCertificatesScreen extends StatefulWidget {
  const EventCertificatesScreen({super.key});

  @override
  State<EventCertificatesScreen> createState() =>
      _EventCertificatesScreenState();
}

class _EventCertificatesScreenState extends State<EventCertificatesScreen> {
  List<EventCertificate> _certificates = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() => _isLoading = true);
    try {
      final certs = await EventService.instance.getMyCertificates();
      if (mounted) {
        setState(() {
          _certificates = certs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EventCertificate> get _filtered {
    if (_search.isEmpty) return _certificates;
    final q = _search.toLowerCase();
    return _certificates
        .where((c) =>
            c.eventTitle.toLowerCase().contains(q) ||
            c.issuerName.toLowerCase().contains(q))
        .toList();
  }

  String _formatDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: U.bg,
      body: Column(children: [
        _buildHeader(user),
        if (!_isLoading && _certificates.isNotEmpty) _buildSearchBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: UtopiaLoader(scale: 0.7))
              : _certificates.isEmpty
                  ? _buildEmptyState()
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No results',
                              style:
                                  GoogleFonts.outfit(color: U.sub, fontSize: 15)),
                        )
                      : RefreshIndicator(
                          color: _kPurple,
                          onRefresh: _loadCertificates,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) =>
                                _buildCertCard(_filtered[index], index),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _buildHeader(User? user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A0F35),
            const Color(0xFF0F0824),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
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
                            'My Certificates',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5),
                          ),
                          Text(
                            'Your earned achievements',
                            style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12),
                          ),
                        ]),
                  ),
                  // Count badge
                  if (_certificates.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _kGold.withValues(alpha: 0.35)),
                      ),
                      child: Row(children: [
                        Icon(Icons.workspace_premium_rounded,
                            color: _kGold, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          '${_certificates.length}',
                          style: GoogleFonts.outfit(
                              color: _kGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ),
                ]),
              ]),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: U.border)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Icon(Icons.search_rounded, color: U.dim, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: GoogleFonts.outfit(color: U.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search certificates...',
                hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCertCard(EventCertificate cert, int index) {
    final accents = [_kGold, _kTeal, _kPurple, _kIndigo];
    final accent = accents[index % accents.length];
    final certId = cert.id != null
        ? 'CERT-${cert.id!.substring(0, 8).toUpperCase()}'
        : 'CERT-0000';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CertificatePreviewScreen(
                cert: cert,
                participantName:
                    FirebaseAuth.instance.currentUser?.displayName ?? '',
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.08)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Center(
                    child: Icon(Icons.workspace_premium_rounded,
                        color: accent, size: 26)),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cert.eventTitle,
                        style: GoogleFonts.outfit(
                            color: U.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cert.issuerName,
                        style: GoogleFonts.outfit(
                            color: U.sub, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            certId,
                            style: GoogleFonts.outfit(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (cert.issuedAt != null)
                          Text(
                            _formatDate(cert.issuedAt!),
                            style: GoogleFonts.outfit(
                                color: U.dim, fontSize: 11),
                          ),
                      ]),
                    ]),
              ),
              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    color: U.dim.withValues(alpha: 0.5), size: 12),
              ),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 80).ms).slideY(
        begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kGold.withValues(alpha: 0.08),
              border: Border.all(color: _kGold.withValues(alpha: 0.15))),
          child: const Center(
              child: Icon(Icons.workspace_premium_outlined,
                  size: 40, color: _kGold)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05),
              duration: 2000.ms, curve: Curves.easeInOut),
        const SizedBox(height: 20),
        Text('No certificates yet',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w600, color: U.text)),
        const SizedBox(height: 6),
        Text('Attend events and earn your first certificate!',
            style: GoogleFonts.outfit(fontSize: 13, color: U.sub)),
      ]),
    );
  }
}
