import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/class_model.dart';
import '../services/github_global_service.dart';
import '../services/class_service.dart';
import 'class_settings_screen.dart';
import 'note_viewer_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;
  final String universityFolderName;
  const ClassDetailScreen({
    super.key,
    required this.classModel,
    required this.universityFolderName,
  });

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final GitHubGlobalService _github = GitHubGlobalService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _currentPath = '';
  List<String> _pathHistory = [''];

  String get _fullPath =>
      '${widget.universityFolderName}/${widget.classModel.classId}/Notes/$_currentPath';

  String _userRole = 'reader';

  @override
  void initState() {
    super.initState();
    _load();
    _checkRole();
    _fetchOwnerName();
  }

  String _ownerName = '';

  Future<void> _fetchOwnerName() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.classModel.creatorUid).get();
    if (doc.exists && mounted) {
      setState(() {
        _ownerName = doc.data()?['displayName'] ?? 'Unknown Admin';
      });
    }
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = await _classService.getUserRole(widget.classModel.classId, user.uid);
    if (mounted) setState(() => _userRole = role);
  }

  final ClassService _classService = ClassService();

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _github.getDirectoryContents(_fullPath);
    if (!mounted) return;
    setState(() {
      _items = items.where((item) => item['name'] != '.keep').toList();
      _loading = false;
    });
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _currentPath = '$_currentPath$folderName/';
      _pathHistory.add(_currentPath);
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
      _loading = true;
    });
    _load();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.classModel.name, style: GoogleFonts.outfit()),
            if (_ownerName.isNotEmpty)
              Text(
                'Owned by $_ownerName',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: U.sub,
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
          if (_userRole == 'writer')
            IconButton(
              icon: Icon(Icons.settings_outlined, color: U.sub),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassSettingsScreen(classModel: widget.classModel),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Code',
                  style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.classModel.classCode,
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      color: U.sub,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.classModel.classCode),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'THIS FEATURE IS UNDER DEVELOPMENT.',
                  style: GoogleFonts.outfit(color: U.red.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Divider(color: U.border, height: 1),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: U.primary))
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No notes yet.',
                      style: GoogleFonts.outfit(color: U.sub),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final name = item['name'] as String;
                      final type = item['type'] as String;
                      final isFolder = type == 'dir';

                      return ListTile(
                        leading: Icon(
                          isFolder
                              ? Icons.folder_rounded
                              : Icons.article_rounded,
                          color: isFolder ? U.primary : U.sub,
                        ),
                        title: Text(
                          name.replaceAll('.md', ''),
                          style: GoogleFonts.outfit(color: U.text),
                        ),
                        subtitle: !isFolder && item['size'] != null && !name.toLowerCase().endsWith('.md')
                            ? Text(
                                _formatFileSize(item['size'] as int),
                                style: GoogleFonts.outfit(
                                  color: U.sub,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        onTap: () {
                          if (isFolder) {
                            _navigateToFolder(name);
                          } else {
                            final downloadUrl = item['download_url'] as String?;
                            if (downloadUrl != null && downloadUrl.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoteViewerScreen(
                                    title: name.replaceAll('.md', ''),
                                    filePath: item['path'] as String,
                                    isEditable: _userRole == 'writer',
                                    useGlobalRepo: true,
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
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
