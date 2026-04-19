import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'cache_service.dart';

class GitHubGlobalService {
  static final GitHubGlobalService _instance = GitHubGlobalService._internal();
  factory GitHubGlobalService() => _instance;
  GitHubGlobalService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cache = CacheService();

  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  Map<String, String>? _cachedConfig;
  DateTime? _configCacheTime;
  static const _configCacheDuration = Duration(minutes: 5);

  Future<Map<String, String>?> _getConfig({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedConfig != null &&
        _configCacheTime != null &&
        DateTime.now().difference(_configCacheTime!) < _configCacheDuration) {
      return _cachedConfig;
    }

    try {
      final doc = await _firestore
          .collection('config')
          .doc('github-global')
          .get();
      if (!doc.exists || doc.data() == null) return null;

      final data = doc.data()!;
      _cachedConfig = {
        'repo': data['repo']?.toString() ?? '',
        'branch': data['branch']?.toString() ?? 'main',
        'pat': data['pat']?.toString() ?? '',
      };
      _configCacheTime = DateTime.now();
      return _cachedConfig;
    } catch (_) {
      return _cachedConfig;
    }
  }

  void invalidateConfigCache() {
    _cachedConfig = null;
    _configCacheTime = null;
  }

  Future<void> ensureUniversityFolderExists(String universityName) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty)
        return;

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;
      final path = '$universityName/.keep';

      final url = Uri.parse(
        'https://api.github.com/repos/$repo/contents/$path',
      );
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final checkRes = await http.get(url, headers: headers);

      if (checkRes.statusCode == 404) {
        final message = 'init university';
        final content = base64Encode(utf8.encode('# $universityName'));

        await http.put(
          url,
          headers: headers,
          body: jsonEncode({
            'message': message,
            'content': content,
            'branch': branch,
          }),
        );
      }
    } catch (_) {}
  }

  Future<void> ensureClassFolderExists(
    String universityName,
    String classId,
  ) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty)
        return;

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;
      final path = '$universityName/$classId/Notes/.keep';

      final url = Uri.parse(
        'https://api.github.com/repos/$repo/contents/$path',
      );
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final checkRes = await http.get(url, headers: headers);

      if (checkRes.statusCode == 404) {
        final message = 'init class $classId';
        final content = base64Encode(utf8.encode('# Notes'));

        await http.put(
          url,
          headers: headers,
          body: jsonEncode({
            'message': message,
            'content': content,
            'branch': branch,
          }),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveToCache(
    String path,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final db = await _cache.db;
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      await db.delete('github_cache', where: 'path = ?', whereArgs: [path]);
      batch.insert('github_cache', {
        'path': path,
        'data': jsonEncode(items),
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> _loadFromCache(String path) async {
    try {
      final db = await _cache.db;
      final rows = await db.query(
        'github_cache',
        where: 'path = ?',
        whereArgs: [path],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final data = rows.first['data'] as String?;
      if (data == null) return null;
      return List<Map<String, dynamic>>.from(
        (jsonDecode(data) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches directory contents using a cache-first pattern:
  /// 1. Return memory cache instantly → background refresh
  /// 2. Return SQLite cache instantly → background refresh  
  /// 3. Only block on network if no cache at all
  Future<List<Map<String, dynamic>>> getDirectoryContents(
    String path, {
    bool forceRefresh = false,
    void Function(List<Map<String, dynamic>>)? onRefresh,
  }) async {
    // If forceRefresh, skip cache and go straight to network
    if (forceRefresh) {
      return _fetchFromNetwork(path);
    }

    // 1. Memory cache → return instantly, background refresh
    if (_memoryCache.containsKey(path)) {
      unawaited(_refreshInBackground(path, onRefresh));
      return List<Map<String, dynamic>>.from(_memoryCache[path]!);
    }

    // 2. SQLite cache → return instantly, background refresh
    final cached = await _loadFromCache(path);
    if (cached != null) {
      _memoryCache[path] = List<Map<String, dynamic>>.from(cached);
      unawaited(_refreshInBackground(path, onRefresh));
      return cached;
    }

    // 3. No cache at all → must block on network
    return _fetchFromNetwork(path);
  }

  Future<List<Map<String, dynamic>>> _fetchFromNetwork(String path) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return [];
      }

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;

      final urlStr = 'https://api.github.com/repos/$repo/contents/$path?ref=$branch&ts=${DateTime.now().millisecondsSinceEpoch}';
      final url = Uri.parse(urlStr);
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'Cache-Control': 'no-cache',
      };

      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final items = data
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _memoryCache[path] = List<Map<String, dynamic>>.from(items);
        _saveToCache(path, items);
        return items;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _refreshInBackground(
    String path,
    void Function(List<Map<String, dynamic>>)? onRefresh,
  ) async {
    try {
      final freshItems = await _fetchFromNetwork(path);
      if (freshItems.isNotEmpty && onRefresh != null) {
        onRefresh(freshItems);
      }
    } catch (_) {
      // Silently fail — stale cache is better than no data
    }
  }

  Future<void> invalidateCache(String path) async {
    _memoryCache.remove(path);
    try {
      final db = await _cache.db;
      await db.delete('github_cache', where: 'path = ?', whereArgs: [path]);
    } catch (_) {}
  }

  Future<void> invalidateAllCache() async {
    _memoryCache.clear();
    try {
      final db = await _cache.db;
      await db.delete('github_cache');
    } catch (_) {}
  }

  Future<bool> createFolder(String path, {String? content}) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return false;
      }

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;

      final url = Uri.parse(
        'https://api.github.com/repos/$repo/contents/$path',
      );
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final checkRes = await http.get(url, headers: headers);
      final fileContent =
          content ?? '# ${path.split('/').last}\n\nAdd your notes here.\n';
      final encoded = base64Encode(utf8.encode(fileContent));

      if (checkRes.statusCode == 200) {
        final existing = jsonDecode(checkRes.body);
        await http.put(
          url,
          headers: headers,
          body: jsonEncode({
            'message': 'Update $path',
            'content': encoded,
            'branch': branch,
            'sha': existing['sha'],
          }),
        );
      } else {
        await http.put(
          url,
          headers: headers,
          body: jsonEncode({
            'message': 'Create $path',
            'content': encoded,
            'branch': branch,
          }),
        );
      }

      await invalidateCache(path);
      if (path.contains('/')) {
        final parentPath = path.substring(0, path.lastIndexOf('/'));
        await invalidateCache(parentPath);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteItem(String path) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return false;
      }

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;

      final url = Uri.parse(
        'https://api.github.com/repos/$repo/contents/$path?ref=$branch',
      );
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final checkRes = await http.get(url, headers: headers);
      if (checkRes.statusCode == 404) return true; // Already deleted
      
      if (checkRes.statusCode == 200) {
        final data = jsonDecode(checkRes.body);
        
        if (data is List) {
          // It's a directory, delete all contents recursively.
          // Process sequentially to avoid Git 409 conflicts (parallel commits to the same branch).
          for (final item in data) {
            await deleteItem(item['path']);
          }
        } else if (data is Map) {
          // It's a single file
          final sha = data['sha'];
          await http.delete(
            Uri.parse('https://api.github.com/repos/$repo/contents/$path'),
            headers: headers,
            body: jsonEncode({
              'message': 'Delete $path',
              'sha': sha,
              'branch': branch,
            }),
          );
        }
      }

      await invalidateCache(path);
      if (path.contains('/')) {
        final parentPath = path.substring(0, path.lastIndexOf('/'));
        await invalidateCache(parentPath);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> renameItem(String oldPath, String newPath) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return false;
      }

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      // Get old file info
      final oldUrl = Uri.parse('https://api.github.com/repos/$repo/contents/$oldPath?ref=$branch');
      final oldRes = await http.get(oldUrl, headers: headers);
      
      if (oldRes.statusCode == 200) {
        final data = jsonDecode(oldRes.body);
        
        if (data is List) { // It's a directory
          // Process children sequentially to avoid Git 409 conflicts
          // (parallel commits to the same branch cause race conditions)
          for (final item in data) {
            final childOldPath = item['path'] as String;
            final childName = item['name'] as String;
            final childNewPath = '$newPath/$childName';
            await renameItem(childOldPath, childNewPath);
          }
          
          _memoryCache.remove(oldPath);
          if (oldPath.contains('/')) _memoryCache.remove(oldPath.substring(0, oldPath.lastIndexOf('/')));
          if (newPath.contains('/')) _memoryCache.remove(newPath.substring(0, newPath.lastIndexOf('/')));
          return true;
        } else if (data is Map) { // It's a file
          final content = data['content'] as String;
          final sha = data['sha'] as String;
          
          // Create new file
          final newUrl = Uri.parse('https://api.github.com/repos/$repo/contents/$newPath');
          final createRes = await http.put(
            newUrl,
            headers: headers,
            body: jsonEncode({
              'message': 'Rename $oldPath to $newPath',
              'content': content.replaceAll('\n', ''),
              'branch': branch,
            }),
          );

          if (createRes.statusCode == 201 || createRes.statusCode == 200) {
            // Delete old file
            await http.delete(
              Uri.parse('https://api.github.com/repos/$repo/contents/$oldPath'),
              headers: headers,
              body: jsonEncode({
                'message': 'Delete old file $oldPath after rename',
                'sha': sha,
                'branch': branch,
              }),
            );
            
            await invalidateCache(oldPath);
            if (oldPath.contains('/')) await invalidateCache(oldPath.substring(0, oldPath.lastIndexOf('/')));
            if (newPath.contains('/')) await invalidateCache(newPath.substring(0, newPath.lastIndexOf('/')));
            return true;
          }
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createBranchStructure(
    String universityFolderName,
    String branchName,
  ) async {
    try {
      final basePath = '$universityFolderName/Community/$branchName';
      final path = '$basePath/Sample-Semester/Sample-Course/Sample-Unit/README.md';
      final content = '# Sample Unit\n\nThis is a sample structure for your branch.\n\nAdd your notes here.\n';
      
      return await createFolder(path, content: content);
    } catch (_) {
      return false;
    }
  }

  Future<String> getFileContent(String downloadUrl) async {
    try {
      final res = await http.get(Uri.parse(downloadUrl));
      if (res.statusCode == 200) {
        return res.body;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<String> getFileContentRaw(String path) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return '';
      }

      final repo = config['repo']!;
      final pat = config['pat']!;
      final branch = config['branch']!;

      final url = Uri.parse('https://api.github.com/repos/$repo/contents/$path?ref=$branch');
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final content = data['content'] as String;
        return utf8.decode(base64Decode(content.replaceAll('\n', '')));
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  /// In-memory cache for last-modified dates: path → (DateTime, fetchedAt).
  static final Map<String, (DateTime, DateTime)> _lastModifiedCache = {};
  static const _lastModifiedCacheDuration = Duration(minutes: 5);

  /// Fetch the date of the most recent commit that touched [path].
  /// Returns `null` if the date cannot be determined.
  Future<DateTime?> getLastModified(String path) async {
    // 1. Check in-memory cache
    final cached = _lastModifiedCache[path];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _lastModifiedCacheDuration) {
      return cached.$1;
    }

    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return null;
      }

      final repo = config['repo']!;
      final branch = config['branch']!;
      final pat = config['pat']!;

      // Use the Commits API with path filter, limited to 1 result
      final url = Uri.parse(
        'https://api.github.com/repos/$repo/commits?sha=$branch&path=$path&per_page=1',
      );
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        final List<dynamic> commits = jsonDecode(res.body);
        if (commits.isNotEmpty) {
          final dateStr = commits[0]['commit']?['committer']?['date'] as String?;
          if (dateStr != null) {
            final dt = DateTime.parse(dateStr);
            _lastModifiedCache[path] = (dt, DateTime.now());
            return dt;
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateFile({
    required String path,
    required String content,
    required String message,
  }) async {
    try {
      final config = await _getConfig();
      if (config == null || config['repo']!.isEmpty || config['pat']!.isEmpty) {
        return false;
      }

      final repo = config['repo']!;
      final pat = config['pat']!;
      final branch = config['branch']!;

      final url = Uri.parse('https://api.github.com/repos/$repo/contents/$path');
      final headers = {
        'Authorization': 'Bearer $pat',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

      // Get current SHA
      final checkRes = await http.get(
        Uri.parse('https://api.github.com/repos/$repo/contents/$path?ref=$branch'),
        headers: headers,
      );

      String? sha;
      if (checkRes.statusCode == 200) {
        sha = jsonDecode(checkRes.body)['sha'];
      }

      final encoded = base64Encode(utf8.encode(content));
      final body = {
        'message': message,
        'content': encoded,
        'branch': branch,
      };
      if (sha != null) body['sha'] = sha;

      final res = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await invalidateCache(path);
        if (path.contains('/')) {
          await invalidateCache(path.substring(0, path.lastIndexOf('/')));
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
