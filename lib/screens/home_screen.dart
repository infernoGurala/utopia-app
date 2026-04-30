import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/cache_service.dart';
import '../services/supabase_notes_service.dart';
import '../services/role_service.dart';
import '../widgets/app_motion.dart';
import 'editor_screen.dart';
import 'sciwordle_screen.dart';
import 'note_viewer_screen.dart';
import 'search_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _notes = SupabaseNotesService();
  static const List<String> _libraryMoodWords = [
    'focus',
    'clarity',
    'rhythm',
    'revision',
    'momentum',
    'depth',
    'calm',
    'signal',
  ];

  List<Map<String, dynamic>> _folders = [];
  bool _loading = true;
  bool _syncing = false;
  bool _offlineWarmupScheduled = false;
  bool _isSuperUser = false;
  late final String _subtitleWord;

  static final _subjectInfo = {
    'thermodynamics': (Icons.local_fire_department_outlined, U.peach),
    'devc': (Icons.calculate_outlined, U.blue),
    'beee': (Icons.electrical_services_outlined, U.peach),
    'electrical': (Icons.electrical_services_outlined, U.peach),
    'chemistry': (Icons.science_outlined, U.teal),
    'economics': (Icons.bar_chart_outlined, U.green),
    'ppsuc': (Icons.code_outlined, U.primary),
    'iot': (Icons.sensors_outlined, U.blue),
    'crt': (Icons.fact_check_outlined, U.primary),
    'lab': (Icons.biotech_outlined, U.teal),
    'archive': (Icons.archive_outlined, U.sub),
    'docs': (Icons.school_outlined, U.primary),
    'other': (Icons.category_outlined, U.dim),
    'mathematics': (Icons.functions_outlined, U.primary),
    'math': (Icons.functions_outlined, U.primary),
  };

  (IconData, Color) _infoFor(String name) {
    final key = name.toLowerCase();
    for (final entry in _subjectInfo.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return (Icons.folder_outlined, U.primary);
  }

  @override
  void initState() {
    super.initState();
    _subtitleWord =
        _libraryMoodWords[DateTime.now().microsecondsSinceEpoch %
            _libraryMoodWords.length];
    WidgetsBinding.instance.addObserver(this);
    RoleService().isSuperUser().then((v) {
      if (mounted) {
        setState(() => _isSuperUser = v);
        _loadCached();
        _load();
      }
    });
    _scheduleOfflineWarmup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      RoleService().isSuperUser().then((v) {
        if (mounted) {
          setState(() => _isSuperUser = v);
          _load();
        }
      });
    }
  }

  void _scheduleOfflineWarmup() {
    if (_offlineWarmupScheduled) return;
    _offlineWarmupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        // Offline warmup is no longer needed with Supabase
      });
    });
  }

  Future<void> _loadCached() async {
    final folders = await CacheService().getFolders(includeHidden: _isSuperUser);
    if (!mounted || folders.isEmpty) return;
    setState(() {
      _folders = folders.where((f) {
        final n = f['name'].toString();
        return !n.startsWith('.') && !n.toLowerCase().contains('github');
      }).toList();
      _loading = false;
    });
  }

  Future<void> _load() async {
    if (mounted) setState(() => _syncing = true);
    final folders = await _notes.getFolders();
    // _scheduleOfflineWarmup();
    if (!mounted) return;
    setState(() {
      _folders = folders.where((f) {
        final n = f['name'].toString();
        return !n.startsWith('.') && !n.toLowerCase().contains('github');
      }).toList();
      _loading = false;
      _syncing = false;
    });
  }

  Future<void> _toggleFolderVisibility(
    String path,
    bool currentlyHidden,
  ) async {
    final newHidden = !currentlyHidden;
    bool success = false;
    try {
      await _notes.setFolderHidden(path, newHidden);
      success = true;
    } catch (_) {
      success = false;
    }

    if (success) {
      setState(() {
        _folders = _folders.map((f) {
          if (f['path'] == path) return {...f, 'is_hidden': newHidden ? 1 : 0};
          return f;
        }).toList();
      });
      await CacheService().setFolderHidden(path, newHidden);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (newHidden
                      ? 'Folder hidden from users'
                      : 'Folder visible to all')
                : 'Failed to update (check internet)',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: success
              ? const Color(0xFFA6E3A1)
              : const Color(0xFFF38D8D),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (success) {
      await _load();
    }
  }

  void _showDeleteFolderDialog(String name, String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          'Delete "$name"?',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will remove the folder and all its files. Cannot be undone.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: U.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: U.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: U.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.outfit(color: U.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = false;
              try {
                await _notes.deleteFolder(path);
                success = true;
              } catch (_) {}
              if (success) {
                await _load();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete folder',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: U.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: U.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFolderDialog() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          'New Folder',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.outfit(color: U.text),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: GoogleFonts.outfit(color: U.dim),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: U.border),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: U.primary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              bool success = false;
              try {
                await _notes.createFolder(name);
                success = true;
              } catch (_) {}
              if (success) {
                await _load();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Folder "$name" created',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: const Color(0xFFA6E3A1),
                    ),
                  );
                }
              } else {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create folder',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: U.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Create',
              style: GoogleFonts.outfit(
                color: U.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(buildContainerRoute(const SearchScreen()));
  }

  void _openTimetable() {
    Navigator.of(context).push(buildContainerRoute(const TimetableScreen()));
  }

  Widget _buildHeaderIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Utopia',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: U.primary,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      color: U.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedOpacity(
              opacity: _syncing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: SizedBox(
                width: 50,
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
      ],
    )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderAction(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onTap: _openSearch,
        ),
        const SizedBox(width: 10),
        _HeaderAction(
          icon: Icons.calendar_month_rounded,
          tooltip: 'Timetable',
          onTap: _openTimetable,
        ),
        const SizedBox(width: 10),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 500.ms, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useCompactHeader = width < 390;

    return Scaffold(
      backgroundColor: U.bg,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSuperUser)
            Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: U.border),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showAddFolderDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.create_new_folder_outlined,
                      color: U.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          if (_isSuperUser) const SizedBox(height: 8),
          _SciWordleFAB(),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: useCompactHeader
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderIdentity(),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildHeaderActions(),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildHeaderIdentity()),
                        const SizedBox(width: 12),
                        _buildHeaderActions(),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Divider(color: U.border, height: 1, thickness: 0.5),
            Expanded(
              child: _loading
                  ? const _LibrarySkeleton()
                  : _folders.isEmpty
                  ? Center(
                      child: Text(
                        'No subjects found',
                        style: GoogleFonts.outfit(color: U.sub),
                      ),
                    )
                  : RefreshIndicator(
                      color: U.primary,
                      backgroundColor: U.card,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 116),
                        itemCount: _folders.length,
                        separatorBuilder: (_, separatorIndex) => Divider(
                          color: U.border,
                          height: 1,
                          thickness: 0.5,
                          indent: 56,
                        ),
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          final info = _infoFor(folder['name']);
                          final isHidden = folder['is_hidden'] == 1;
                          return _SubjectRow(
                            key: ValueKey(folder['path']),
                            name: folder['name'],
                            path: folder['path'],
                            icon: info.$1,
                            color: info.$2,
                            index: index,
                            isHidden: isHidden,
                            isWriter: _isSuperUser,
                            onTap: () => Navigator.push(
                              context,
                              buildForwardRoute(
                                TopicListScreen(
                                  folderName: folder['name'],
                                  folderPath: folder['path'],
                                ),
                              ),
                            ),
                            onToggleVisibility: () => _toggleFolderVisibility(
                              folder['path'],
                              isHidden,
                            ),
                            onDelete: () => _showDeleteFolderDialog(
                              folder['name'],
                              folder['path'],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String name;
  final String path;
  final IconData icon;
  final Color color;
  final int index;
  final bool isHidden;
  final bool isWriter;
  final VoidCallback onTap;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;
  const _SubjectRow({
    super.key,
    required this.name,
    required this.path,
    required this.icon,
    required this.color,
    required this.index,
    required this.isHidden,
    required this.isWriter,
    required this.onTap,
    required this.onToggleVisibility,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const trailingSlotWidth = 28.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + index * 45),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.06),
        highlightColor: color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: isHidden ? U.dim : color, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isHidden ? U.dim : U.text,
                  ),
                ),
              ),
              SizedBox(
                width: trailingSlotWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: isWriter
                      ? PopupMenuButton<String>(
                          color: U.card,
                          padding: EdgeInsets.zero,
                          tooltip: 'Folder actions',
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: Center(
                              child: Icon(
                                Icons.more_vert,
                                color: U.dim,
                                size: 14,
                              ),
                            ),
                          ),
                          splashRadius: 18,
                          onSelected: (value) {
                            if (value == 'hide') onToggleVisibility();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'hide',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isHidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: U.text,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isHidden ? 'Show' : 'Hide',
                                    style: GoogleFonts.outfit(
                                      color: U.text,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: U.red,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Delete',
                                    style: GoogleFonts.outfit(
                                      color: U.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Icon(
                          Icons.chevron_right,
                          color: U.dim.withValues(alpha: 0.9),
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? iconColor;
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: iconColor ?? U.text, size: 22)),
              if (badgeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: U.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SciWordleFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [U.primary, U.primary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: U.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SciwordleScreen()),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      children: const [
        _LibrarySkeletonRow(),
        _LibrarySkeletonRow(),
        _LibrarySkeletonRow(),
        _LibrarySkeletonRow(),
        _LibrarySkeletonRow(),
      ],
    );
  }
}

class _LibrarySkeletonRow extends StatelessWidget {
  const _LibrarySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SkeletonBox(height: 22, width: 22, radius: 8),
          const SizedBox(width: 16),
          Expanded(child: SkeletonBox(height: 18, radius: 8)),
          const SizedBox(width: 12),
          SkeletonBox(height: 16, width: 16, radius: 8),
        ],
      ),
    );
  }
}

