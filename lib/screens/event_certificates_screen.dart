import 'package:flutter/material.dart';
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';

class EventCertificatesScreen extends StatefulWidget {
  const EventCertificatesScreen({super.key});

  @override
  State<EventCertificatesScreen> createState() => _EventCertificatesScreenState();
}

class _EventCertificatesScreenState extends State<EventCertificatesScreen> {
  List<EventCertificate> _certificates = [];
  bool _isLoading = true;

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

  @override
  Widget build(BuildContext context) {
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
          'My Certificates',
          style: GoogleFonts.outfit(color: U.text, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: UtopiaLoader(scale: 0.7))
          : _certificates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_outlined, size: 64, color: U.dim),
                      const SizedBox(height: 16),
                      Text('No certificates yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text)),
                      const SizedBox(height: 4),
                      Text('Attend events to earn certificates!', style: GoogleFonts.outfit(fontSize: 14, color: U.sub)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: U.primary,
                  onRefresh: _loadCertificates,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    itemCount: _certificates.length,
                    itemBuilder: (context, index) {
                      return _buildCertificateCard(_certificates[index], index);
                    },
                  ),
                ),
    );
  }

  Widget _buildCertificateCard(EventCertificate cert, int index) {
    final colors = [U.primary, U.teal, U.peach, U.blue, U.gold, U.lavender];
    final accent = colors[index % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: U.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Could open certificate URL if available
            if (cert.certificateUrl != null && cert.certificateUrl!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening certificate...', style: GoogleFonts.outfit())),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Icon(Icons.workspace_premium_rounded, size: 48, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  cert.eventTitle,
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: U.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  cert.issuerName,
                  style: GoogleFonts.outfit(fontSize: 11, color: U.sub),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  cert.issuedAt != null ? _formatDate(cert.issuedAt!) : '',
                  style: GoogleFonts.outfit(fontSize: 10, color: U.dim),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms).scale(begin: const Offset(0.95, 0.95));
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
