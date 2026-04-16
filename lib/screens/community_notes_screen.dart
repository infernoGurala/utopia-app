import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/github_global_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'note_viewer_screen.dart';

class CommunityNotesScreen extends StatefulWidget {
  final String universityFolderName;
  const CommunityNotesScreen({super.key, required this.universityFolderName});

  @override
  State<CommunityNotesScreen> createState() => _CommunityNotesScreenState();
}

class _CommunityNotesScreenState extends State<CommunityNotesScreen> {
  final GitHubGlobalService _github = GitHubGlobalService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _syncing = false;
  String _currentPath = '';
  List<String> _pathHistory = [''];
  bool _warningShown = false;
  bool _editModeEnabled = false;
  List<QueryDocumentSnapshot> _pendingDeletions = [];

  String get _fullPath =>
      '${widget.universityFolderName}/Community/$_currentPath';

  @override
  void initState() {
    super.initState();
    _load();
    _listenToDeletions();
  }

  StreamSubscription? _deletionSubscription;

  void _listenToDeletions() {
    debugPrint('LISTEN: Starting listener for ${widget.universityFolderName}');
    _deletionSubscription = FirebaseFirestore.instance
        .collection('community_deletions')
        .where('universityId', isEqualTo: widget.universityFolderName)
        .snapshots()
        .listen(
          (snapshot) {
            final pendingDocs = snapshot.docs
                .where((d) => d['isDeleted'] == false)
                .toList();
            debugPrint(
              'LISTEN: Got ${snapshot.docs.length} total, ${pendingDocs.length} pending deletions for ${widget.universityFolderName}',
            );
            for (var doc in pendingDocs) {
              debugPrint(
                'LISTEN: Deletion doc - path=${doc['path']}, name=${doc['name']}, approvals=${doc['approvals']}, isDeleted=${doc['isDeleted']}',
              );
            }
            if (mounted) {
              setState(() {
                _pendingDeletions = pendingDocs;
                _sortItems();
              });
            }
          },
          onError: (e) {
            debugPrint('LISTEN ERROR: $e');
          },
        );
  }

  @override
  void dispose() {
    _deletionSubscription?.cancel();
    super.dispose();
  }

