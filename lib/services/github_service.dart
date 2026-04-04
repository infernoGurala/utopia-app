import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cache_service.dart';
import 'file_cache_service.dart';

class GitHubService {
  static const String owner = 'infernoGurala';
  static const String repo = 'utopia-content';
  static const String branch = 'main';
  static const String baseUrl = 'https://api.github.com/repos/$owner/$repo';
  static const String rawUrl =
      'https://raw.githubusercontent.com/$owner/$repo/$branch';
  static final FileCacheService _fileCache = FileCacheService();
  static Future<void>? _libraryWarmupFuture;
  static final Map<String, Future<void>> _folderWarmups = {};
  static final Map<String, Future<String?>> _noteWarmups = {};
  static List<Map<String, dynamic>>? _foldersMemoryCache;
  static final Map<String, List<Map<String, dynamic>>> _filesMemoryCache = {};
  static final Map<String, String> _noteContentMemoryCache = {};
  static List<Map<String, dynamic>>? _repoTreeMemoryCache;
  static List<Map<String, dynamic>>? _imageTreeCache;
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.svg',
    '.bmp',
  };

  List<Map<String, dynamic>> getCachedFoldersSync() {
    return _foldersMemoryCache == null
        ? const []
        : List<Map<String, dynamic>>.from(_foldersMemoryCache!);
  }

  List<Map<String, dynamic>> getCachedFilesSync(String folderPath) {
    final files = _filesMemoryCache[folderPath];
    return files == null ? const [] : List<Map<String, dynamic>>.from(files);
  }

  String? getCachedNoteContentSync(String filePath) {
    return _noteContentMemoryCache[filePath];
  }

  Future<String> _fetchPat() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('github')
        .get();
    final pat = doc.data()?['pat'] as String?;
    if (pat == null || pat.isEmpty) {
      throw Exception('GitHub token is missing.');
    }
    return pat;
  }

  static Future<void> primeFileContentCache(
    String filePath,
    String content,
  ) async {
    _noteContentMemoryCache[filePath] = content;
    await CacheService().saveNoteContent(filePath, content);
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  String _normalizeDisplayName(String input) {
    return input
        .toLowerCase()
        .replaceAll('.md', '')
        .replaceAll(RegExp(r'^\d+[-_\s]*'), '')
        .replaceAll(RegExp(r'[-_\s]+'), ' ')
        .trim();
  }

  String _normalizePath(String input) {
    final parts = <String>[];
    for (final rawPart in input.split('/')) {
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

  bool _looksLikeImagePath(String input) {
    final lower = input.toLowerCase();
    return _imageExtensions.any((ext) => lower.endsWith(ext));
  }

  String _folderPathFromFile(String filePath) {
    final normalizedPath = _normalizePath(filePath);
    if (normalizedPath.isEmpty || !normalizedPath.contains('/')) {
      return '';
    }
    final parts = normalizedPath.split('/')..removeLast();
    return parts.join('/');
  }

  List<String> _extractImageSources(String rawContent) {
    final sources = <String>{};

    for (final match in RegExp(r'!\[\[([^\]]+)\]\]').allMatches(rawContent)) {
      final inner = (match.group(1) ?? '').trim();
      final source = inner.split('|').first.trim();
      if (source.isNotEmpty) {
        sources.add(source);
      }
    }

    for (final match in RegExp(
      r'!\[[^\]]*\]\(([^)]+)\)',
    ).allMatches(rawContent)) {
      final rawSource = (match.group(1) ?? '').trim();
      if (rawSource.isEmpty) {
        continue;
      }
      final source = rawSource.split(RegExp(r'\s+')).first.trim();
      if (source.isNotEmpty) {
        sources.add(source);
      }
    }

    return sources.toList();
  }

  Future<void> _prefetchNoteImages(String notePath, String rawContent) async {
    final imageSources = _extractImageSources(rawContent);
    if (imageSources.isEmpty) {
      return;
    }

    final noteFolderPath = _folderPathFromFile(notePath);
    final pending = <Future<void>>[];

    for (final source in imageSources) {
      pending.add(() async {
        final localPath = await getOrFetchRepoImage(
          source,
          noteFolderPath: noteFolderPath,
          notePath: notePath,
        );
        if (localPath != null) {
          return;
        }

        final url = await resolveImageUrl(
          source,
          noteFolderPath: noteFolderPath,
        );
        if (url == null || url.isEmpty) {
          return;
        }
        final cached = await _fileCache.getCachedImagePath(url);
        if (cached != null) {
          return;
        }
        await _fileCache.downloadFile(url);
      }());

      if (pending.length >= 4) {
        await Future.wait(pending);
        pending.clear();
      }
    }

    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }

  Future<List<Map<String, dynamic>>> _getRepoTree() async {
    if (_repoTreeMemoryCache != null && _imageTreeCache != null) {
      return List<Map<String, dynamic>>.from(_repoTreeMemoryCache!);
    }

    final online = await _isOnline();
    if (!online) {
      return const [];
    }

    try {
      final pat = await _fetchPat();
      final response = await http
          .get(
            Uri.parse('$baseUrl/git/trees/$branch?recursive=1'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final allBlobs = (data['tree'] as List)
          .cast<Map<String, dynamic>>()
          .where((item) => item['type'] == 'blob')
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final tree = allBlobs.where((item) {
        final path = (item['path'] ?? '').toString();
        return path.endsWith('.md');
      }).toList();
      _imageTreeCache = allBlobs.where((item) {
        final path = (item['path'] ?? '').toString().toLowerCase();
        return _imageExtensions.any((ext) => path.endsWith(ext));
      }).toList();
      final repoFiles = tree
          .map((item) => _noteMetadataFromPath((item['path'] ?? '').toString()))
          .toList();
      await CacheService().saveRepoFiles(repoFiles);
      _repoTreeMemoryCache = tree;
      return List<Map<String, dynamic>>.from(tree);
    } catch (e) {
      return const [];
    }
  }

  Map<String, dynamic> _noteMetadataFromPath(String path) {
    final normalizedPath = _normalizePath(path);
    final parts = normalizedPath.split('/');
    final basename = parts.removeLast();
    final displayName = basename
        .replaceAll('.md', '')
        .replaceAll(RegExp(r'^\d+[-_\s]*'), '')
        .replaceAll('-', ' ');
    return {
      'name': displayName,
      'path': normalizedPath,
      'folder_path': parts.join('/'),
    };
  }

  Future<void> _prefetchNoteContents(List<Map<String, dynamic>> files) async {
    final pending = <Future<void>>[];
    for (final file in files) {
      final path = file['path'] as String?;
      if (path == null || path.isEmpty) continue;
      pending.add(_ensureNoteCached(path));
      if (pending.length >= 4) {
        await Future.wait(pending);
        pending.clear();
      }
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }

  Future<String?> _fetchFileContentRemote(String filePath) async {
    final pat = await _fetchPat();
    final response = await http
        .get(
          Uri.parse('$baseUrl/contents/$filePath'),
          headers: {
            'Accept': 'application/vnd.github+json',
            'Authorization': 'Bearer $pat',
            'X-GitHub-Api-Version': '2022-11-28',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body);
    final encoded = data['content'] as String;
    final decoded = utf8.decode(base64Decode(encoded.replaceAll('\n', '')));
    await CacheService().saveNoteContent(filePath, decoded);
    _noteContentMemoryCache[filePath] = decoded;
    await _prefetchNoteImages(filePath, decoded);
    return decoded;
  }

  Future<void> _ensureNoteCached(String filePath) async {
    final cached = await CacheService().getNoteContent(filePath);
    if (cached != null && cached.isNotEmpty) {
      final online = await _isOnline();
      if (online) {
        await _prefetchNoteImages(filePath, cached);
      }
      return;
    }
    final online = await _isOnline();
    if (!online) {
      return;
    }
    final inFlight = _noteWarmups[filePath];
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _fetchFileContentRemote(filePath);
    _noteWarmups[filePath] = future;
    try {
      await future;
    } finally {
      _noteWarmups.remove(filePath);
    }
  }

  Future<void> refreshFileContent(String filePath) async {
    final online = await _isOnline();
    if (!online) {
      return;
    }
    final inFlight = _noteWarmups[filePath];
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _fetchFileContentRemote(filePath);
    _noteWarmups[filePath] = future;
    try {
      await future;
    } finally {
      _noteWarmups.remove(filePath);
    }
  }

  Future<void> warmFolderForOffline(String folderPath) async {
    final inFlight = _folderWarmups[folderPath];
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = () async {
      final files = await getFiles(folderPath);
      if (files.isEmpty) {
        return;
      }
      await _prefetchNoteContents(files);
    }();
    _folderWarmups[folderPath] = future;
    try {
      await future;
    } finally {
      _folderWarmups.remove(folderPath);
    }
  }

  Future<void> warmLibraryForOffline() async {
    if (_libraryWarmupFuture != null) {
      await _libraryWarmupFuture;
      return;
    }
    _libraryWarmupFuture = () async {
      await _getRepoTree();
      final folders = await getFolders();
      for (final folder in folders) {
        final folderPath = (folder['path'] ?? '').toString();
        if (folderPath.isEmpty) {
          continue;
        }
        await warmFolderForOffline(folderPath);
      }
    }();
    try {
      await _libraryWarmupFuture;
    } finally {
      _libraryWarmupFuture = null;
    }
  }

  Future<List<Map<String, dynamic>>> getFolders({bool isWriter = false}) async {
    final online = await _isOnline();
    if (!online) {
      final cachedFolders = await CacheService().getFolders(
        includeHidden: true,
      );
      if (isWriter) return cachedFolders;
      return cachedFolders.where((f) => f['is_hidden'] != 1).toList();
    }

    Set<String> hiddenPaths = {};
    String? pat;
    try {
      pat = await _fetchPat();
    } catch (_) {
      pat = null;
    }

    // Step 1: Fetch hidden folders from GitHub
    if (pat != null) {
      try {
        final hiddenResponse = await http
            .get(
              Uri.parse('$baseUrl/contents/.utopia-hidden'),
              headers: {
                'Accept': 'application/vnd.github+json',
                'Authorization': 'Bearer $pat',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            )
            .timeout(_requestTimeout);
        if (hiddenResponse.statusCode == 200) {
          final data = jsonDecode(hiddenResponse.body);
          final String content = data['content'];
          String normalizedContent = content
              .replaceAll('-', '+')
              .replaceAll('_', '/')
              .trim();
          if (!normalizedContent.endsWith('=') &&
              normalizedContent.length % 4 != 0) {
            final int padLen = (4 - normalizedContent.length % 4) % 4;
            normalizedContent += '=' * padLen;
          }
          try {
            final String decoded = utf8.decode(base64Decode(normalizedContent));
            final List<dynamic> hiddenList = jsonDecode(decoded);
            hiddenPaths = hiddenList.cast<String>().toSet();
            debugPrint('Hidden paths from GitHub: $hiddenPaths');
          } catch (decodeErr) {
            debugPrint('Error decoding hidden file: $decodeErr');
          }
        } else if (hiddenResponse.statusCode != 404) {
          debugPrint('Failed to fetch hidden file: ${hiddenResponse.statusCode}');
        }
      } catch (e) {
        debugPrint('Error fetching hidden folders: $e');
      }
    }

    // Step 2: Fetch all folders from GitHub
    try {
      final authHeaders = pat == null
          ? <String, String>{'Accept': 'application/vnd.github+json'}
          : <String, String>{
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
            };
      final response = await http
          .get(
            Uri.parse('$baseUrl/contents'),
            headers: authHeaders,
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List items = jsonDecode(response.body);

        // Step 3: Build folders with is_hidden flag
        final folders = <Map<String, dynamic>>[];
        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          if (item['type'] != 'dir') continue;

          final path = item['path'] as String;
          final name = (item['name'] as String)
              .replaceAll(RegExp(r'^\d+-'), '')
              .replaceAll('-', ' ');

          folders.add({
            'sort_index': i,
            'name': name,
            'path': path,
            'is_hidden': hiddenPaths.contains(path) ? 1 : 0,
          });
        }

        // Step 4: Save to cache
        await CacheService().saveFolders(folders);
        _foldersMemoryCache = folders;

        // Step 5: Return filtered results
        if (isWriter) {
          return folders;
        } else {
          return folders.where((f) => f['is_hidden'] != 1).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching folders: $e');
    }

    // Fallback: load from cache
    final cachedFolders = await CacheService().getFolders(includeHidden: true);
    if (isWriter) return cachedFolders;
    return cachedFolders.where((f) => f['is_hidden'] != 1).toList();
  }

  Future<List<Map<String, dynamic>>> getFiles(String folderPath) async {
    final online = await _isOnline();
    if (online) {
      try {
        final pat = await _fetchPat();
        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/contents/$folderPath?ts=${DateTime.now().millisecondsSinceEpoch}',
              ),
              headers: {
                'Accept': 'application/vnd.github+json',
                'Authorization': 'Bearer $pat',
                'X-GitHub-Api-Version': '2022-11-28',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final List items = jsonDecode(response.body);
          final files = items
              .where(
                (item) =>
                    item['type'] == 'file' &&
                    (item['name'] as String).endsWith('.md'),
              )
              .toList()
              .asMap()
              .entries
              .map<Map<String, dynamic>>(
                (entry) => {
                  'sort_index': entry.key,
                  'name': (entry.value['name'] as String)
                      .replaceAll('.md', '')
                      .replaceAll(RegExp(r'^\d+-'), '')
                      .replaceAll('-', ' '),
                  'path': entry.value['path'],
                },
              )
              .toList();
          await CacheService().saveFiles(folderPath, files);
          _filesMemoryCache[folderPath] = List<Map<String, dynamic>>.from(
            files,
          );
          unawaited(_prefetchNoteContents(files));
          return files;
        }
      } catch (e) {}
    }
    final cachedFiles = await CacheService().getFiles(folderPath);
    if (cachedFiles.isNotEmpty) {
      _filesMemoryCache[folderPath] = List<Map<String, dynamic>>.from(
        cachedFiles,
      );
    }
    return cachedFiles;
  }

  Future<String> getFileContent(String filePath) async {
    final memory = _noteContentMemoryCache[filePath];
    if (memory != null && memory.isNotEmpty) {
      unawaited(refreshFileContent(filePath));
      return memory;
    }

    final cached = await CacheService().getNoteContent(filePath);
    if (cached != null && cached.isNotEmpty) {
      _noteContentMemoryCache[filePath] = cached;
      unawaited(refreshFileContent(filePath));
      return cached;
    }

    final online = await _isOnline();
    if (online) {
      try {
        final remote = await _fetchFileContentRemote(filePath);
        if (remote != null) {
          return remote;
        }
      } catch (e) {}
    }
    return cached ?? '';
  }

  Future<Map<String, dynamic>?> findNoteByPath(String targetPath) async {
    final normalizedTarget = _normalizePath(targetPath);
    if (normalizedTarget.isEmpty) {
      return null;
    }

    final cachedFiles = await CacheService().getAllFiles();
    for (final file in cachedFiles) {
      final path = _normalizePath((file['path'] ?? '').toString());
      if (path == normalizedTarget) {
        return {
          'name': file['name'],
          'path': path,
          'folder_path': file['folder_path'],
        };
      }
    }

    final tree = await _getRepoTree();
    for (final item in tree) {
      final path = _normalizePath((item['path'] ?? '').toString());
      if (path == normalizedTarget) {
        return _noteMetadataFromPath(path);
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> findNoteByName(String targetName) async {
    final normalizedTarget = _normalizeDisplayName(targetName);

    final cachedFiles = await CacheService().getAllFiles();
    for (final file in cachedFiles) {
      final fileName = (file['name'] ?? '').toString();
      if (_normalizeDisplayName(fileName) == normalizedTarget) {
        return file;
      }
    }

    try {
      final tree = await _getRepoTree();
      for (final item in tree) {
        final path = (item['path'] ?? '').toString();
        final basename = path.split('/').last.replaceAll('.md', '');
        final displayName = basename
            .replaceAll(RegExp(r'^\d+[-_\s]*'), '')
            .replaceAll('-', ' ');

        if (_normalizeDisplayName(displayName) == normalizedTarget ||
            _normalizeDisplayName(basename) == normalizedTarget) {
          return _noteMetadataFromPath(path);
        }
      }
    } catch (e) {}

    return null;
  }

  Future<List<int>?> _fetchRepoFileBytes(String filePath) async {
    final pat = await _fetchPat();
    final response = await http
        .get(
          Uri.parse('$baseUrl/contents/$filePath'),
          headers: {
            'Accept': 'application/vnd.github.v3.raw',
            'Authorization': 'Bearer $pat',
            'X-GitHub-Api-Version': '2022-11-28',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(_requestTimeout);
    if (response.statusCode != 200) {
      return null;
    }
    return response.bodyBytes;
  }

  Future<String?> _resolveImageRepoPath(
    String src, {
    String? noteFolderPath,
    String? notePath,
  }) async {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return null;
    }

    final cleaned = Uri.decodeComponent(
      trimmed,
    ).split('#').first.split('?').first.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final normalizedSrc = _normalizePath(
      cleaned.startsWith('/') ? cleaned.substring(1) : cleaned,
    );
    if (normalizedSrc.isEmpty) {
      return null;
    }

    final normalizedFolder = noteFolderPath == null
        ? ''
        : _normalizePath(noteFolderPath);
    final normalizedNotePath = notePath == null ? '' : _normalizePath(notePath);

    if (normalizedNotePath.isNotEmpty) {
      final mapped = await CacheService().getImageReference(
        normalizedNotePath,
        cleaned,
      );
      final normalizedMapped = mapped == null ? '' : _normalizePath(mapped);
      if (normalizedMapped.isNotEmpty &&
          _looksLikeImagePath(normalizedMapped)) {
        return normalizedMapped;
      }
    }

    final exactCandidatePaths = <String>[
      if (normalizedFolder.isNotEmpty && !cleaned.startsWith('/'))
        _normalizePath('$normalizedFolder/$cleaned'),
      normalizedSrc,
    ];

    for (final candidate in exactCandidatePaths) {
      if (candidate.isEmpty || !_looksLikeImagePath(candidate)) {
        continue;
      }
      final cached = await _fileCache.getCachedImagePath('$rawUrl/$candidate');
      if (cached != null) {
        return candidate;
      }
    }

    final isExplicitRepoPath =
        cleaned.startsWith('/') ||
        cleaned.contains('/') ||
        cleaned.startsWith('./') ||
        cleaned.startsWith('../');
    if (isExplicitRepoPath) {
      for (final candidate in exactCandidatePaths) {
        if (candidate.isEmpty || !_looksLikeImagePath(candidate)) {
          continue;
        }
        return candidate;
      }
    }

    await _getRepoTree();

    final images = _imageTreeCache;
    if (images == null || images.isEmpty) return null;

    for (final candidate in exactCandidatePaths) {
      final normalizedCandidate = _normalizePath(candidate).toLowerCase();
      if (normalizedCandidate.isEmpty) {
        continue;
      }
      for (final image in images) {
        final imagePath = _normalizePath(
          (image['path'] ?? '').toString(),
        ).toLowerCase();
        if (imagePath == normalizedCandidate) {
          return (image['path'] ?? '').toString();
        }
      }
    }

    final srcBasename = Uri.decodeComponent(
      cleaned.split('/').last,
    ).toLowerCase();
    if (srcBasename.isEmpty) {
      return null;
    }

    final candidates = <Map<String, dynamic>>[];
    for (final image in images) {
      final path = (image['path'] ?? '').toString();
      final basename = path.split('/').last.toLowerCase();
      if (basename == srcBasename) {
        candidates.add(image);
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    if (candidates.length == 1) {
      return (candidates.first['path'] ?? '').toString();
    }

    if (normalizedFolder.isNotEmpty) {
      for (final candidate in candidates) {
        final parts = (candidate['path'] ?? '').toString().split('/')
          ..removeLast();
        final folder = _normalizePath(parts.join('/'));
        if (folder == normalizedFolder) {
          return (candidate['path'] ?? '').toString();
        }
      }

      for (final candidate in candidates) {
        final path = _normalizePath((candidate['path'] ?? '').toString());
        if (path.startsWith(normalizedFolder)) {
          return (candidate['path'] ?? '').toString();
        }
      }
    }

    if (cleaned.contains('/')) {
      final normalizedSourcePath = _normalizePath(cleaned).toLowerCase();
      for (final candidate in candidates) {
        final path = _normalizePath(
          (candidate['path'] ?? '').toString(),
        ).toLowerCase();
        if (path.endsWith(normalizedSourcePath) ||
            path == normalizedSourcePath) {
          return (candidate['path'] ?? '').toString();
        }
      }

      if (normalizedFolder.isNotEmpty) {
        final resolved = _normalizePath(
          '$normalizedFolder/$cleaned',
        ).toLowerCase();
        for (final candidate in candidates) {
          final path = _normalizePath(
            (candidate['path'] ?? '').toString(),
          ).toLowerCase();
          if (path == resolved) {
            return (candidate['path'] ?? '').toString();
          }
        }
      }
    }

    return (candidates.first['path'] ?? '').toString();
  }

  Future<String?> getOrFetchRepoImage(
    String src, {
    String? noteFolderPath,
    String? notePath,
  }) async {
    final repoPath = await _resolveImageRepoPath(
      src,
      noteFolderPath: noteFolderPath,
      notePath: notePath,
    );
    if (repoPath == null || repoPath.isEmpty) {
      return null;
    }

    final trimmed = src.trim();
    final cleanedSource = Uri.decodeComponent(
      trimmed,
    ).split('#').first.split('?').first.trim();
    final normalizedNotePath = notePath == null ? '' : _normalizePath(notePath);
    if (normalizedNotePath.isNotEmpty && cleanedSource.isNotEmpty) {
      await CacheService().saveImageReference(
        normalizedNotePath,
        cleanedSource,
        repoPath,
      );
    }

    final stableUrl = '$rawUrl/$repoPath';
    final cached = await _fileCache.getCachedImagePath(stableUrl);
    if (cached != null) {
      return cached;
    }

    final online = await _isOnline();
    if (!online) {
      return null;
    }

    final bytes = await _fetchRepoFileBytes(repoPath);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final savedPath = await _fileCache.saveBytes(stableUrl, bytes);
    if (savedPath == null) {
      return null;
    }

    return _fileCache.getCachedImagePath(stableUrl);
  }

  /// Resolves an image source to an absolute raw.githubusercontent URL.
  ///
  /// Handles: absolute URLs (passthrough), relative paths, and bare filenames
  /// by searching the repo-wide image tree for a matching basename.
  Future<String?> resolveImageUrl(
    String src, {
    String? noteFolderPath,
    String? notePath,
  }) async {
    final trimmed = src.trim();
    if (trimmed.isEmpty) return null;

    // Absolute URL — use as-is.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final repoPath = await _resolveImageRepoPath(
      src,
      noteFolderPath: noteFolderPath,
      notePath: notePath,
    );
    if (repoPath == null || repoPath.isEmpty) {
      return null;
    }
    return '$rawUrl/$repoPath';
  }

  Future<bool> createFolder(String folderName) async {
    final online = await _isOnline();
    if (!online) return false;

    try {
      final pat = await _fetchPat();
      final folderPath =
          '${folderName.replaceAll(' ', '-').toLowerCase()}/README.md';
      final response = await http
          .put(
            Uri.parse('$baseUrl/contents/$folderPath'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': 'Create $folderName folder',
              'content': base64Encode(
                utf8.encode('# $folderName\n\nAdd your notes here.'),
              ),
              'branch': branch,
            }),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFolder(
    String folderPath, {
    bool deleteFiles = false,
  }) async {
    final online = await _isOnline();
    if (!online) return false;

    try {
      final pat = await _fetchPat();
      if (deleteFiles) {
        final files = await getFiles(folderPath);
        for (final file in files) {
          final filePath = file['path'] as String;
          final sha = await _getFileSha(filePath);
          if (sha == null) continue;
          final deleteResp = await http
              .delete(
                Uri.parse('$baseUrl/contents/$filePath'),
                headers: {
                  'Accept': 'application/vnd.github+json',
                  'Authorization': 'Bearer $pat',
                  'X-GitHub-Api-Version': '2022-11-28',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'message': 'Delete $filePath',
                  'sha': sha,
                  'branch': branch,
                }),
              )
              .timeout(_requestTimeout);
          if (deleteResp.statusCode != 200 && deleteResp.statusCode != 204) {
            return false;
          }
        }
      }

      final folderSha = await _getFileSha(folderPath);
      if (folderSha == null) return false;

      final response = await http
          .delete(
            Uri.parse('$baseUrl/contents/$folderPath'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': 'Delete $folderPath',
              'sha': folderSha,
              'branch': branch,
            }),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getFileSha(String path) async {
    try {
      final pat = await _fetchPat();
      final response = await http
          .get(
            Uri.parse('$baseUrl/contents/$path'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sha'] as String?;
      }
    } catch (e) {}
    return null;
  }

  Future<bool> createFile(
    String folderPath,
    String fileName,
    String content,
  ) async {
    final online = await _isOnline();
    if (!online) return false;

    try {
      final pat = await _fetchPat();
      final filePath =
          '$folderPath/${fileName.replaceAll(' ', '-').toLowerCase()}.md';
      final response = await http
          .put(
            Uri.parse('$baseUrl/contents/$filePath'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': 'Create $fileName',
              'content': base64Encode(utf8.encode(content)),
              'branch': branch,
            }),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteFile(String filePath) async {
    final online = await _isOnline();
    if (!online) return false;

    try {
      final pat = await _fetchPat();
      final sha = await _getFileSha(filePath);
      if (sha == null) return false;

      final response = await http
          .delete(
            Uri.parse('$baseUrl/contents/$filePath'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': 'Delete $filePath',
              'sha': sha,
              'branch': branch,
            }),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateHiddenFoldersForFolder(
    String folderPath,
    bool hide,
  ) async {
    final online = await _isOnline();
    if (!online) return false;

    Set<String> hiddenPaths = {};

    // Fetch current hidden list
    try {
      final pat = await _fetchPat();
      final response = await http
          .get(
            Uri.parse('$baseUrl/contents/.utopia-hidden'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String content = data['content'];
        String normalizedContent = content
            .replaceAll('-', '+')
            .replaceAll('_', '/')
            .trim();
        if (!normalizedContent.endsWith('=') &&
            normalizedContent.length % 4 != 0) {
          final int padLen = (4 - normalizedContent.length % 4) % 4;
          normalizedContent += '=' * padLen;
        }
        final String decoded = utf8.decode(base64Decode(normalizedContent));
        final List<dynamic> list = jsonDecode(decoded);
        hiddenPaths = list.cast<String>().toSet();
      }
    } catch (e) {
      // File might not exist yet, start with empty set
    }

    // Update the set
    if (hide) {
      hiddenPaths.add(folderPath);
    } else {
      hiddenPaths.remove(folderPath);
    }

    // Write back to GitHub
    return updateHiddenFolders(hiddenPaths);
  }

  Future<bool> updateHiddenFolders(Set<String> hiddenPaths) async {
    final online = await _isOnline();
    if (!online) return false;

    try {
      final pat = await _fetchPat();
      String? existingSha;
      try {
        final getResp = await http
            .get(
              Uri.parse('$baseUrl/contents/.utopia-hidden'),
              headers: {
                'Accept': 'application/vnd.github+json',
                'Authorization': 'Bearer $pat',
                'X-GitHub-Api-Version': '2022-11-28',
              },
            )
            .timeout(_requestTimeout);
        if (getResp.statusCode == 200) {
          final data = jsonDecode(getResp.body);
          existingSha = data['sha'];
        }
      } catch (e) {}

      final content = jsonEncode(hiddenPaths.toList());
      final body = <String, dynamic>{
        'message': 'Update hidden folders',
        'content': base64Encode(utf8.encode(content)),
        'branch': branch,
      };
      if (existingSha != null) {
        body['sha'] = existingSha;
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/contents/.utopia-hidden'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'Authorization': 'Bearer $pat',
              'X-GitHub-Api-Version': '2022-11-28',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