class TopicListScreen extends StatefulWidget {
  final String folderName;
  final String folderPath;
  const TopicListScreen({
    super.key,
    required this.folderName,
    required this.folderPath,
  });
  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  final _supabaseNotes = SupabaseNotesService();
  List<Map<String, dynamic>> _files = [];
  String _indexContent = '';
  String? _indexFilePath;
  String _indexRawContent = '';
  bool _loading = true;
  bool _isSuperUser = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    RoleService().isSuperUser().then((v) {
      if (mounted) setState(() => _isSuperUser = v);
    });
  }

  Map<String, dynamic>? _findIndexFile(List<Map<String, dynamic>> files) {
    for (final file in files) {
      final name = file['name'].toString().toLowerCase();
      final path = file['path'].toString().toLowerCase();
      if (name == 'index' || path.endsWith('index.md')) return file;
    }
    return null;
  }

  void _applyTopicFiles(List<Map<String, dynamic>> files) {
    final displayFiles = files
        .where((f) => !f['name'].toString().toLowerCase().contains('index'))
        .toList();
    if (!mounted) return;
    setState(() {
      _files = displayFiles;
      _loading = false;
    });
  }

  Future<void> _load() async {
    try {
      final files = await _supabaseNotes.getFiles(widget.folderPath);
      _applyTopicFiles(files);
      unawaited(_refreshIndexContent(files));
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshIndexContent(List<Map<String, dynamic>> files) async {
    final indexFile = _findIndexFile(files);
    if (indexFile == null) return;
    final indexPath = indexFile['path'].toString();
    try {
      final raw = await _supabaseNotes.getNoteContent(indexPath);
      if (!mounted) return;
      setState(() {
        _indexFilePath = indexPath;
        _indexRawContent = raw;
        _indexContent = _extractDescription(raw);
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  String _extractDescription(String raw) {
    final lines = raw.split('\n');
    final desc = <String>[];
    bool inFrontmatter = false, pastFrontmatter = false;
    for (final line in lines) {
      if (line.trim() == '---') {
        if (!pastFrontmatter) {
          inFrontmatter = !inFrontmatter;
          if (!inFrontmatter) pastFrontmatter = true;
        }
        continue;
      }
      if (inFrontmatter) continue;
      if (line.startsWith('#')) continue;
      if (line.trim().isEmpty && desc.isEmpty) continue;
      if (line.startsWith('###')) break;
      desc.add(line);
      if (desc.length >= 3) break;
    }
    return desc.join('\n').trim();
  }

  Future<void> _openExternalLink(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _displayName(String name) =>
      name.replaceAll(RegExp(r'^\d+\s*'), '').trim();
  String? _numberBadge(String name) =>
      RegExp(r'^(\d+)').firstMatch(name)?.group(1);
  bool _isExamPrep(String name) =>
      name.toLowerCase().contains('exam') ||
      name.toLowerCase().contains('prep') ||
      name.toLowerCase().contains('question') ||
      name.toLowerCase().contains('bank');

  void _showAddFileDialog() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          'New File',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.outfit(color: U.text),
          decoration: InputDecoration(
            hintText: 'File name',
            hintStyle: GoogleFonts.outfit(color: U.dim),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: U.border),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: U.primary),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              try {
                await _supabaseNotes.createNote(
                  widget.folderPath,
                  name,
                  '# $name\n\nStart writing your notes here...',
                );
                await _load();
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to create file',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: U.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Create',
              style: GoogleFonts.outfit(
                color: U.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteFileDialog(String name, String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          'Delete "$name"?',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This file will be permanently deleted.',
              style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: U.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: U.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: U.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cannot be undone.',
                      style: GoogleFonts.outfit(color: U.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: U.dim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _supabaseNotes.deleteNote(path);
                await _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete file',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: U.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(
                color: U.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Color(0xFF6C7086),
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.folderName,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: U.text,
                      ),
                    ),
                  ),
                  if (_isSuperUser && _indexFilePath != null)
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: U.primary,
                        size: 20,
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditorScreen(
                              title: '${widget.folderName} Index',
                              filePath: _indexFilePath!,
                              initialContent: _indexRawContent,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() => _loading = true);
                          await _load();
                        }
                      },
                    ),
                  if (_isSuperUser) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.add, color: U.primary, size: 20),
                      onPressed: _showAddFileDialog,
                    ),
                  ],
                ],
              ),
            ),
            if (_indexContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: MarkdownBody(
                  data: _indexContent,
                  onTapLink: (text, href, title) async {
                    if (href != null) await _openExternalLink(href);
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.outfit(
                      fontSize: 13,
                      color: U.sub,
                      height: 1.5,
                    ),
                    a: GoogleFonts.outfit(fontSize: 13, color: U.primary),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Divider(color: U.border, height: 1, thickness: 0.5),
            Expanded(
              child: _loading
                  ? const _TopicListSkeleton()
                  : _files.isEmpty
                  ? Center(
                      child: Text(
                        'No files found',
                        style: GoogleFonts.outfit(color: U.sub),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 116),
                      itemCount: _files.length,
                      separatorBuilder: (context, separatorIndex) => Divider(
                        color: U.border,
                        height: 1,
                        thickness: 0.5,
                        indent: 56,
                      ),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        final isExam = _isExamPrep(file['name']);
                        final number = _numberBadge(file['name']);
                        final displayName = _displayName(file['name']);

                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 220 + index * 35),
                          curve: Curves.easeOut,
                          builder: (context, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - v)),
                              child: child,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              buildForwardRoute(
                                NoteViewerScreen(
                                  title: displayName,
                                  filePath: file['path'],
                                  folderPath: widget.folderPath,
                                ),
                              ),
                            ),
                            splashColor: isExam
                                ? U.peach.withValues(alpha: 0.08)
                                : U.teal.withValues(alpha: 0.06),
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  if (isExam)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: U.peach.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const _ExamPrepIcon(),
                                    )
                                  else if (number != null)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: U.teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          number,
                                          style: GoogleFonts.outfit(
                                            color: U.teal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.article_outlined,
                                      color: U.teal,
                                      size: 22,
                                    ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      isExam ? file['name'] : displayName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: isExam
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isExam ? U.peach : U.text,
                                      ),
                                    ),
                                  ),
                                  if (_isSuperUser)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: U.dim,
                                        size: 16,
                                      ),
                                      padding: EdgeInsets.zero,
                                      onSelected: (value) {
                                        if (value == 'delete')
                                          _showDeleteFileDialog(
                                            file['name'],
                                            file['path'],
                                          );
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'delete',
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                color: U.red,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Delete',
                                                style: GoogleFonts.outfit(
                                                  color: U.red,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right,
                                      color: U.dim,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamPrepIcon extends StatelessWidget {
  const _ExamPrepIcon();

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(Icons.quiz_outlined, color: U.peach, size: 18));
  }
}

class _TopicListSkeleton extends StatelessWidget {
  const _TopicListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      children: const [
        SkeletonBox(height: 44, margin: EdgeInsets.only(bottom: 16)),
        SkeletonBox(height: 58, margin: EdgeInsets.only(bottom: 10)),
        SkeletonBox(height: 58, margin: EdgeInsets.only(bottom: 10)),
        SkeletonBox(height: 58, margin: EdgeInsets.only(bottom: 10)),
        SkeletonBox(height: 58),
      ],
    );
  }
}