  void _sortItems() {
    _items.sort((a, b) {
      final aPath = a['path'] as String? ?? '';
      final bPath = b['path'] as String? ?? '';

      final isADeleted = _pendingDeletions.any(
        (d) => (d.data() as Map<String, dynamic>?)?['path'] == aPath,
      );
      final isBDeleted = _pendingDeletions.any(
        (d) => (d.data() as Map<String, dynamic>?)?['path'] == bPath,
      );

      if (isADeleted && !isBDeleted) return -1;
      if (!isADeleted && isBDeleted) return 1;

      final aIsFolder = a['type'] == 'dir';
      final bIsFolder = b['type'] == 'dir';
      if (aIsFolder && !bIsFolder) return -1;
      if (!aIsFolder && bIsFolder) return 1;

      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
  }

  void _enterEditMode() {
    if (!_warningShown) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Edit Mode',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'This is a shared space for everyone. Please be respectful and don\'t delete useful content.',
            style: GoogleFonts.outfit(color: U.sub),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _warningShown = true);
                Navigator.pop(ctx);
                setState(() => _editModeEnabled = !_editModeEnabled);
              },
              child: Text(
                'I Understand',
                style: GoogleFonts.outfit(
                  color: U.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      setState(() => _editModeEnabled = !_editModeEnabled);
    }
  }

  bool get _isEditMode => _editModeEnabled;

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      if (_items.isEmpty) {
        _loading = true;
      } else {
        _syncing = true;
      }
    });

    // Capture the path at call time to guard against navigation race conditions
    final requestedPath = _fullPath;

    final items = await _github.getDirectoryContents(
      requestedPath,
      forceRefresh: forceRefresh,
      onRefresh: (freshItems) {
        // Background refresh completed — only update if we're still on the same path
        if (!mounted || _fullPath != requestedPath) return;
        setState(() {
          _items = freshItems.where((item) => item['name'] != '.keep').toList();
          _sortItems();
          _syncing = false;
        });
      },
    );
    if (!mounted || _fullPath != requestedPath) return;
    setState(() {
      _items = items.where((item) => item['name'] != '.keep').toList();
      _sortItems();
      _loading = false;
      _syncing = false;
    });
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath = '$_currentPath$folderName/';
      _pathHistory.add(_currentPath);
      // Clear old items immediately so previous folder content doesn't flash
      _items = [];
      _loading = true;
    });
    _load();
  }

  void _navigateBack() {
    if (_pathHistory.length <= 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _pathHistory.removeLast();
      _currentPath = _pathHistory.last;
      // Clear old items immediately so previous folder content doesn't flash
      _items = [];
      _loading = true;
    });
    _load();
  }

  void _showAddBranchDialog() {
    final controller = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Add Branch',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creates a sample semester, course, and unit structure.',
                style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: 'Branch name',
                  hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true,
                  fillColor: U.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: U.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) return;

                      Navigator.pop(ctx);

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() {
                        _items.insert(0, {
                          'name': name,
                          'type': 'dir',
                          'path':
                              '${widget.universityFolderName}/Community/$name',
                        });
                        _sortItems();
                      });

                      final success = await _github.createBranchStructure(
                        widget.universityFolderName,
                        name,
                      );

                      if (!mounted) return;

                      if (success) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name branch created!'),
                            backgroundColor: U.green,
                          ),
                        );
                        _load(forceRefresh: true);
                      } else {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create $name branch'),
                            backgroundColor: U.red,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isCreating ? 'Creating...' : 'Create',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    final controller = TextEditingController();
    bool isCreating = false;
    bool isFile = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Add Item',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'File',
                        style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                      ),
                      value: true,
                      groupValue: isFile,
                      activeColor: U.primary,
                      onChanged: (val) => setDialogState(() => isFile = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Folder',
                        style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                      ),
                      value: false,
                      groupValue: isFile,
                      activeColor: U.primary,
                      onChanged: (val) => setDialogState(() => isFile = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: isFile ? 'File name' : 'Folder name',
                  hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true,
                  fillColor: U.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: U.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      var name = controller.text.trim();
                      if (name.isEmpty) return;

                      if (isFile && !name.endsWith('.md')) {
                        name += '.md';
                      }

                      setDialogState(() => isCreating = true);
                      Navigator.pop(ctx);

                      final targetPath = isFile
                          ? '$_fullPath$name'
                          : '$_fullPath$name/.keep';

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() {
                        _items.insert(0, {
                          'name': name,
                          'type': isFile ? 'file' : 'dir',
                          'path': targetPath,
                          'size': isFile ? 0 : null,
                        });
                        _sortItems();
                      });

                      final success = await _github.createFolder(
                        targetPath,
                        content: isFile
                            ? '# ${name.replaceAll('.md', '')}\n\n'
                            : '# init\n',
                      );

                      if (mounted) {
                        if (!success) {
                          // Revert on failure
                          setState(() {
                            _items = originalItems;
                          });
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '$name created!'
                                  : 'Failed to create $name',
                            ),
                            backgroundColor: success ? U.green : U.red,
                          ),
                        );
                        if (success) _load(forceRefresh: true);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isCreating ? 'Creating...' : 'Create',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAtRoot = _currentPath.isEmpty;

    return PopScope(
      canPop: isAtRoot,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Utopia',
                style: GoogleFonts.playfairDisplay(
                  color: U.primary,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: (_syncing || _loading) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: SizedBox(
                  width: 40,
                  child: LinearProgressIndicator(
                    backgroundColor: U.border,
                    valueColor: AlwaysStoppedAnimation<Color>(U.primary),
                    minHeight: 1.5,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: U.bg,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: U.text),
            onPressed: _navigateBack,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isEditMode
                    ? Icons.check_circle_outline
                    : Icons.edit_note_rounded,
                color: _isEditMode ? U.green : U.primary,
              ),
              onPressed: _enterEditMode,
            ),
            if (isAtRoot)
              IconButton(
                icon: Icon(Icons.add, color: U.primary),
                onPressed: _showAddBranchDialog,
              )
            else
              IconButton(
                icon: Icon(Icons.add, color: U.primary),
                onPressed: _showAddItemDialog,
              ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: U.primary))
            : _items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No notes yet.',
                      style: GoogleFonts.outfit(color: U.sub),
                    ),
                    if (isAtRoot) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showAddBranchDialog,
                        icon: Icon(Icons.add, color: U.bg),
                        label: Text(
                          'Add Branch',
                          style: GoogleFonts.outfit(color: U.bg),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: U.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : RefreshIndicator(
                color: U.primary,
                backgroundColor: U.surface,
                onRefresh: () => _load(forceRefresh: true),
                child: isAtRoot
                    ? GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final name = item['name'] as String;
                          return _buildProgramCard(
                            title: name,
                            onTap: () => _navigateToFolder(name),
                          );
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final name = item['name'] as String;
                          final type = item['type'] as String;
                          final isFolder = type == 'dir';
                          final path = item['path'] as String;

                          final deletionDoc = _pendingDeletions
                              .where((d) => d['path'] == path)
                              .firstOrNull;
                          final isPendingDeletion = deletionDoc != null;
                          final approvals = isPendingDeletion
                              ? List<String>.from(
                                  deletionDoc['approvals'] ?? [],
                                )
                              : [];
                          final user = FirebaseAuth.instance.currentUser;
                          final hasApproved =
                              user != null && approvals.contains(user.uid);

                          return ListTile(
                            enabled: !isPendingDeletion,
                            leading: Icon(
                              isFolder
                                  ? Icons.folder_rounded
                                  : Icons.article_rounded,
                              color: isPendingDeletion
                                  ? U.sub.withValues(alpha: 0.3)
                                  : (isFolder ? U.primary : U.sub),
                            ),
                            title: Text(
                              name.replaceAll('.md', ''),
                              style: GoogleFonts.outfit(
                                color: isPendingDeletion ? U.sub : U.text,
                              ),
                            ),
                            subtitle:
                                !isFolder &&
                                    item['size'] != null &&
                                    !name.toLowerCase().endsWith('.md')
                                ? Text(
                                    isPendingDeletion
                                        ? 'Pending Deletion (${approvals.length}/3 approvals)'
                                        : _formatFileSize(item['size'] as int),
                                    style: GoogleFonts.outfit(
                                      color: U.sub,
                                      fontSize: 12,
                                    ),
                                  )
                                : (isPendingDeletion
                                      ? Text(
                                          'Pending Deletion (${approvals.length}/3 approvals)',
                                          style: GoogleFonts.outfit(
                                            color: U.sub,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null),
                            trailing: isPendingDeletion
                                ? (hasApproved
                                      ? Icon(
                                          Icons.check_circle,
                                          color: U.green,
                                          size: 20,
                                        )
                                      : TextButton(
                                          onPressed: () =>
                                              _approveDeletion(deletionDoc!),
                                          child: Text(
                                            'Approve',
                                            style: GoogleFonts.outfit(
                                              color: U.red,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ))
                                : (_isEditMode
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: U.primary,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              _showEditOptions(item, isFolder),
                                        )
                                      : null),
                            onTap: () async {
                              if (isPendingDeletion) return;
                              if (isFolder) {
                                _navigateToFolder(name);
                              } else {
                                final downloadUrl =
                                    item['download_url'] as String?;
                                if (downloadUrl != null &&
                                    downloadUrl.isNotEmpty) {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoteViewerScreen(
                                        title: name.replaceAll('.md', ''),
                                        filePath: path,
                                        isEditable: _isEditMode,
                                      ),
                                    ),
                                  );

                                  if (result is String) {
                                    // Trigger a silent reload or let NoteViewerScreen handle its own cache updates
                                  }
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
      ),
    );
  }

  void _requestDeletion(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final path = item['path'] as String;
    final name = item['name'] as String;
    final type = item['type'] as String;

    debugPrint(
      'DELETE REQUEST: path=$path, name=$name, type=$type, uni=${widget.universityFolderName}',
    );

    try {
      await FirebaseFirestore.instance.collection('community_deletions').add({
        'universityId': widget.universityFolderName,
        'path': path,
        'name': name,
        'type': type,
        'requesterUid': user.uid,
        'approvals': <String>[],
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('DELETE REQUEST: Successfully added to Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deletion requested. Needs 3 approvals.'),
            backgroundColor: U.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('DELETE REQUEST ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request deletion: $e'),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  void _showRenameDialog(Map<String, dynamic> item, bool isFolder) {
    final oldName = item['name'] as String;
    final path = item['path'] as String;
    final controller = TextEditingController(
      text: oldName.replaceAll('.md', ''),
    );
    bool isRenaming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text(
            'Rename',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: U.text),
            decoration: InputDecoration(
              hintText: 'New name',
              hintStyle: GoogleFonts.outfit(color: U.sub),
              filled: true,
              fillColor: U.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: U.border),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isRenaming
                  ? null
                  : () async {
                      var newName = controller.text.trim();
                      if (newName.isEmpty ||
                          newName == oldName.replaceAll('.md', ''))
                        return;

                      if (!isFolder && !newName.endsWith('.md')) {
                        newName += '.md';
                      }

                      setDialogState(() => isRenaming = true);
                      Navigator.pop(ctx);

                      final parentPath = path.substring(
                        0,
                        path.lastIndexOf('/'),
                      );
                      final newPath = parentPath.isEmpty
                          ? newName
                          : '$parentPath/$newName';

                      // Optimistic Update
                      final originalItems = List<Map<String, dynamic>>.from(
                        _items,
                      );
                      setState(() {
                        final index = _items.indexWhere(
                          (i) => i['path'] == path,
                        );
                        if (index != -1) {
                          _items[index] = {
                            ..._items[index],
                            'name': newName,
                            'path': newPath,
                          };
                        }
                      });

                      final success = await _github.renameItem(path, newPath);

                      if (mounted) {
                        if (!success) {
                          // Revert on failure
                          setState(() {
                            _items = originalItems;
                          });
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Renamed successfully'
                                  : 'Failed to rename',
                            ),
                            backgroundColor: success ? U.green : U.red,
                          ),
                        );
                        if (success) _load(forceRefresh: true);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(
                isRenaming ? 'Renaming...' : 'Rename',
                style: GoogleFonts.outfit(color: U.bg),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _approveDeletion(QueryDocumentSnapshot deletionDoc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final approvals = List<String>.from(deletionDoc['approvals'] ?? []);
    if (!approvals.contains(user.uid)) {
      approvals.add(user.uid);

      if (approvals.length >= 3) {
        // Trigger actual deletion!
        await deletionDoc.reference.update({
          'approvals': approvals,
          'isDeleted': true,
        });
        await _github.deleteItem(deletionDoc['path']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File deleted successfully.'),
              backgroundColor: U.green,
            ),
          );
          _load();
        }
      } else {
        await deletionDoc.reference.update({'approvals': approvals});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deletion approved (${approvals.length}/3).'),
              backgroundColor: U.primary,
            ),
          );
        }
      }
    }
  }

  void _showEditOptions(Map<String, dynamic> item, bool isFolder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: U.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.edit_outlined, color: U.text),
            title: Text('Rename', style: GoogleFonts.outfit(color: U.text)),
            onTap: () {
              Navigator.pop(ctx);
              _showRenameDialog(item, isFolder);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: U.red),
            title: Text('Delete', style: GoogleFonts.outfit(color: U.red)),
            onTap: () {
              Navigator.pop(ctx);
              _requestDeletion(item);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgramCard({
    required String title,
    required VoidCallback onTap,
  }) {
    // Curated color pairs for vibrant gradients
    final colorPairs = [
      [const Color(0xFF6366F1), const Color(0xFFA855F7)], // Indigo -> Purple
      [const Color(0xFFEC4899), const Color(0xFFF43F5E)], // Pink -> Rose
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber -> Orange
      [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald -> Green
      [const Color(0xFF3B82F6), const Color(0xFF2563EB)], // Blue -> Deep Blue
      [
        const Color(0xFF8B5CF6),
        const Color(0xFF7C3AED),
      ], // Violet -> Dark Violet
    ];

    // Select color based on title hash
    final pairIndex = title.hashCode.abs() % colorPairs.length;
    final pair = colorPairs[pairIndex];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pair[0], pair[1]],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: pair[0].withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Abstract background shape
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -30,
                child: Icon(
                  Icons.folder_copy_rounded,
                  color: Colors.white.withValues(alpha: 0.05),
                  size: 140,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.collections_bookmark_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
