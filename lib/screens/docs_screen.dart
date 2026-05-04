import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart';
import '../services/docs_service.dart';
import 'doc_viewer_screen.dart';

class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  String _universityId = '';
  String _userName = '';
  String _uid = '';
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _uid = user.uid;
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        _universityId = userDoc.data()?['selectedUniversityId'] as String? ?? '';
        _userName = userDoc.data()?['displayName'] as String? ??
            user.displayName ??
            'Unknown';
      }
    } catch (_) {}
    if (mounted) setState(() => _isReady = true);
  }

  Future<void> _showAddEditDialog({UniversityDoc? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: U.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: U.border.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: U.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      existing == null ? 'Add Document' : 'Edit Document',
                      style: GoogleFonts.playfairDisplay(
                        color: U.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title field
                    Text(
                      'Title',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: titleCtrl,
                      autofocus: existing == null,
                      style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'e.g. Exam Schedule 2025',
                        hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 15),
                        filled: true,
                        fillColor: U.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 16),

                    // URL field
                    Text(
                      'Link (Google Drive or any URL)',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'https://drive.google.com/...',
                        hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 15),
                        filled: true,
                        fillColor: U.bg,
                        prefixIcon: Icon(Icons.link_rounded, color: U.sub, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: U.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter a URL';
                        final uri = Uri.tryParse(v.trim());
                        if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: U.primary,
                          foregroundColor: U.bg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);
                                try {
                                  if (existing == null) {
                                    await DocsService.instance.addDoc(
                                      title: titleCtrl.text.trim(),
                                      url: urlCtrl.text.trim(),
                                      universityId: _universityId,
                                      createdBy: _uid,
                                      createdByName: _userName,
                                    );
                                  } else {
                                    await DocsService.instance.updateDoc(
                                      docId: existing.id,
                                      title: titleCtrl.text.trim(),
                                      url: urlCtrl.text.trim(),
                                    );
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } catch (_) {
                                  setSheet(() => saving = false);
                                }
                              },
                        child: saving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: U.bg, strokeWidth: 2),
                              )
                            : Text(
                                existing == null ? 'Add Document' : 'Save Changes',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _confirmDelete(UniversityDoc doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: U.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: U.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: U.red, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Document?',
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${doc.title}" will be removed for everyone.',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: U.text,
                        side: BorderSide(color: U.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: U.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await DocsService.instance.deleteDoc(doc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Docs',
                        style: GoogleFonts.playfairDisplay(
                          color: U.text,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                    ),
                    _AddDocButton(onTap: () => _showAddEditDialog()),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'University documents, accessible to everyone',
                  style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
              ),

              // Doc list
              Expanded(
                child: !_isReady
                    ? Center(child: CircularProgressIndicator(color: U.primary, strokeWidth: 2.5))
                    : _universityId.isEmpty
                        ? _EmptyState(message: 'No university found.\nPlease set up your profile.')
                        : StreamBuilder<List<UniversityDoc>>(
                            stream: DocsService.instance.watchDocs(_universityId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                      color: U.primary, strokeWidth: 2.5),
                                );
                              }
                              final docs = snapshot.data ?? [];
                              if (docs.isEmpty) {
                                return _EmptyState(
                                  message:
                                      'No documents yet.\nTap + to add the first one!',
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                                itemCount: docs.length,
                                itemBuilder: (context, i) => _DocCard(
                                  doc: docs[i],
                                  index: i,
                                  isDark: isDark,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DocViewerScreen(
                                        title: docs[i].title,
                                        url: docs[i].url,
                                      ),
                                    ),
                                  ),
                                  onEdit: () => _showAddEditDialog(existing: docs[i]),
                                  onDelete: () => _confirmDelete(docs[i]),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────

class _AddDocButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDocButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: U.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: U.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: U.bg, size: 18),
            const SizedBox(width: 6),
            Text(
              'Add',
              style: GoogleFonts.outfit(
                color: U.bg,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms),
    );
  }
}

class _DocCard extends StatelessWidget {
  final UniversityDoc doc;
  final int index;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DocCard({
    required this.doc,
    required this.index,
    required this.isDark,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isGDrive = DocsService.isGoogleDriveUrl(doc.url);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: U.primary.withValues(alpha: 0.08),
              highlightColor: U.primary.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: U.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isGDrive
                            ? Icons.picture_as_pdf_rounded
                            : Icons.insert_drive_file_outlined,
                        color: U.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: GoogleFonts.outfit(
                              color: U.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isGDrive) ...[
                                Icon(Icons.cloud_done_rounded,
                                    color: U.primary.withValues(alpha: 0.7), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'Google Drive  •  ',
                                  style: GoogleFonts.outfit(
                                      color: U.sub, fontSize: 12),
                                ),
                              ],
                              Text(
                                'by ${doc.createdByName}',
                                style: GoogleFonts.outfit(
                                    color: U.dim, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Options menu
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') onEdit();
                        if (v == 'delete') onDelete();
                      },
                      color: U.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      icon: Icon(Icons.more_vert_rounded, color: U.sub, size: 20),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: U.text, size: 18),
                              const SizedBox(width: 10),
                              Text('Edit',
                                  style: GoogleFonts.outfit(
                                      color: U.text, fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: U.red, size: 18),
                              const SizedBox(width: 10),
                              Text('Delete',
                                  style: GoogleFonts.outfit(
                                      color: U.red, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: (index * 60).ms, duration: 400.ms)
          .slideY(begin: 0.1, end: 0, delay: (index * 60).ms, curve: Curves.easeOutCubic),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: U.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_rounded, color: U.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.outfit(color: U.sub, fontSize: 15, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
