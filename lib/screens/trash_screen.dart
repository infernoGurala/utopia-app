import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/trash_service.dart';
import '../services/supabase_global_service.dart';
import '../main.dart';

class TrashScreen extends StatefulWidget {
  final String universityId;
  const TrashScreen({super.key, required this.universityId});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late final TrashService _trashService;
  final SupabaseGlobalService _github = SupabaseGlobalService.instance;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _trashService = TrashService(universityId: widget.universityId);
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _restore(String docId, String name) async {
    setState(() => _processing = true);
    try {
      await _trashService.restore(docId, github: _github);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored "$name"'), backgroundColor: U.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: U.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _permanentlyDelete(
    String docId,
    String path,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: U.surface,
        title: Text(
          'Delete Permanently',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to permanently delete "$name"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: U.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing = true);
    try {
      await _trashService.permanentlyDelete(
        docId: docId,
        deleteCallback: () async {
          if (path.endsWith('.md')) {
            await _github.deleteNote(path);
          } else {
            await _github.deleteFolder(path);
          }
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted "$name"'),
            backgroundColor: U.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: U.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        title: Text(
          'Trash',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        foregroundColor: U.text,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _trashService.trashStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("TRASH: Stream error: ${snapshot.error}");
            return Center(
              child: Text(
                "Error loading trash",
                style: GoogleFonts.outfit(color: U.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: U.primary));
          }
          final docs = (snapshot.data?.docs ?? [])
              .where((d) => d.data()['restored'] == false)
              .toList();
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 64, color: U.dim),
                  const SizedBox(height: 16),
                  Text(
                    'Trash is empty',
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final path = data['path'] as String;
              final name = data['name'] as String;
              final type = data['type'] as String;
              final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();
              final permanentDeleteAt = data['permanentDeleteAt'] as Timestamp?;
              final daysLeft = _trashService.daysRemaining(permanentDeleteAt);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: U.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    type == 'dir'
                        ? Icons.folder_outlined
                        : Icons.article_outlined,
                    color: U.primary,
                  ),
                  title: Text(
                    name,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deleted ${deletedAt != null ? _formatRelativeTime(deletedAt) : ''} by ${data['deletedByName']}',
                        style: GoogleFonts.outfit(color: U.dim, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Permanently deletes in $daysLeft days',
                        style: GoogleFonts.outfit(
                          color: U.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.settings_backup_restore_rounded,
                          color: U.green,
                        ),
                        onPressed: _processing
                            ? null
                            : () => _restore(docs[index].id, name),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_rounded, color: U.red),
                        onPressed: _processing
                            ? null
                            : () => _permanentlyDelete(
                                docs[index].id,
                                path,
                                name,
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
