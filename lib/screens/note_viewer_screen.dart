import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../services/cache_service.dart';
import '../services/chat_service.dart';
import '../services/file_cache_service.dart';
import '../services/github_service.dart';
import '../services/github_global_service.dart';
import '../services/platform_support.dart';
import '../services/role_service.dart';
import 'editor_screen.dart';

class NoteViewerScreen extends StatefulWidget {
  final String title;
  final String filePath;
  final String? folderPath;
  final String? highlightQuery;
  final List<String>? wikiCandidates;
  final String? initialSegmentId;
  final bool isEditable;
  const NoteViewerScreen({
    super.key,
    required this.title,
    required this.filePath,
    this.folderPath,
    this.highlightQuery,
    this.wikiCandidates,
    this.initialSegmentId,
    this.isEditable = false,
  });
  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  final _github = GitHubService();
  final _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  String _rawContent = '';
  List<Map<String, dynamic>> _noteFiles = [];
  List<Map<String, dynamic>> _assignmentFiles = [];
  List<_Segment> _segments = const [];
  final Map<String, GlobalKey> _segmentKeys = {};
  bool _loading = true;
  bool _isWriter = false;
  bool _didScrollToInitialSegment = false;

  @override
  void initState() {
    super.initState();
    _load();
    RoleService().isWriter().then((v) {
      if (mounted) {
        setState(() {
          // If it's a community note, we consider the user a writer if isEditable is passed as true
          // but we still check global writer role for overall permission.
          _isWriter = v;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String raw = '';

    final allCandidates = <String>[widget.filePath];
    if (widget.wikiCandidates != null) {
      for (final c in widget.wikiCandidates!) {
        if (!allCandidates.contains(c)) allCandidates.add(c);
      }
    }

    final isCommunityNote = widget.filePath.contains('/Community/');
    final globalGitHub = GitHubGlobalService();

    for (final candidate in allCandidates) {
      if (isCommunityNote) {
        raw = await globalGitHub.getFileContentRaw(candidate);
      } else {
        raw = await _github.getFileContent(candidate);
      }
      if (raw.isNotEmpty) break;
    }

    if (raw.isEmpty && mounted) {
      setState(() {
        _segments = _parseSegments(
          '_Note not found. Open this note directly from the library._',
        );
        _loading = false;
      });
      return;
    }

    _rawContent = raw;
    _parse(raw);
  }

  String _applyHighlight(String content) {
    final query = widget.highlightQuery;
    if (query == null || query.trim().isEmpty) return content;
    final escaped = RegExp.escape(query);
    final re = RegExp(escaped, caseSensitive: false);
    return content.replaceFirstMapped(re, (m) => '**${m.group(0)}**');
  }

  void _parse(String raw) {
    final noteFiles = <Map<String, dynamic>>[];
    final assignmentFiles = <Map<String, dynamic>>[];
    final contentLines = <String>[];
    final lines = raw.split('\n');
    String? section;
    bool inFrontmatter = false;
    bool frontmatterDone = false;
    int frontmatterDashes = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final t = line.trim();

      if (!frontmatterDone) {
        if (t == '---' && i == 0) {
          inFrontmatter = true;
          frontmatterDashes = 1;
          continue;
        }
        if (inFrontmatter && t == '---' && frontmatterDashes == 1) {
          inFrontmatter = false;
          frontmatterDone = true;
          continue;
        }
        if (inFrontmatter) continue;
        frontmatterDone = true;
      }

      if (t == '### NOTES' || t == '### RESOURCES') {
        section = 'NOTES';
        continue;
      }
      if (t == '### ASSIGNMENTS') {
        section = 'ASSIGNMENTS';
        continue;
      }
      if (t.startsWith('### ') && section != null) {
        section = null;
      }

      if (section != null && t.startsWith('[')) {
        final m = RegExp(r'\[(.+?)\]\((.+?)\)').firstMatch(t);
        if (m != null) {
          final entry = {
            'name': m.group(1) ?? '',
            'url': m.group(2) ?? '',
            'type': 'pdf',
          };
          if (section == 'NOTES') {
            noteFiles.add(entry);
          } else {
            assignmentFiles.add(entry);
          }
          continue;
        }
      }

      if (t == '---') section = null;
      contentLines.add(line);
    }

    while (contentLines.isNotEmpty && contentLines.first.trim().isEmpty) {
      contentLines.removeAt(0);
    }

    var content = contentLines.join('\n').trim();

    // Convert Obsidian image embeds ![[image.png|200]] → ![image.png](image.png)
    // Must run BEFORE the [[wiki link]] conversion below.
    content = content.replaceAllMapped(RegExp(r'!\[\[([^\]]+)\]\]'), (m) {
      final inner = m.group(1)!;
      // Strip Obsidian size suffix (e.g. "|200" or "|200x100")
      final name = inner.split('|').first.trim();
      return '![$name]($name)';
    });

    content = content.replaceAllMapped(
      RegExp(r'\[\[([^\]]+)\]\]'),
      (m) => '[${m.group(1)}](wikilink://${Uri.encodeComponent(m.group(1)!)})',
    );

    content = content.replaceAllMapped(
      RegExp(r'==([^=]+)=='),
      (m) => '`${m.group(1)}`',
    );

    setState(() {
      final highlighted = _applyHighlight(content);
      _noteFiles = noteFiles;
      _assignmentFiles = assignmentFiles;
      _segments = _parseSegments(highlighted);
      _loading = false;
    });
    _scheduleInitialSegmentReveal();
  }

  String _normalizePath(String path) {
    final parts = <String>[];
    for (final rawPart in path.split('/')) {
      final part = rawPart.trim();
      if (part.isEmpty || part == '.') {
        continue;
      }
      if (part == '..') {
        if (parts.isNotEmpty) {
          parts.removeLast();
        }
        continue;
      }
      parts.add(part);
    }
    return parts.join('/');
  }

  String _normalizeName(String input) {
    return input
        .toLowerCase()
        .replaceAll('.md', '')
        .replaceAll(RegExp(r'^\d+[-_\s]*'), '')
        .replaceAll(RegExp(r'[-_\s]+'), ' ')
        .trim();
  }

  String _folderPathForResolution() {
    if (widget.folderPath != null && widget.folderPath!.trim().isNotEmpty) {
      return _normalizePath(widget.folderPath!);
    }
    return _folderFromPath();
  }

  List<String> _repoPathCandidatesForLink(String href) {
    final cleaned = Uri.decodeComponent(
      href,
    ).split('#').first.split('?').first.trim();
    if (cleaned.isEmpty) {
      return const [];
    }

    final baseFolder = _folderPathForResolution();
    final trimmed = cleaned.startsWith('/') ? cleaned.substring(1) : cleaned;
    final direct = _normalizePath(trimmed);
    final relative = _normalizePath('$baseFolder/$trimmed');
    final rawCandidates = <String>[
      if (cleaned.startsWith('/')) direct else relative,
      direct,
      relative,
    ];

    final expanded = <String>{};
    for (final candidate in rawCandidates) {
      if (candidate.isEmpty) {
        continue;
      }
      expanded.add(candidate);
      if (!candidate.toLowerCase().endsWith('.md')) {
        expanded.add('$candidate.md');
      }
    }
    return expanded.toList();
  }

  Map<String, dynamic>? _matchCachedNoteByPath(
    List<Map<String, dynamic>> files,
    List<String> candidatePaths,
  ) {
    final wanted = candidatePaths.map(_normalizePath).toSet();
    for (final file in files) {
      final path = _normalizePath((file['path'] ?? '').toString());
      if (wanted.contains(path)) {
        return file;
      }
    }
    return null;
  }

  Map<String, dynamic>? _matchCachedNoteByName(
    List<Map<String, dynamic>> files,
    String rawName,
    String? preferredFolder,
  ) {
    final target = _normalizeName(rawName);
    if (target.isEmpty) {
      return null;
    }

    final normalizedPreferredFolder = preferredFolder == null
        ? null
        : _normalizePath(preferredFolder);

    if (normalizedPreferredFolder != null &&
        normalizedPreferredFolder.isNotEmpty) {
      for (final file in files) {
        final folderPath = _normalizePath(
          (file['folder_path'] ?? '').toString(),
        );
        if (folderPath != normalizedPreferredFolder) {
          continue;
        }
        final name = (file['name'] ?? '').toString();
        final path = (file['path'] ?? '').toString();
        final basename = path.split('/').last;
        if (_normalizeName(name) == target ||
            _normalizeName(basename) == target) {
          return file;
        }
      }
    }

    for (final file in files) {
      final name = (file['name'] ?? '').toString();
      final path = (file['path'] ?? '').toString();
      final basename = path.split('/').last;
      if (_normalizeName(name) == target ||
          _normalizeName(basename) == target) {
        return file;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _resolveInternalNote(String href) async {
    final allFiles = await CacheService().getAllFiles();

    if (href.startsWith('wikilink://')) {
      final name = Uri.decodeComponent(
        href.replaceFirst('wikilink://', '').trim(),
      );
      final baseFolder = _folderPathForResolution();
      final localCandidates = <String>[
        '$baseFolder/$name',
        '$baseFolder/$name.md',
        '$baseFolder/${name.replaceAll(' ', '-')}',
        '$baseFolder/${name.replaceAll(' ', '-')}.md',
        '$baseFolder/${name.replaceAll(' ', '_')}',
        '$baseFolder/${name.replaceAll(' ', '_')}.md',
      ].map(_normalizePath).toList();

      final localMatch = _matchCachedNoteByPath(allFiles, localCandidates);
      if (localMatch != null) {
        return localMatch;
      }

      final cachedByName = _matchCachedNoteByName(allFiles, name, baseFolder);
      if (cachedByName != null) {
        return cachedByName;
      }

      return _github.findNoteByName(name);
    }

    final uri = Uri.tryParse(href);
    final hasExternalScheme =
        uri != null &&
        uri.hasScheme &&
        uri.scheme != 'wikilink' &&
        uri.scheme != 'file';
    if (hasExternalScheme) {
      return null;
    }

    final pathCandidates = _repoPathCandidatesForLink(href);
    final pathMatch = _matchCachedNoteByPath(allFiles, pathCandidates);
    if (pathMatch != null) {
      return pathMatch;
    }

    for (final candidate in pathCandidates) {
      final exactMatch = await _github.findNoteByPath(candidate);
      if (exactMatch != null) {
        return exactMatch;
      }
    }

    final cleanedHref = Uri.decodeComponent(
      href,
    ).split('#').first.split('?').first.trim();
    final isPathLike =
        cleanedHref.contains('/') ||
        cleanedHref.toLowerCase().endsWith('.md') ||
        cleanedHref.startsWith('.');
    if (isPathLike) {
      return null;
    }

    final fallbackName = Uri.decodeComponent(
      href,
    ).split('#').first.split('?').first.trim().split('/').last;
    final cachedByName = _matchCachedNoteByName(
      allFiles,
      fallbackName,
      _folderPathForResolution(),
    );
    if (cachedByName != null) {
      return cachedByName;
    }

    return _github.findNoteByName(fallbackName);
  }

  String _folderFromPath() {
    final parts = widget.filePath.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  List<_Segment> _parseSegments(String content) {
    final segments = <_Segment>[];
    final lines = content.split('\n');
    final buffer = StringBuffer();

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final t = line.trim();

      if (t == r'$$') {
        if (buffer.isNotEmpty) {
          segments.add(_segmentMarkdown(buffer.toString().trimRight()));
          buffer.clear();
        }
        final latexLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim() != r'$$') {
          latexLines.add(lines[i]);
          i++;
        }
        segments.add(_segmentLatex(latexLines.join('\n').trim()));
        i++;
        continue;
      }

      if (t.startsWith(r'$$') && t.endsWith(r'$$') && t.length > 4) {
        if (buffer.isNotEmpty) {
          segments.add(_segmentMarkdown(buffer.toString().trimRight()));
          buffer.clear();
        }
        segments.add(_segmentLatex(t.substring(2, t.length - 2).trim()));
        i++;
        continue;
      }

      if (t == '```mermaid') {
        if (buffer.isNotEmpty) {
          segments.add(_segmentMarkdown(buffer.toString().trimRight()));
          buffer.clear();
        }
        final mermaidLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim() != '```') {
          mermaidLines.add(lines[i]);
          i++;
        }
        segments.add(_segmentMermaid(mermaidLines.join('\n').trim()));
        i++;
        continue;
      }

      if (t.startsWith('```')) {
        if (buffer.isNotEmpty) {
          segments.add(_segmentMarkdown(buffer.toString().trimRight()));
          buffer.clear();
        }
        final language = t.substring(3).trim();
        final codeLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim() != '```') {
          codeLines.add(lines[i]);
          i++;
        }
        segments.add(
          _segmentCode(
            codeLines.join('\n'),
            language: language.isEmpty ? null : language,
          ),
        );
        i++;
        continue;
      }

      if (t.startsWith('> [!') && t.contains(']')) {
        if (buffer.isNotEmpty) {
          segments.add(_segmentMarkdown(buffer.toString().trimRight()));
          buffer.clear();
        }
        final typeMatch = RegExp(r'>\s*\[!(\w+)\][-+]?\s*(.*)').firstMatch(t);
        final calloutType = typeMatch?.group(1)?.toUpperCase() ?? 'NOTE';
        final title = typeMatch?.group(2) ?? calloutType;
        final bodyLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          bodyLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        segments.add(_segmentCallout(calloutType, title, bodyLines.join('\n')));
        continue;
      }

      buffer.writeln(line);
      i++;
    }

    if (buffer.isNotEmpty) {
      final s = buffer.toString().trimRight();
      if (s.isNotEmpty) segments.add(_segmentMarkdown(s));
    }

    return segments;
  }

  _Segment _segmentMarkdown(String content) => _Segment.markdown(
    content,
    id: _segmentIdFor(_SegType.markdown, content),
    preview: _segmentPreviewFor(content),
  );

  _Segment _segmentLatex(String content) => _Segment.latex(
    content,
    id: _segmentIdFor(_SegType.latex, content),
    preview: _segmentPreviewFor(content),
  );

  _Segment _segmentMermaid(String content) => _Segment.mermaid(
    content,
    id: _segmentIdFor(_SegType.mermaid, content),
    preview: _segmentPreviewFor(content),
  );

  _Segment _segmentCode(String content, {String? language}) => _Segment.code(
    content,
    language: language,
    id: _segmentIdFor(_SegType.code, content, extra: language ?? ''),
    preview: _segmentPreviewFor(content),
  );

  _Segment _segmentCallout(String type, String title, String body) =>
      _Segment.callout(
        type,
        title,
        body,
        id: _segmentIdFor(_SegType.callout, body, extra: '$type|$title'),
        preview: _segmentPreviewFor(body.isNotEmpty ? body : title),
      );

  String _segmentIdFor(_SegType type, String content, {String extra = ''}) {
    final source = '${type.name}|$extra|${content.trim()}';
    var hash = 2166136261;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return '${type.name}_$hash';
  }

  String _segmentPreviewFor(String raw) {
    final withoutImages = raw.replaceAll(
      RegExp(r'!\[[^\]]*\]\([^)]+\)'),
      '[image]',
    );
    final withoutLinks = withoutImages.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );
    final withoutMarkers = withoutLinks
        .replaceAll(RegExp(r'[`#>*_\-\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (withoutMarkers.isEmpty) {
      return 'Shared note section';
    }
    return withoutMarkers.length > 120
        ? '${withoutMarkers.substring(0, 117)}...'
        : withoutMarkers;
  }

  void _scheduleInitialSegmentReveal() {
    final targetId = widget.initialSegmentId;
    if (targetId == null || targetId.isEmpty || _didScrollToInitialSegment) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _didScrollToInitialSegment) {
        return;
      }
      final key = _segmentKeys[targetId];
      final context = key?.currentContext;
      if (context == null) {
        return;
      }
      _didScrollToInitialSegment = true;
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  Future<void> _shareSegment(_Segment segment) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: U.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ShareNoteSheet(
          currentUid: currentUid,
          noteTitle: widget.title,
          segmentPreview: segment.preview,
          chatService: _chatService,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await _chatService.sendNoteShare(
        otherUserId: result['uid'].toString(),
        noteTitle: widget.title,
        filePath: widget.filePath,
        folderPath: widget.folderPath,
        segmentId: segment.id,
        segmentPreview: segment.preview,
        segmentType: segment.type.name,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: U.primary,
          content: Text(
            'Shared with ${(result['displayName'] ?? 'friend').toString()}',
            style: GoogleFonts.outfit(color: U.bg),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: U.red,
          content: Text(
            'Could not share note section',
            style: GoogleFonts.outfit(color: U.bg),
          ),
        ),
      );
    }
  }

  Widget _shareableSegment(_Segment segment, Widget child) {
    final key = _segmentKeys.putIfAbsent(segment.id, GlobalKey.new);
    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _shareSegment(segment),
        child: child,
      ),
    );
  }

  Widget _buildSegment(_Segment seg) {
    switch (seg.type) {
      case _SegType.latex:
        return _LatexBlock(latex: seg.content);
      case _SegType.mermaid:
        return _MermaidBlock(code: seg.content);
      case _SegType.code:
        return _CodeFenceBlock(code: seg.content, language: seg.language);
      case _SegType.callout:
        return _CalloutBlock(
          type: seg.calloutType!,
          title: seg.title!,
          body: seg.content,
          onTapLink: _handleLink,
          folderPath: _folderPathForResolution(),
          notePath: widget.filePath,
        );
      case _SegType.markdown:
        return _buildMarkdown(seg.content);
    }
  }

  Future<void> _handleLink(String href) async {
    final resolvedNote = await _resolveInternalNote(href);
    if (resolvedNote != null) {
      if (!mounted) {
        return;
      }
      final resolvedPath = (resolvedNote['path'] ?? '').toString();
      final resolvedFolder = (resolvedNote['folder_path'] ?? '').toString();
      final resolvedTitle = (resolvedNote['name'] ?? '').toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteViewerScreen(
            title: resolvedTitle.isEmpty ? widget.title : resolvedTitle,
            filePath: resolvedPath,
            folderPath: resolvedFolder,
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open link', style: GoogleFonts.outfit()),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  Widget _buildMarkdown(String content) {
    return _InlineMathMarkdown(
      data: content,
      onTapLink: _handleLink,
      folderPath: _folderPathForResolution(),
      notePath: widget.filePath,
    );
  }

  int _contentItemCount() {
    var count = _segments.length;
    if (_noteFiles.isNotEmpty) {
      count += _noteFiles.length + 2;
    }
    if (_assignmentFiles.isNotEmpty) {
      count += _assignmentFiles.length + 2;
    }
    if (_noteFiles.isNotEmpty || _assignmentFiles.isNotEmpty) {
      count += 1;
    }
    return count;
  }

  Widget _buildContentItem(int index) {
    var cursor = index;

    if (_noteFiles.isNotEmpty) {
      if (cursor == 0) {
        return const _SecLabel('NOTES');
      }
      cursor -= 1;

      if (cursor < _noteFiles.length) {
        return _FileBar(file: _noteFiles[cursor]);
      }
      cursor -= _noteFiles.length;

      if (cursor == 0) {
        return const SizedBox(height: 4);
      }
      cursor -= 1;
    }

    if (_assignmentFiles.isNotEmpty) {
      if (cursor == 0) {
        return const _SecLabel('ASSIGNMENTS');
      }
      cursor -= 1;

      if (cursor < _assignmentFiles.length) {
        return _FileBar(file: _assignmentFiles[cursor]);
      }
      cursor -= _assignmentFiles.length;

      if (cursor == 0) {
        return const SizedBox(height: 4);
      }
      cursor -= 1;
    }

    if (_noteFiles.isNotEmpty || _assignmentFiles.isNotEmpty) {
      if (cursor == 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(color: U.border, thickness: 0.5),
        );
      }
      cursor -= 1;
    }

    final segment = _segments[cursor];
    return _shareableSegment(segment, _buildSegment(segment));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: U.sub,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: U.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isEditable && (widget.filePath.contains('/Community/') || _isWriter))
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
                              title: widget.title,
                              filePath: widget.filePath,
                              initialContent: _rawContent,
                            ),
                          ),
                        );
                        if (result is String) {
                          setState(() {
                            _rawContent = result;
                            _segments = _parseSegments(result);
                            _loading = false;
                          });
                        } else if (result == true) {
                          _load();
                        }
                      },
                    ),
                ],
              ),
            ),
            Divider(color: U.border, height: 1, thickness: 0.5),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: U.primary,
                        strokeWidth: 1.5,
                      ),
                    )
                  : RefreshIndicator(
                      color: U.primary,
                      backgroundColor: U.card,
                      onRefresh: () async {
                        setState(() => _loading = true);
                        await _load();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                        itemCount: _contentItemCount(),
                        itemBuilder: (context, index) =>
                            _buildContentItem(index),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SegType { markdown, latex, mermaid, callout, code }

class _Segment {
  final _SegType type;
  final String content;
  final String id;
  final String preview;
  final String? calloutType;
  final String? title;
  final String? language;
  _Segment._(
    this.type,
    this.content, {
    required this.id,
    required this.preview,
    this.calloutType,
    this.title,
    this.language,
  });
  factory _Segment.markdown(
    String c, {
    required String id,
    required String preview,
  }) => _Segment._(_SegType.markdown, c, id: id, preview: preview);
  factory _Segment.latex(
    String c, {
    required String id,
    required String preview,
  }) => _Segment._(_SegType.latex, c, id: id, preview: preview);
  factory _Segment.mermaid(
    String c, {
    required String id,
    required String preview,
  }) => _Segment._(_SegType.mermaid, c, id: id, preview: preview);
  factory _Segment.code(
    String c, {
    String? language,
    required String id,
    required String preview,
  }) => _Segment._(
    _SegType.code,
    c,
    language: language,
    id: id,
    preview: preview,
  );
  factory _Segment.callout(
    String type,
    String title,
    String body, {
    required String id,
    required String preview,
  }) => _Segment._(
    _SegType.callout,
    body,
    calloutType: type,
    title: title,
    id: id,
    preview: preview,
  );
}

class _ShareNoteSheet extends StatefulWidget {
  const _ShareNoteSheet({
    required this.currentUid,
    required this.noteTitle,
    required this.segmentPreview,
    required this.chatService,
  });

  final String currentUid;
  final String noteTitle;
  final String segmentPreview;
  final ChatService chatService;

  @override
  State<_ShareNoteSheet> createState() => _ShareNoteSheetState();
}

class _ShareNoteSheetState extends State<_ShareNoteSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<Map<String, int>> _recentRanksStream;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _usersStream = widget.chatService.usersStream();
    _recentRanksStream = widget.chatService.recentChatRanksStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: U.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Share section',
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.noteTitle,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.segmentPreview,
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 12,
                      height: 1.45,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search_rounded, color: U.sub),
                  hintText: 'Share with...',
                  hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: StreamBuilder<Map<String, int>>(
                stream: _recentRanksStream,
                builder: (context, rankSnapshot) {
                  final ranks = rankSnapshot.data ?? const <String, int>{};
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _usersStream,
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                              color: U.primary,
                              strokeWidth: 1.6,
                            ),
                          ),
                        );
                      }

                      final users =
                          userSnapshot.data?.docs
                              .map((doc) => {'uid': doc.id, ...doc.data()})
                              .where((user) => user['uid'] != widget.currentUid)
                              .where((user) {
                                if (_query.isEmpty) {
                                  return true;
                                }
                                final name = (user['displayName'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final email = (user['email'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return name.contains(_query) ||
                                    email.contains(_query);
                              })
                              .toList() ??
                          <Map<String, dynamic>>[];

                      users.sort((a, b) {
                        final rankA = ranks[a['uid'].toString()];
                        final rankB = ranks[b['uid'].toString()];
                        if (rankA != null && rankB != null) {
                          return rankA.compareTo(rankB);
                        }
                        if (rankA != null) {
                          return -1;
                        }
                        if (rankB != null) {
                          return 1;
                        }
                        return (a['displayName'] ?? '')
                            .toString()
                            .toLowerCase()
                            .compareTo(
                              (b['displayName'] ?? '').toString().toLowerCase(),
                            );
                      });

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: users.length,
                        separatorBuilder: (context, index) => Divider(
                          color: U.border,
                          height: 1,
                          thickness: 0.5,
                          indent: 56,
                        ),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final displayName = (user['displayName'] ?? 'Friend')
                              .toString();
                          final email = (user['email'] ?? '').toString();
                          final photoUrl = user['photoUrl']?.toString();
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(user),
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: U.primary.withValues(
                                alpha: 0.16,
                              ),
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null || photoUrl.isEmpty
                                  ? Text(
                                      displayName.isEmpty
                                          ? 'U'
                                          : displayName[0].toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: U.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                color: U.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: GoogleFonts.outfit(
                                color: U.sub,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              Icons.send_rounded,
                              color: U.primary,
                              size: 18,
                            ),
                          );
                        },
                      );
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
}

class _InlineMathMarkdown extends StatelessWidget {
  final String data;
  final Future<void> Function(String href) onTapLink;
  final String folderPath;
  final String notePath;
  const _InlineMathMarkdown({
    required this.data,
    required this.onTapLink,
    required this.folderPath,
    required this.notePath,
  });

  @override
  Widget build(BuildContext context) {
    // Only use fast path when there's no inline latex to process
    // Otherwise, process inline latex even with structured markdown
    if (!data.contains(r'$')) {
      return _MarkdownChunk(
        data: data,
        onTapLink: onTapLink,
        folderPath: folderPath,
        notePath: notePath,
      );
    }

    final parts = <InlineSpan>[];
    final pattern = RegExp(r'\$([^\$\n]+?)\$');
    int last = 0;

    for (final match in pattern.allMatches(data)) {
      if (match.start > last) {
        parts.add(
          WidgetSpan(
            child: _MarkdownChunk(
              data: data.substring(last, match.start),
              onTapLink: onTapLink,
              folderPath: folderPath,
              notePath: notePath,
            ),
          ),
        );
      }
      parts.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Math.tex(
            match.group(1)!,
            textStyle: TextStyle(color: U.text, fontSize: 15),
            onErrorFallback: (e) => Text(
              '\$${match.group(1)}\$',
              style: GoogleFonts.sourceCodePro(color: U.red, fontSize: 13),
            ),
          ),
        ),
      );
      last = match.end;
    }

    if (last < data.length) {
      parts.add(
        WidgetSpan(
          child: _MarkdownChunk(
            data: data.substring(last),
            onTapLink: onTapLink,
            folderPath: folderPath,
            notePath: notePath,
          ),
        ),
      );
    }

    if (parts.isEmpty) {
      return _MarkdownChunk(
        data: data,
        onTapLink: onTapLink,
        folderPath: folderPath,
        notePath: notePath,
      );
    }

    final hasMath = parts.any((p) => p is WidgetSpan && p.child is Math);
    if (!hasMath) {
      return _MarkdownChunk(
        data: data,
        onTapLink: onTapLink,
        folderPath: folderPath,
        notePath: notePath,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((p) {
        if (p is WidgetSpan) return p.child;
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  bool _hasStructuredMarkdown(String value) {
    if (value.contains(r'$$')) return true;
    for (final rawLine in value.split('\n')) {
      final line = rawLine.trimLeft();
      if (line.isEmpty) continue;
      if (line.startsWith('```')) return true;
      if (line.startsWith('> ')) return true;
      if (line.startsWith('|')) return true;
      if (RegExp(r'^#{1,6}\s').hasMatch(line)) return true;
      if (RegExp(r'^\d+\.\s').hasMatch(line)) return true;
    }
    return false;
  }
}

class _MarkdownChunk extends StatelessWidget {
  final String data;
  final Future<void> Function(String href) onTapLink;
  final String folderPath;
  final String notePath;
  const _MarkdownChunk({
    required this.data,
    required this.onTapLink,
    required this.folderPath,
    required this.notePath,
  });

  @override
  Widget build(BuildContext context) {
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final fencedCode = _parseFencedCodeBlock(data);
    if (fencedCode != null) {
      return _CodeFenceBlock(language: fencedCode.$1, code: fencedCode.$2);
    }

    return MarkdownBody(
      data: data,
      builders: {'pre': _CodeBlockBuilder(), 'input': _TaskListBuilder()},
      sizedImageBuilder: (config) => _CachedImage(
        src: config.uri.toString(),
        folderPath: folderPath,
        notePath: notePath,
        alt: config.alt,
      ),
      onTapLink: (text, href, title) {
        if (href != null) onTapLink(href);
      },
      styleSheet: MarkdownStyleSheet(
        h1: GoogleFonts.outfit(
          color: U.mdH1,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        h2: GoogleFonts.outfit(
          color: U.mdH2,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        h3: GoogleFonts.outfit(
          color: U.mdH3,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        h4: GoogleFonts.outfit(
          color: U.sub,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        h5: GoogleFonts.outfit(
          color: U.sub,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        h6: GoogleFonts.outfit(
          color: U.dim,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        p: GoogleFonts.outfit(color: U.text, fontSize: 15, height: 1.75),
        strong: GoogleFonts.outfit(
          color: U.mdBold,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        em: GoogleFonts.outfit(
          color: U.mdItalic,
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
        code: GoogleFonts.sourceCodePro(
          color: U.mdCode,
          backgroundColor: U.card,
          fontSize: 13,
        ),
        codeblockDecoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: U.border),
        ),
        codeblockPadding: const EdgeInsets.all(14),
        blockquote: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: U.mdBlockquote, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        listBullet: GoogleFonts.outfit(color: U.sub, fontSize: 15),
        a: GoogleFonts.outfit(
          color: U.mdLink,
          fontSize: 15,
          decoration: TextDecoration.underline,
          decorationColor: U.mdLink.withValues(alpha: 0.4),
        ),
        tableHead: GoogleFonts.outfit(
          color: U.text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tableBody: GoogleFonts.outfit(color: U.sub, fontSize: 13),
        tableBorder: TableBorder.all(color: U.border, width: 0.5),
        del: GoogleFonts.outfit(
          color: U.mdDel,
          decoration: TextDecoration.lineThrough,
          decorationColor: U.mdDel.withValues(alpha: 0.5),
          fontSize: 15,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: U.border, width: 1)),
        ),
      ),
    );
  }

  (String?, String)? _parseFencedCodeBlock(String value) {
    final trimmed = value.trim();
    final match = RegExp(
      r'^```([^\n`]*)\n([\s\S]*?)\n```$',
    ).firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final language = match.group(1)?.trim();
    final code = match.group(2) ?? '';
    return (language == null || language.isEmpty ? null : language, code);
  }
}

class _LatexBlock extends StatelessWidget {
  final String latex;
  const _LatexBlock({required this.latex});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: U.border),
      ),
      child: Center(
        child: Math.tex(
          latex,
          textStyle: TextStyle(color: U.text, fontSize: 17),
          onErrorFallback: (e) => SelectableText(
            latex,
            style: GoogleFonts.sourceCodePro(color: U.red, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _MermaidBlock extends StatefulWidget {
  final String code;
  const _MermaidBlock({required this.code});

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> {
  WebViewController? _controller;
  double _height = 200;

  @override
  void initState() {
    super.initState();
    if (!PlatformSupport.supportsEmbeddedWebView) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          final h = double.tryParse(msg.message);
          if (h != null && mounted) {
            setState(() => _height = h + 24);
          }
        },
      )
      ..loadHtmlString(_buildHtml(widget.code));
  }

  String _buildHtml(String code) {
    final escaped = const HtmlEscape().convert(code);
    final bgHex = U.mermaidBackground.replaceAll('#', '');
    final primaryHex = U.mermaidPrimary.replaceAll('#', '');
    final lineHex = U.mermaidLine.replaceAll('#', '');
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #${bgHex};
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 12px;
    min-height: 100vh;
  }
  .mermaid {
    width: 100%;
    max-width: 100%;
  }
  .mermaid svg {
    max-width: 100%;
    height: auto;
  }
</style>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: true,
    theme: 'dark',
    themeVariables: {
      primaryColor: '#${primaryHex}',
      primaryTextColor: '#CDD6F4',
      primaryBorderColor: '#45475A',
      lineColor: '#${lineHex}',
      secondaryColor: '#${bgHex}',
      tertiaryColor: '#${bgHex}',
      background: '#${bgHex}',
      mainBkg: '#${primaryHex}',
      nodeBorder: '#${lineHex}',
      clusterBkg: '#${bgHex}',
      titleColor: '#CDD6F4',
      edgeLabelBackground: '#${bgHex}',
      fontFamily: 'sans-serif',
    }
  });
  window.addEventListener('load', () => {
    setTimeout(() => {
      const el = document.querySelector('.mermaid svg');
      if (el) {
        FlutterChannel.postMessage(el.getBoundingClientRect().height.toString());
      }
    }, 800);
  });
</script>
</head>
<body>
<div class="mermaid">
$escaped
</div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mermaid preview is unavailable on this platform.',
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              widget.code,
              style: GoogleFonts.sourceCodePro(
                color: U.text,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: _height,
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: WebViewWidget(controller: _controller!),
    );
  }
}

class _CalloutBlock extends StatelessWidget {
  final String type;
  final String title;
  final String body;
  final Future<void> Function(String) onTapLink;
  final String folderPath;
  final String notePath;
  const _CalloutBlock({
    required this.type,
    required this.title,
    required this.body,
    required this.onTapLink,
    required this.folderPath,
    required this.notePath,
  });

  static final _calloutStyles = {
    'NOTE': (Icons.info_outline, U.blue),
    'INFO': (Icons.info_outline, U.blue),
    'TIP': (Icons.lightbulb_outline, U.green),
    'SUCCESS': (Icons.check_circle_outline, U.green),
    'DONE': (Icons.check_circle_outline, U.green),
    'WARNING': (Icons.warning_amber_outlined, U.gold),
    'CAUTION': (Icons.warning_amber_outlined, U.gold),
    'ATTENTION': (Icons.warning_amber_outlined, U.gold),
    'DANGER': (Icons.error_outline, U.red),
    'ERROR': (Icons.error_outline, U.red),
    'BUG': (Icons.bug_report_outlined, U.red),
    'QUESTION': (Icons.help_outline, U.primary),
    'ABSTRACT': (Icons.summarize_outlined, U.teal),
    'SUMMARY': (Icons.summarize_outlined, U.teal),
    'EXAMPLE': (Icons.code_outlined, U.peach),
    'QUOTE': (Icons.format_quote_outlined, U.gray),
    'CITE': (Icons.format_quote_outlined, U.gray),
  };

  @override
  Widget build(BuildContext context) {
    final style =
        _calloutStyles[type] ?? (Icons.info_outline, const Color(0xFF89B4FA));
    final icon = style.$1;
    final color = style.$2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: color.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title.isEmpty ? type : title,
                  style: GoogleFonts.outfit(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (body.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: MarkdownBody(
                data: body,
                builders: {'pre': _CodeBlockBuilder()},
                sizedImageBuilder: (config) => _CachedImage(
                  src: config.uri.toString(),
                  folderPath: folderPath,
                  notePath: notePath,
                  alt: config.alt,
                ),
                onTapLink: (text, href, title) {
                  if (href != null) onTapLink(href);
                },
                styleSheet: MarkdownStyleSheet(
                  p: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  strong: GoogleFonts.outfit(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                  a: GoogleFonts.outfit(
                    color: U.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeElement = element.children != null && element.children!.isNotEmpty
        ? element.children!.first
        : null;
    final languageClass = codeElement is md.Element
        ? codeElement.attributes['class']
        : null;
    final language =
        languageClass != null && languageClass.startsWith('language-')
        ? languageClass.substring('language-'.length)
        : null;
    final code = element.textContent;

    final highlighter = _CodeSyntaxHighlighter(
      baseStyle: GoogleFonts.sourceCodePro(
        color: U.text,
        fontSize: 13,
        height: 1.5,
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: U.border),
      ),
      child: SelectableText.rich(highlighter.format(code, language: language)),
    );
  }
}

class _TaskListBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final isChecked = element.attributes['checked'] != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Icon(
        isChecked ? Icons.check_box : Icons.check_box_outline_blank,
        color: isChecked ? U.green : U.dim,
        size: 18,
      ),
    );
  }
}

class _CodeFenceBlock extends StatelessWidget {
  const _CodeFenceBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final highlighter = _CodeSyntaxHighlighter(
      baseStyle: GoogleFonts.sourceCodePro(
        color: U.text,
        fontSize: 13,
        height: 1.5,
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: U.border),
      ),
      child: SelectableText.rich(highlighter.format(code, language: language)),
    );
  }
}

class _CodeSyntaxHighlighter {
  _CodeSyntaxHighlighter({required this.baseStyle});

  final TextStyle baseStyle;

  static Color get keywordColor => U.primary;
  static Color get typeColor => U.blue;
  static Color get stringColor => U.green;
  static Color get numberColor => U.peach;
  static Color get commentColor => U.dim;
  static Color get annotationColor => U.teal;
  static Color get operatorColor => U.red;
  static Color get propertyColor => U.gold;

  static const Map<String, Set<String>> _keywordsByLanguage = {
    'dart': {
      'abstract',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'covariant',
      'default',
      'deferred',
      'do',
      'dynamic',
      'else',
      'enum',
      'export',
      'extends',
      'extension',
      'external',
      'factory',
      'false',
      'final',
      'finally',
      'for',
      'function',
      'get',
      'hide',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'is',
      'late',
      'library',
      'mixin',
      'new',
      'null',
      'on',
      'operator',
      'part',
      'required',
      'rethrow',
      'return',
      'set',
      'show',
      'static',
      'super',
      'switch',
      'sync',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'var',
      'void',
      'while',
      'with',
      'yield',
    },
    'javascript': {
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'function',
      'if',
      'import',
      'in',
      'instanceof',
      'let',
      'new',
      'null',
      'return',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typeof',
      'var',
      'void',
      'while',
      'yield',
    },
    'js': {
      'await',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'default',
      'delete',
      'do',
      'else',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'function',
      'if',
      'import',
      'in',
      'instanceof',
      'let',
      'new',
      'null',
      'return',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typeof',
      'var',
      'void',
      'while',
      'yield',
    },
    'typescript': {
      'abstract',
      'any',
      'as',
      'async',
      'await',
      'boolean',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'declare',
      'default',
      'do',
      'else',
      'enum',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'keyof',
      'let',
      'module',
      'namespace',
      'never',
      'new',
      'null',
      'number',
      'private',
      'protected',
      'public',
      'readonly',
      'return',
      'static',
      'string',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'type',
      'typeof',
      'undefined',
      'var',
      'void',
      'while',
    },
    'ts': {
      'abstract',
      'any',
      'as',
      'async',
      'await',
      'boolean',
      'break',
      'case',
      'catch',
      'class',
      'const',
      'continue',
      'declare',
      'default',
      'do',
      'else',
      'enum',
      'export',
      'extends',
      'false',
      'finally',
      'for',
      'from',
      'function',
      'if',
      'implements',
      'import',
      'in',
      'interface',
      'keyof',
      'let',
      'module',
      'namespace',
      'never',
      'new',
      'null',
      'number',
      'private',
      'protected',
      'public',
      'readonly',
      'return',
      'static',
      'string',
      'super',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'type',
      'typeof',
      'undefined',
      'var',
      'void',
      'while',
    },
    'python': {
      'and',
      'as',
      'assert',
      'async',
      'await',
      'break',
      'class',
      'continue',
      'def',
      'del',
      'elif',
      'else',
      'except',
      'False',
      'finally',
      'for',
      'from',
      'global',
      'if',
      'import',
      'in',
      'is',
      'lambda',
      'None',
      'nonlocal',
      'not',
      'or',
      'pass',
      'raise',
      'return',
      'True',
      'try',
      'while',
      'with',
      'yield',
    },
    'java': {
      'abstract',
      'assert',
      'boolean',
      'break',
      'byte',
      'case',
      'catch',
      'char',
      'class',
      'const',
      'continue',
      'default',
      'do',
      'double',
      'else',
      'enum',
      'extends',
      'false',
      'final',
      'finally',
      'float',
      'for',
      'if',
      'implements',
      'import',
      'instanceof',
      'int',
      'interface',
      'long',
      'native',
      'new',
      'null',
      'package',
      'private',
      'protected',
      'public',
      'return',
      'short',
      'static',
      'super',
      'switch',
      'this',
      'throw',
      'throws',
      'true',
      'try',
      'void',
      'volatile',
      'while',
    },
    'c': {
      'auto',
      'break',
      'case',
      'char',
      'const',
      'continue',
      'default',
      'do',
      'double',
      'else',
      'enum',
      'extern',
      'float',
      'for',
      'goto',
      'if',
      'inline',
      'int',
      'long',
      'register',
      'restrict',
      'return',
      'short',
      'signed',
      'sizeof',
      'static',
      'struct',
      'switch',
      'typedef',
      'union',
      'unsigned',
      'void',
      'volatile',
      'while',
    },
    'cpp': {
      'alignas',
      'alignof',
      'auto',
      'bool',
      'break',
      'case',
      'catch',
      'char',
      'class',
      'const',
      'constexpr',
      'continue',
      'default',
      'delete',
      'do',
      'double',
      'else',
      'enum',
      'explicit',
      'export',
      'extern',
      'false',
      'float',
      'for',
      'friend',
      'goto',
      'if',
      'inline',
      'int',
      'long',
      'mutable',
      'namespace',
      'new',
      'noexcept',
      'nullptr',
      'operator',
      'private',
      'protected',
      'public',
      'register',
      'return',
      'short',
      'signed',
      'sizeof',
      'static',
      'struct',
      'switch',
      'template',
      'this',
      'throw',
      'true',
      'try',
      'typedef',
      'typename',
      'union',
      'unsigned',
      'using',
      'virtual',
      'void',
      'volatile',
      'while',
    },
    'csharp': {
      'abstract',
      'as',
      'base',
      'bool',
      'break',
      'byte',
      'case',
      'catch',
      'char',
      'checked',
      'class',
      'const',
      'continue',
      'decimal',
      'default',
      'delegate',
      'do',
      'double',
      'else',
      'enum',
      'event',
      'explicit',
      'extern',
      'false',
      'finally',
      'fixed',
      'float',
      'for',
      'foreach',
      'if',
      'implicit',
      'in',
      'int',
      'interface',
      'internal',
      'is',
      'lock',
      'long',
      'namespace',
      'new',
      'null',
      'object',
      'operator',
      'out',
      'override',
      'params',
      'private',
      'protected',
      'public',
      'readonly',
      'ref',
      'return',
      'sbyte',
      'sealed',
      'short',
      'sizeof',
      'stackalloc',
      'static',
      'string',
      'struct',
      'switch',
      'this',
      'throw',
      'true',
      'try',
      'typeof',
      'uint',
      'ulong',
      'unchecked',
      'unsafe',
      'ushort',
      'using',
      'virtual',
      'void',
      'while',
    },
    'json': {'true', 'false', 'null'},
    'yaml': {'true', 'false', 'null', 'yes', 'no', 'on', 'off'},
    'html': {
      'html',
      'head',
      'body',
      'div',
      'span',
      'script',
      'style',
      'meta',
      'link',
      'title',
      'section',
      'article',
      'header',
      'footer',
      'main',
      'nav',
      'img',
      'a',
      'p',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    },
    'css': {
      'display',
      'position',
      'color',
      'background',
      'font',
      'padding',
      'margin',
      'border',
      'flex',
      'grid',
      'absolute',
      'relative',
      'fixed',
      'block',
      'inline',
      'none',
    },
    'bash': {
      'if',
      'then',
      'else',
      'elif',
      'fi',
      'for',
      'in',
      'do',
      'done',
      'case',
      'esac',
      'while',
      'function',
      'return',
      'local',
      'export',
    },
    'sh': {
      'if',
      'then',
      'else',
      'elif',
      'fi',
      'for',
      'in',
      'do',
      'done',
      'case',
      'esac',
      'while',
      'function',
      'return',
      'local',
      'export',
    },
    'sql': {
      'select',
      'from',
      'where',
      'insert',
      'into',
      'update',
      'delete',
      'join',
      'left',
      'right',
      'inner',
      'outer',
      'group',
      'by',
      'order',
      'limit',
      'having',
      'as',
      'on',
      'and',
      'or',
      'not',
      'null',
      'create',
      'table',
      'alter',
      'drop',
      'distinct',
      'values',
    },
  };

  static const Map<String, String> _aliases = {
    'node': 'javascript',
    'jsx': 'javascript',
    'tsx': 'typescript',
    'py': 'python',
    'kt': 'java',
    'kts': 'java',
    'cs': 'csharp',
    'c#': 'csharp',
    'shell': 'bash',
    'zsh': 'bash',
    'yml': 'yaml',
    'htm': 'html',
  };

  TextSpan format(String source, {String? language}) {
    final resolvedLanguage = _normalizeLanguage(language);
    final spans = <TextSpan>[];
    var index = 0;

    while (index < source.length) {
      final comment = _matchComment(source, index, resolvedLanguage);
      if (comment != null) {
        spans.add(_span(comment, commentColor));
        index += comment.length;
        continue;
      }

      final string = _matchString(source, index);
      if (string != null) {
        spans.add(_span(string, stringColor));
        index += string.length;
        continue;
      }

      final annotation = _matchAnnotation(source, index, resolvedLanguage);
      if (annotation != null) {
        spans.add(_span(annotation, annotationColor));
        index += annotation.length;
        continue;
      }

      final number = _matchNumber(source, index);
      if (number != null) {
        spans.add(_span(number, numberColor));
        index += number.length;
        continue;
      }

      final identifier = _matchIdentifier(source, index);
      if (identifier != null) {
        spans.add(_styleIdentifier(identifier, resolvedLanguage));
        index += identifier.length;
        continue;
      }

      final operator = _matchOperator(source, index);
      if (operator != null) {
        spans.add(_span(operator, operatorColor));
        index += operator.length;
        continue;
      }

      spans.add(_span(source[index], null));
      index++;
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  String _normalizeLanguage(String? language) {
    if (language == null || language.trim().isEmpty) {
      return '';
    }
    final lower = language.trim().toLowerCase();
    return _aliases[lower] ?? lower;
  }

  TextSpan _styleIdentifier(String identifier, String language) {
    final keywords = _keywordsByLanguage[language] ?? const <String>{};
    if (keywords.contains(identifier) ||
        keywords.contains(identifier.toLowerCase())) {
      return _span(identifier, keywordColor, FontWeight.w700);
    }

    final propertyLike =
        language == 'json' &&
        identifier.isNotEmpty &&
        identifier != 'true' &&
        identifier != 'false' &&
        identifier != 'null';
    if (propertyLike) {
      return _span(identifier, propertyColor);
    }

    final startsUppercase =
        identifier.isNotEmpty &&
        identifier[0].toUpperCase() == identifier[0] &&
        identifier[0].toLowerCase() != identifier[0];
    if (startsUppercase) {
      return _span(identifier, typeColor);
    }

    return _span(identifier, null);
  }

  TextSpan _span(String text, Color? color, [FontWeight? weight]) {
    return TextSpan(
      text: text,
      style: baseStyle.copyWith(
        color: color ?? baseStyle.color,
        fontWeight: weight ?? baseStyle.fontWeight,
      ),
    );
  }

  String? _matchComment(String source, int index, String language) {
    if (language == 'python' ||
        language == 'yaml' ||
        language == 'bash' ||
        language == 'sh') {
      if (source.startsWith('#', index)) {
        final end = source.indexOf('\n', index);
        return end == -1
            ? source.substring(index)
            : source.substring(index, end);
      }
    }

    if (source.startsWith('//', index) ||
        (language == 'sql' && source.startsWith('--', index))) {
      final end = source.indexOf('\n', index);
      return end == -1 ? source.substring(index) : source.substring(index, end);
    }

    if (source.startsWith('/*', index)) {
      final end = source.indexOf('*/', index + 2);
      return end == -1
          ? source.substring(index)
          : source.substring(index, end + 2);
    }

    return null;
  }

  String? _matchString(String source, int index) {
    final quote = source[index];
    if (quote != '\'' && quote != '"' && quote != '`') {
      return null;
    }

    var i = index + 1;
    var escaped = false;
    while (i < source.length) {
      final char = source[i];
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == quote) {
        return source.substring(index, i + 1);
      }
      i++;
    }
    return source.substring(index);
  }

  String? _matchAnnotation(String source, int index, String language) {
    final isAnnotationLanguage =
        language == 'dart' ||
        language == 'java' ||
        language == 'csharp' ||
        language == 'python';
    if (!isAnnotationLanguage || source[index] != '@') {
      return null;
    }

    var end = index + 1;
    while (end < source.length && _isIdentifierChar(source.codeUnitAt(end))) {
      end++;
    }
    return source.substring(index, end);
  }

  String? _matchNumber(String source, int index) {
    final char = source[index];
    if (!_isDigit(char.codeUnitAt(0))) {
      return null;
    }

    var end = index + 1;
    while (end < source.length) {
      final codeUnit = source.codeUnitAt(end);
      if (_isDigit(codeUnit) ||
          source[end] == '.' ||
          source[end].toLowerCase() == 'x') {
        end++;
      } else {
        break;
      }
    }
    return source.substring(index, end);
  }

  String? _matchIdentifier(String source, int index) {
    final codeUnit = source.codeUnitAt(index);
    if (!_isIdentifierStart(codeUnit)) {
      return null;
    }

    var end = index + 1;
    while (end < source.length && _isIdentifierChar(source.codeUnitAt(end))) {
      end++;
    }
    return source.substring(index, end);
  }

  String? _matchOperator(String source, int index) {
    const operators = [
      '=>',
      '==',
      '!=',
      '<=',
      '>=',
      '&&',
      '||',
      '??',
      '?.',
      '::',
      '+=',
      '-=',
      '*=',
      '/=',
      '%=',
      '=',
      '+',
      '-',
      '*',
      '/',
      '%',
      '<',
      '>',
      '!',
      '&',
      '|',
      '^',
      '~',
      '?',
      ':',
    ];
    for (final operator in operators) {
      if (source.startsWith(operator, index)) {
        return operator;
      }
    }
    return null;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  bool _isIdentifierStart(int codeUnit) =>
      (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122) ||
      codeUnit == 95;

  bool _isIdentifierChar(int codeUnit) =>
      _isIdentifierStart(codeUnit) || _isDigit(codeUnit);
}

class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: U.sub,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _FileBar extends StatefulWidget {
  final Map<String, dynamic> file;
  const _FileBar({required this.file});

  @override
  State<_FileBar> createState() => _FileBarState();
}

class _FileBarState extends State<_FileBar> {
  final _cache = FileCacheService();
  bool _cached = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _cache.isCached(widget.file['url'] ?? '').then((v) {
      if (mounted) setState(() => _cached = v);
    });
  }

  Future<void> _tap() async {
    final url = widget.file['url'] ?? '';
    if (url.isEmpty) return;
    if (_cached) {
      final path = await _cache.getCachedPath(url);
      if (path != null) {
        await OpenFilex.open(path);
        return;
      }
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final path = await _cache.downloadFile(
      url,
      onProgress: (r, t) {
        if (t > 0 && mounted) setState(() => _progress = r / t);
      },
    );
    if (mounted) {
      setState(() => _downloading = false);
      if (path != null) {
        setState(() => _cached = true);
        await OpenFilex.open(path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed', style: GoogleFonts.outfit()),
            backgroundColor: U.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = U.red;
    return GestureDetector(
      onTap: _tap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _cached ? color.withValues(alpha: 0.35) : U.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.picture_as_pdf_outlined,
                color: color,
                size: 17,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file['name'] ?? '',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_downloading)
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: U.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(2),
                    )
                  else
                    Text(
                      _cached ? 'Saved offline' : 'Tap to download',
                      style: GoogleFonts.outfit(
                        color: _cached ? color : U.dim,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _downloading
                  ? Icons.hourglass_empty_outlined
                  : _cached
                  ? Icons.check_circle_outline
                  : Icons.download_outlined,
              color: _cached ? color : U.dim,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedImage extends StatefulWidget {
  final String src;
  final String folderPath;
  final String notePath;
  final String? alt;

  const _CachedImage({
    required this.src,
    required this.folderPath,
    required this.notePath,
    this.alt,
  });

  @override
  State<_CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<_CachedImage> {
  final _github = GitHubService();
  final _cache = FileCacheService();
  String? _localPath;
  String? _networkUrl;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final repoImagePath = await _github.getOrFetchRepoImage(
        widget.src,
        noteFolderPath: widget.folderPath,
        notePath: widget.notePath,
      );

      if (repoImagePath != null &&
          repoImagePath.isNotEmpty &&
          await File(repoImagePath).exists()) {
        if (mounted) {
          setState(() {
            _localPath = repoImagePath;
            _loading = false;
          });
        }
        return;
      }

      final url = await _github.resolveImageUrl(
        widget.src,
        noteFolderPath: widget.folderPath,
        notePath: widget.notePath,
      );

      if (url == null || url.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = true;
          });
        }
        return;
      }

      _networkUrl = url;

      final cached = await _cache.getCachedImagePath(url);
      if (cached != null && await File(cached).exists()) {
        if (mounted) {
          setState(() {
            _localPath = cached;
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      final path = await _cache.downloadFile(url);
      if (path != null) {
        final healedPath = await _cache.getCachedImagePath(url);
        if (healedPath != null && mounted) {
          setState(() {
            _localPath = healedPath;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: U.primary,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }

    if (_error) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: U.dim, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.alt ?? 'Image not found',
                style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    final imageWidget = _localPath != null
        ? Image.file(
            File(_localPath!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _networkUrl != null
                ? Image.network(
                    _networkUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: _loadingBuilder,
                    errorBuilder: _errorBuilder,
                  )
                : _errorPlaceholder(),
          )
        : _networkUrl != null
        ? Image.network(
            _networkUrl!,
            fit: BoxFit.contain,
            loadingBuilder: _loadingBuilder,
            errorBuilder: _errorBuilder,
          )
        : _errorPlaceholder();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: (_localPath != null || _networkUrl != null)
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _FullscreenImageViewer(
                    localPath: _localPath,
                    networkUrl: _networkUrl,
                    alt: widget.alt,
                  ),
                ),
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded /
              loadingProgress.expectedTotalBytes!
        : null;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress,
            color: U.primary,
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _errorBuilder(BuildContext context, Object error, StackTrace? stack) {
    final url = _networkUrl;
    if (_localPath != null && url != null) {
      unawaited(_cache.deleteCached(url));
      _localPath = null;
    }
    return _errorPlaceholder();
  }

  Widget _errorPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: U.dim, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.alt ?? 'Image failed to load',
            style: GoogleFonts.outfit(color: U.dim, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageViewer extends StatelessWidget {
  final String? localPath;
  final String? networkUrl;
  final String? alt;

  const _FullscreenImageViewer({this.localPath, this.networkUrl, this.alt});

  @override
  Widget build(BuildContext context) {
    final image = localPath != null
        ? Image.file(
            File(localPath!),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => networkUrl != null
                ? Image.network(
                    networkUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _fullscreenError(),
                  )
                : _fullscreenError(),
          )
        : networkUrl != null
        ? Image.network(
            networkUrl!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _fullscreenError(),
          )
        : _fullscreenError();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: alt == null || alt!.trim().isEmpty
            ? null
            : Text(alt!, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(minScale: 0.8, maxScale: 5, child: image),
      ),
    );
  }

  Widget _fullscreenError() {
    return Center(
      child: Text(
        alt ?? 'Image failed to load',
        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }
}
