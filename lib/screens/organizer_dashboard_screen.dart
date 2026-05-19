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
import '../widgets/utopia_snackbar.dart';

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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [U.primary, U.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: U.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white30, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: U.surface,
              backgroundImage: user?.photoURL != null ? CachedNetworkImageProvider(user!.photoURL!) : null,
              child: user?.photoURL == null ? Icon(Icons.business_center_rounded, color: U.primary, size: 36) : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Organizer',
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_myEvents.length} Events  •  ${_analytics['total_registrations'] ?? 0} Registrations',
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border),
        boxShadow: [
          BoxShadow(color: U.primary.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 8)),
        ],
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildEventStat('Registrations', '${event.participantCount}${event.participantLimit > 0 ? '/${event.participantLimit}' : ''}', Icons.how_to_reg_rounded, U.primary),
              _buildEventStat('Views', '${event.viewCount}', Icons.visibility_rounded, U.teal),
              _buildEventStat('Shares', '${event.shareCount}', Icons.share_rounded, U.blue),
              _buildEventStat('Engagement', '${event.participantCount > 0 ? ((event.participantCount / (event.participantLimit > 0 ? event.participantLimit : 100)) * 100).round().clamp(0, 100) : 0}%', Icons.auto_graph_rounded, U.peach),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildIconBtn(Icons.edit_rounded, 'Edit Event', () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEventScreen(existingEvent: event)));
                _loadData();
              }),
              _buildIconBtn(Icons.people_outline_rounded, 'Participants', () async {
                if (event.id == null) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: UtopiaLoader(scale: 0.7)),
                );
                try {
                  final regs = await EventService.instance.getRegistrations(event.id!);
                  final certs = await EventService.instance.getEventCertificates(event.id!);
                  if (mounted) {
                    Navigator.pop(context); // Dismiss loader
                    _showParticipantsDialog(event, regs, certs);
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Dismiss loader
                    showUtopiaSnackBar(
                      context,
                      message: 'Error loading participants: $e',
                      tone: UtopiaSnackBarTone.error,
                    );
                  }
                }
              }),
              _buildIconBtn(Icons.delete_outline_rounded, 'Delete', () => _confirmDelete(event), iconColor: U.red),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(EventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Delete Event', style: GoogleFonts.outfit(color: U.text)),
        content: Text('Are you sure you want to delete "${event.title}"? This cannot be undone.', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text('Delete', style: GoogleFonts.outfit(color: U.red))),
        ],
      ),
    );

    if (confirm == true && event.id != null) {
      try {
        await EventService.instance.deleteEvent(event.id!);
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildIconBtn(IconData icon, String tooltip, VoidCallback? onPressed, {Color? iconColor}) {
    final color = iconColor ?? U.primary;
    return Container(
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildEventStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 11, color: U.sub), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: U.text)),
        ],
      ),
    );
  }

  void _showParticipantsDialog(
    EventModel event,
    List<EventRegistration> regs,
    List<EventCertificate> initialCerts,
  ) {
    final certs = List<EventCertificate>.from(initialCerts);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: U.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${event.title} — Participants',
                    style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                if (regs.any((r) => !certs.any((c) => c.userId == r.userId)))
                  TextButton.icon(
                    onPressed: () => _awardAllConfirm(context, event, regs, certs, setState),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: U.primary,
                    ),
                    icon: Icon(Icons.select_all_rounded, size: 16),
                    label: Text(
                      'Select All',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 350,
              child: regs.isEmpty
                  ? Center(child: Text('No registrations yet', style: GoogleFonts.outfit(color: U.sub)))
                  : ListView.builder(
                      itemCount: regs.length,
                      itemBuilder: (context, index) {
                        final r = regs[index];
                        final isIssued = certs.any((c) => c.userId == r.userId);
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: U.primary.withValues(alpha: 0.1),
                            child: Text(
                              r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?',
                              style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          title: Text(
                            r.userName,
                            style: GoogleFonts.outfit(color: U.text, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Row(
                            children: [
                              Text(r.ticketId ?? '', style: GoogleFonts.outfit(color: U.dim, fontSize: 11)),
                              const SizedBox(width: 6),
                              if (r.checkedIn)
                                Icon(Icons.check_circle_rounded, color: U.teal, size: 14)
                              else
                                Icon(Icons.circle_outlined, color: U.dim, size: 14),
                            ],
                          ),
                          trailing: isIssued
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: U.teal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: U.teal.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_user_rounded, color: U.teal, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Issued',
                                        style: GoogleFonts.outfit(color: U.teal, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: () => _awardCertificatePrompt(context, event, r, (newCert) {
                                    setState(() {
                                      certs.add(newCert);
                                    });
                                  }),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: U.primary.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    foregroundColor: U.primary,
                                  ),
                                  icon: Icon(Icons.workspace_premium_rounded, size: 14),
                                  label: Text(
                                    'Award',
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
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
          );
        },
      ),
    );
  }

  void _awardAllConfirm(
    BuildContext dialogContext,
    EventModel event,
    List<EventRegistration> regs,
    List<EventCertificate> certs,
    StateSetter setDialogState,
  ) {
    showDialog(
      context: dialogContext,
      builder: (context) => AlertDialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Award All Certificates', style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text(
          'This will award certificates to all remaining participants. Continue?',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm dialog
              
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (context) => const Center(child: UtopiaLoader(scale: 0.7)),
              );

              try {
                final unawarded = regs.where((r) => !certs.any((c) => c.userId == r.userId)).toList();
                if (unawarded.isNotEmpty) {
                  final futures = unawarded.map((r) => EventService.instance.issueCertificate(
                    eventId: event.id!,
                    eventTitle: event.title,
                    userId: r.userId,
                    issuerName: event.organizerName.isNotEmpty ? event.organizerName : 'Utopia Organizer',
                    certificateUrl: 'https://utopia-app.web.app/certificates/default.pdf',
                  ));
                  await Future.wait(futures);

                  final updatedCerts = await EventService.instance.getEventCertificates(event.id!);
                  setDialogState(() {
                    certs.clear();
                    certs.addAll(updatedCerts);
                  });
                }
                
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Dismiss loader
                  showUtopiaSnackBar(
                    dialogContext,
                    message: 'Successfully awarded certificates to all participants!',
                    tone: UtopiaSnackBarTone.success,
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Dismiss loader
                  showUtopiaSnackBar(
                    dialogContext,
                    message: 'Failed to award certificates: $e',
                    tone: UtopiaSnackBarTone.error,
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: U.primary,
              foregroundColor: U.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Award All', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _awardCertificatePrompt(
    BuildContext dialogContext,
    EventModel event,
    EventRegistration registration,
    Function(EventCertificate) onIssued,
  ) {
    final urlController = TextEditingController();
    bool issuing = false;

    showDialog(
      context: dialogContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setPromptState) {
          return AlertDialog(
            backgroundColor: U.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Award Certificate',
              style: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Issue a certificate of participation to ${registration.userName}.',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlController,
                  enabled: !issuing,
                  style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Certificate URL (Optional)',
                    hintText: 'e.g. https://drive.google.com/...',
                    labelStyle: GoogleFonts.outfit(color: U.text, fontSize: 12),
                    hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 12),
                    filled: true,
                    fillColor: U.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.primary, width: 1.2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: issuing ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
              ),
              FilledButton(
                onPressed: issuing
                    ? null
                    : () async {
                        setPromptState(() => issuing = true);
                        try {
                          final certUrl = urlController.text.trim().isNotEmpty
                              ? urlController.text.trim()
                              : 'https://utopia-app.web.app/certificates/default.pdf';
                          
                          final success = await EventService.instance.issueCertificate(
                            eventId: event.id!,
                            eventTitle: event.title,
                            userId: registration.userId,
                            issuerName: event.organizerName.isNotEmpty ? event.organizerName : 'Utopia Organizer',
                            certificateUrl: certUrl,
                          );

                          if (success) {
                            final newCert = EventCertificate(
                              eventId: event.id!,
                              eventTitle: event.title,
                              userId: registration.userId,
                              issuerName: event.organizerName.isNotEmpty ? event.organizerName : 'Utopia Organizer',
                              certificateUrl: certUrl,
                              issuedAt: DateTime.now(),
                            );
                            onIssued(newCert);
                            if (context.mounted) {
                              Navigator.pop(context); // Close award prompt
                              showUtopiaSnackBar(
                                dialogContext,
                                message: 'Certificate awarded to ${registration.userName} successfully!',
                                tone: UtopiaSnackBarTone.success,
                              );
                            }
                          } else {
                            throw Exception('Database insertion returned false');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setPromptState(() => issuing = false);
                            showUtopiaSnackBar(
                              context,
                              message: 'Failed to issue certificate: $e',
                              tone: UtopiaSnackBarTone.error,
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: U.primary,
                  foregroundColor: U.bg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: issuing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Award', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
