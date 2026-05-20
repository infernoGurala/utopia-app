import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../widgets/utopia_snackbar.dart';
import '../widgets/aditya_logo_circle.dart';

const _kGold = Color(0xFFF59E0B);
const _kTeal = Color(0xFF0D9488);
const _kPurple = Color(0xFF7C3AED);
const _kIndigo = Color(0xFF6366F1);

class CertificatePreviewScreen extends StatefulWidget {
  final EventCertificate cert;
  final String participantName;
  final bool isOrganizer;

  const CertificatePreviewScreen({
    super.key,
    required this.cert,
    required this.participantName,
    this.isOrganizer = false,
  });

  @override
  State<CertificatePreviewScreen> createState() =>
      _CertificatePreviewScreenState();
}

class _CertificatePreviewScreenState extends State<CertificatePreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _shimmer = _shimmerCtrl.drive(CurveTween(curve: Curves.linear));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String get _certId {
    final id = widget.cert.id;
    if (id == null) return 'CERT-0000';
    return 'CERT-${id.substring(0, 8).toUpperCase()}';
  }

  String get _displayName {
    final name = widget.participantName.isNotEmpty
        ? widget.participantName
        : widget.cert.userId.substring(0, 8);
    return name.toUpperCase();
  }

  String get _verifyUrl => 'https://events.inferalis.space/verify/$_certId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Ambient glow background
        Positioned.fill(
          child: CustomPaint(painter: _AmbientPainter()),
        ),
        SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(children: [
                  _buildCertificateCard(),
                  const SizedBox(height: 24),
                  _buildMetaRow(),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            'Certificate Preview',
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _buildCertificateCard() {
    final issueDate = widget.cert.issuedAt != null
        ? _formatDate(widget.cert.issuedAt!)
        : 'May 20, 2026';

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _kGold.withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.15),
                blurRadius: 60,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              // Certificate background
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1035), Color(0xFF0F0824)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Shimmer sweep
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(-2 + _shimmer.value * 4, 0),
                      end: Alignment(-1 + _shimmer.value * 4, 0),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ).createShader(bounds);
                  },
                  child: Container(color: Colors.white),
                ),
              ),
              // Border gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: _kGold.withValues(alpha: 0.35), width: 1.5),
                  ),
                ),
              ),
              // Inner gold corner decorations
              Positioned(
                  top: 12, left: 12,
                  child: _CornerDecor(color: _kGold)),
              Positioned(
                  top: 12, right: 12,
                  child: Transform.rotate(
                      angle: math.pi / 2, child: _CornerDecor(color: _kGold))),
              Positioned(
                  bottom: 12, left: 12,
                  child: Transform.rotate(
                      angle: -math.pi / 2,
                      child: _CornerDecor(color: _kGold))),
              Positioned(
                  bottom: 12, right: 12,
                  child: Transform.rotate(
                      angle: math.pi, child: _CornerDecor(color: _kGold))),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo / icon
                    widget.cert.isAditya
                        ? const AdityaLogoCircle(size: 52)
                        : Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [_kGold, _kGold.withValues(alpha: 0.7)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: _kGold.withValues(alpha: 0.4),
                                    blurRadius: 16)
                              ],
                            ),
                            child: const Center(
                                child: Icon(Icons.workspace_premium_rounded,
                                    color: Colors.white, size: 26)),
                          ),
                    const SizedBox(height: 16),
                    // University name
                    Text(
                      'ADITYA UNIVERSITY',
                      style: GoogleFonts.outfit(
                          color: _kGold.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                        width: 80, height: 1,
                        color: _kGold.withValues(alpha: 0.3)),
                    const SizedBox(height: 20),
                    Text(
                      'CERTIFICATE OF PARTICIPATION',
                      style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This is to certify that',
                      style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    // Name
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [_kGold, Color(0xFFFFE9A0), _kGold],
                      ).createShader(b),
                      child: Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            height: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Ticket / Roll
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _kGold.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _certId,
                        style: GoogleFonts.outfit(
                            color: _kGold,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'has successfully participated in',
                      style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.cert.eventTitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          height: 1.3),
                    ),
                    const SizedBox(height: 28),
                    // Divider
                    Row(children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.star_rounded,
                            color: _kGold.withValues(alpha: 0.4), size: 14),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.12))),
                    ]),
                    const SizedBox(height: 20),
                    // Footer: issuer + date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.cert.issuerName.toUpperCase(),
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Event Organizer',
                                style: GoogleFonts.outfit(
                                    color:
                                        Colors.white.withValues(alpha: 0.45),
                                    fontSize: 9),
                              ),
                            ]),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                issueDate,
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Issue Date',
                                style: GoogleFonts.outfit(
                                    color:
                                        Colors.white.withValues(alpha: 0.45),
                                    fontSize: 9),
                              ),
                            ]),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        curve: Curves.easeOutCubic);
  }

  Widget _buildMetaRow() {
    return Row(children: [
      _metaChip(Icons.verified_rounded, 'Verified', _kTeal),
      const SizedBox(width: 10),
      _metaChip(Icons.calendar_today_rounded,
          widget.cert.issuedAt != null
              ? '${widget.cert.issuedAt!.day}/${widget.cert.issuedAt!.month}/${widget.cert.issuedAt!.year}'
              : '—',
          _kIndigo),
      const SizedBox(width: 10),
      _metaChip(Icons.tag_rounded, _certId, _kGold),
    ]).animate().fadeIn(delay: 200.ms);
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }


}

// ── Corner decoration ──
class _CornerDecor extends StatelessWidget {
  final Color color;
  const _CornerDecor({required this.color});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _CornerPainter(color: color)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

// ── Ambient dark background ──
class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0A0712));

    void orb(Offset c, double r, Color col, double sigma) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = col.withValues(alpha: 0.18)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
    }

    orb(Offset(size.width * 0.85, size.height * 0.08), 120, _kPurple, 70);
    orb(Offset(size.width * 0.1, size.height * 0.55), 100, _kGold, 60);
    orb(Offset(size.width * 0.9, size.height * 0.75), 80, _kTeal, 50);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter _) => false;
}


