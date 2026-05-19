import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../widgets/utopia_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import 'create_event_screen.dart';
import '../widgets/utopia_snackbar.dart';
import '../widgets/gradient_dot_button.dart';

class OrganizerDashboardScreen extends StatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  State<OrganizerDashboardScreen> createState() => _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState extends State<OrganizerDashboardScreen> {
  List<EventModel> _myEvents = [];
  Map<String, dynamic> _analytics = {};
  bool _isLoading = true;
  String? _userRollNumber;
  String? _userDisplayName;

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
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);

      final events = results[0] as List<EventModel>;
      final analytics = results[1] as Map<String, dynamic>;
      final userDoc = results[2] as DocumentSnapshot;

      final data = userDoc.data() as Map<String, dynamic>?;
      final rollNumber = data?['rollNumber'] as String? ?? '';
      final name = data?['displayName'] as String? ?? FirebaseAuth.instance.currentUser?.displayName ?? '';

      if (mounted) {
        setState(() {
          _myEvents = events;
          _analytics = analytics;
          _userRollNumber = rollNumber;
          _userDisplayName = name;
          _isLoading = false;
        });

        if (rollNumber.isEmpty || name.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNameAndRollNumberDialog(uid, name, rollNumber);
          });
        }
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
                          GradientDotButton(
                            onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
                              _loadData();
                            },
                            icon: Icons.add_rounded,
                            label: 'Create New',
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
    final eventCount = _myEvents.length;
    final regCount = _analytics['total_registrations'] as int? ?? 0;

    return ProfileHeaderBackground(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 520;
            
            final avatarWidget = Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFF472B6), Color(0xFFA78BFA), Color(0xFF22D3EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: U.surface,
                    backgroundImage: user?.photoURL != null ? CachedNetworkImageProvider(user!.photoURL!) : null,
                    child: user?.photoURL == null ? Icon(Icons.business_center_rounded, color: U.primary, size: 36) : null,
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            );

            final nameAndRollColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (_userDisplayName != null && _userDisplayName!.isNotEmpty)
                      ? _userDisplayName!
                      : (user?.displayName ?? 'Organizer'),
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (_userRollNumber != null && _userRollNumber!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Roll No: $_userRollNumber',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            );

            final statsCapsule = Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCapsuleItem(
                    icon: Icons.calendar_month_rounded,
                    value: '$eventCount',
                    label: 'Events',
                    iconBgColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      height: 18,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  _buildCapsuleItem(
                    icon: Icons.local_activity_rounded,
                    value: '$regCount',
                    label: 'Registrations',
                    iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                  ),
                ],
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  avatarWidget,
                  const SizedBox(width: 20),
                  Expanded(child: nameAndRollColumn),
                  const SizedBox(width: 16),
                  statsCapsule,
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      avatarWidget,
                      const SizedBox(width: 18),
                      Expanded(child: nameAndRollColumn),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(child: statsCapsule),
                ],
              );
            }
          },
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildCapsuleItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconBgColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showNameAndRollNumberDialog(String uid, String currentName, String currentRoll) {
    final nameController = TextEditingController(text: currentName);
    final rollController = TextEditingController(text: currentRoll);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: U.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Complete Profile',
            style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700, fontSize: 20),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please enter your name and roll number to continue.',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.outfit(color: U.text),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: GoogleFonts.outfit(color: U.sub),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.primary),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: rollController,
                  style: GoogleFonts.outfit(color: U.text),
                  decoration: InputDecoration(
                    labelText: 'Roll Number',
                    labelStyle: GoogleFonts.outfit(color: U.sub),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: U.primary),
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Roll number is required' : null,
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newName = nameController.text.trim();
                  final newRoll = rollController.text.trim();
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                      'displayName': newName,
                      'rollNumber': newRoll,
                    }, SetOptions(merge: true));

                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      try {
                        await user.updateDisplayName(newName);
                        await user.reload();
                      } catch (_) {}
                    }

                    if (mounted) {
                      setState(() {
                        _userDisplayName = newName;
                        _userRollNumber = newRoll;
                      });
                      Navigator.pop(dialogContext);
                      showUtopiaSnackBar(
                        context,
                        message: 'Profile updated successfully!',
                        tone: UtopiaSnackBarTone.success,
                      );
                    }
                  } catch (e) {
                    showUtopiaSnackBar(
                      context,
                      message: 'Failed to update profile: $e',
                      tone: UtopiaSnackBarTone.error,
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                foregroundColor: U.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
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

class ProfileHeaderBackground extends StatefulWidget {
  final Widget child;
  const ProfileHeaderBackground({super.key, required this.child});

  @override
  State<ProfileHeaderBackground> createState() => _ProfileHeaderBackgroundState();
}

class _ProfileHeaderBackgroundState extends State<ProfileHeaderBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MeshPainter(_controller.value),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;
  _MeshPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    // Draw background waves/paths
    final path1 = Path();
    path1.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.7 +
          math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) * 14;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.close();
    canvas.drawPath(path1, paint);

    // Subtle overlay wavy lines (mesh stroke)
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final path2 = Path();
    path2.moveTo(0, size.height * 0.4);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.4 +
          math.cos((x / size.width * 1.5 * math.pi) - (progress * 2 * math.pi)) * 20;
      path2.lineTo(x, y);
    }
    canvas.drawPath(path2, strokePaint);

    // Floating blurred blobs to match mockup
    final paintBlob = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    final center1 = Offset(
      size.width * 0.2 + math.sin(progress * 2 * math.pi) * 30,
      size.height * 0.3 + math.cos(progress * 2 * math.pi) * 15,
    );
    canvas.drawCircle(center1, 50, paintBlob);

    final center2 = Offset(
      size.width * 0.8 + math.cos(progress * 2 * math.pi) * 20,
      size.height * 0.4 + math.sin(progress * 2 * math.pi) * 20,
    );
    canvas.drawCircle(center2, 60, paintBlob);

    // Draw dots pattern grids on left and right sides
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    const spacing = 12.0;
    const dotRadius = 1.0;

    // Left dot matrix
    for (double x = spacing / 2; x < 65.0; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }

    // Right dot matrix
    for (double x = size.width - 65.0 + spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
