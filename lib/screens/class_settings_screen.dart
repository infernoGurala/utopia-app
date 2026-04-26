import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';

class ClassSettingsScreen extends StatefulWidget {
  final ClassModel classModel;
  final String userRole;
  const ClassSettingsScreen({super.key, required this.classModel, required this.userRole});

  @override
  State<ClassSettingsScreen> createState() => _ClassSettingsScreenState();
}

class _ClassSettingsScreenState extends State<ClassSettingsScreen> {
  final ClassService _classService = ClassService();
  List<Map<String, dynamic>> _members = [];
  bool _loadingMembers = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await _classService.getMembers(widget.classModel.classId);
      // Ensure the owner is at the top
      members.sort((a, b) {
        if (a['uid'] == widget.classModel.creatorUid) return -1;
        if (b['uid'] == widget.classModel.creatorUid) return 1;
        return (a['displayName'] ?? '').compareTo(b['displayName'] ?? '');
      });
      if (mounted) {
        setState(() {
          _members = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  void _shareJoinLink() {
    final link = 'https://classes.inferalis.space/join/${widget.classModel.classCode}';
    Share.share('Join my class "${widget.classModel.name}" on Utopia: $link\nClass Code: ${widget.classModel.classCode}');
  }

  Future<void> _addWriter() async {
    if (widget.userRole != 'writer') return;
    final emailController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Add Writer', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the user\'s email to promote them to writer.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: GoogleFonts.outfit(color: U.text),
              decoration: InputDecoration(
                hintText: 'user@email.com',
                hintStyle: GoogleFonts.outfit(color: U.sub),
                filled: true,
                fillColor: U.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: U.primary),
            child: Text('Add', style: GoogleFonts.outfit(color: U.bg)),
          ),
        ],
      ),
    );

    if (result == true) {
      final email = emailController.text.trim();
      if (email.isEmpty) return;

      try {
        await _classService.addWriterByEmail(widget.classModel.classId, email);
        _loadMembers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Writer added successfully'), backgroundColor: U.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: U.red));
        }
      }
    }
  }

  Future<void> _removeWriter(String uid, String name) async {
    if (widget.userRole != 'writer') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Remove Writer', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to demote $name to reader?', style: GoogleFonts.outfit(color: U.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: GoogleFonts.outfit(color: U.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _classService.removeWriter(widget.classModel.classId, uid);
        _loadMembers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: U.red));
        }
      }
    }
  }

  Future<void> _deleteClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text('Delete Class', style: GoogleFonts.outfit(color: U.red, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete the class record. This action cannot be undone.',
              style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Students will no longer be able to access the class or its notes.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: U.red),
            child: Text('Delete Permanently', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await _classService.deleteClass(widget.classModel.classId);
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Class deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e'), backgroundColor: U.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
        backgroundColor: U.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: U.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildMembersSection(),
          const SizedBox(height: 32),
          _buildTimetablePlaceholder(),
          if (widget.userRole == 'writer') ...[
            const SizedBox(height: 48),
            _buildDangerZone(),
          ]
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: U.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: U.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(widget.classModel.name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: U.text)),
          const SizedBox(height: 8),
          Text('CLASS CODE', style: GoogleFonts.outfit(color: U.sub, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            widget.classModel.classCode,
            style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: U.primary, letterSpacing: 8),
          ),
          const SizedBox(height: 8),
          Text(
            'SHARE THIS CODE WITH STUDENTS',
            style: GoogleFonts.outfit(color: U.dim, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _shareJoinLink,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: Text('Share Join Link', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: U.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    final bool canEdit = widget.userRole == 'writer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MEMBERS', style: GoogleFonts.outfit(color: U.sub, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            Text('${_members.length}', style: GoogleFonts.outfit(color: U.dim, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: U.border.withValues(alpha: 0.5)),
          ),
          child: _loadingMembers
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(
                  children: [
                    ..._members.map((w) {
                      final isCreator = w['uid'] == widget.classModel.creatorUid;
                      final isWriter = widget.classModel.writerUids.contains(w['uid']);
                      final isSelf = FirebaseAuth.instance.currentUser?.uid == w['uid'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isWriter
                              ? U.primary.withValues(alpha: 0.12)
                              : U.dim.withValues(alpha: 0.1),
                          child: Text(
                            (w['displayName'] as String).isNotEmpty
                                ? w['displayName'][0].toUpperCase()
                                : '?',
                            style: GoogleFonts.outfit(
                              color: isWriter ? U.primary : U.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          w['displayName'] + (isSelf ? ' (You)' : ''),
                          style: GoogleFonts.outfit(
                            color: U.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          w['email'],
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Writer badge (always show if writer, regardless of owner)
                            if (isWriter)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: U.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Writer',
                                  style: GoogleFonts.outfit(
                                    color: U.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            // Owner badge
                            if (isCreator)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: U.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Owner',
                                  style: GoogleFonts.outfit(
                                    color: U.teal,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            // Remove writer button — only for non-owner writers when canEdit
                            if (!isCreator && isWriter && canEdit)
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: U.red.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                                onPressed: () => _removeWriter(w['uid'], w['displayName']),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (canEdit && widget.classModel.writerUids.length < 6)
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: U.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.add, color: U.primary, size: 20),
                        ),
                        title: Text('Add Writer', style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600, fontSize: 15)),
                        onTap: _addWriter,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTimetablePlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TIMETABLE', style: GoogleFonts.outfit(color: U.sub, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: U.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: U.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Icon(Icons.calendar_today_rounded, color: U.dim, size: 32),
              const SizedBox(height: 12),
              Text('Coming soon', style: GoogleFonts.outfit(color: U.sub, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Sync class workflows with your local timetable.', style: GoogleFonts.outfit(color: U.dim, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DANGER ZONE', style: GoogleFonts.outfit(color: U.red, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isDeleting ? null : _deleteClass,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: U.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: U.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_forever_rounded, color: U.red),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delete Class', style: GoogleFonts.outfit(color: U.red, fontWeight: FontWeight.w600)),
                      Text('Permanently remove this class and its notes.', style: GoogleFonts.outfit(color: U.red.withValues(alpha: 0.7), fontSize: 12)),
                    ],
                  ),
                ),
                if (_isDeleting) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
