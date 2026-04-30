import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'utopia_cache.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE folders (
            path TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            sort_index INTEGER NOT NULL DEFAULT 0,
            is_hidden INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE files (
            path TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            folder_path TEXT NOT NULL,
            sort_index INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE note_content (
            path TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE image_refs (
            note_path TEXT NOT NULL,
            source TEXT NOT NULL,
            repo_path TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY (note_path, source)
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE folders ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE files ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE image_refs (
              note_path TEXT NOT NULL,
              source TEXT NOT NULL,
              repo_path TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (note_path, source)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE folders ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE supabase_cache (
              path TEXT PRIMARY KEY,
              data TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE github_cache RENAME TO supabase_cache',
          ).catchError((_) {});
        }
      },
    );
  }

  Future<void> saveAppSetting(String key, String value) async {
    final database = await db;
    await database.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getAppSetting(String key) async {
    final database = await db;
    final rows = await database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> saveFolders(List<Map<String, dynamic>> folders) async {
    final database = await db;
    final batch = database.batch();
    await database.delete('folders');
    for (var i = 0; i < folders.length; i++) {
      final f = folders[i];
      batch.insert('folders', {
        'path': f['path'],
        'name': f['name'],
        'sort_index': f['sort_index'] ?? i,
        'is_hidden': f['is_hidden'] == 1 ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setFolderHidden(String path, bool hidden) async {
    final database = await db;
    await database.update(
      'folders',
      {
        'is_hidden': hidden ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  Future<List<Map<String, dynamic>>> getFolders({
    bool includeHidden = false,
  }) async {
    final database = await db;
    final rows = await database.query(
      'folders',
      where: includeHidden ? null : 'is_hidden = ?',
      whereArgs: includeHidden ? null : [0],
      orderBy: 'sort_index ASC, updated_at ASC',
    );
    return rows
        .map(
          (r) => {
            'path': r['path'],
            'name': r['name'],
            'sort_index': r['sort_index'],
            'is_hidden': r['is_hidden'],
          },
        )
        .toList();
  }

  Future<void> saveFiles(
    String folderPath,
    List<Map<String, dynamic>> files,
  ) async {
    final database = await db;
    final batch = database.batch();
    await database.delete(
      'files',
      where: 'folder_path = ?',
      whereArgs: [folderPath],
    );
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      batch.insert('files', {
        'path': f['path'],
        'name': f['name'],
        'folder_path': folderPath,
        'sort_index': f['sort_index'] ?? i,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveRepoFiles(List<Map<String, dynamic>> files) async {
    final database = await db;
    final batch = database.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      batch.insert('files', {
        'path': file['path'],
        'name': file['name'],
        'folder_path': file['folder_path'],
        'sort_index': file['sort_index'] ?? i,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getFiles(String folderPath) async {
    final database = await db;
    final rows = await database.query(
      'files',
      where: 'folder_path = ?',
      whereArgs: [folderPath],
      orderBy: 'sort_index ASC, updated_at ASC',
    );
    return rows
        .map(
          (r) => {
            'path': r['path'],
            'name': r['name'],
            'sort_index': r['sort_index'],
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllFiles() async {
    final database = await db;
    final rows = await database.query(
      'files',
      orderBy: 'sort_index ASC, updated_at ASC',
    );
    return rows
        .map(
          (r) => {
            'path': r['path'],
            'name': r['name'],
            'folder_path': r['folder_path'],
            'sort_index': r['sort_index'],
          },
        )
        .toList();
  }

  Future<void> saveNoteContent(String path, String content) async {
    final database = await db;
    await database.insert('note_content', {
      'path': path,
      'content': content,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getNoteContent(String path) async {
    final database = await db;
    final rows = await database.query(
      'note_content',
      where: 'path = ?',
      whereArgs: [path],
    );
    if (rows.isEmpty) return null;
    return rows.first['content'] as String;
  }

  Future<void> saveImageReference(
    String notePath,
    String source,
    String repoPath,
  ) async {
    final database = await db;
    await database.insert('image_refs', {
      'note_path': notePath,
      'source': source,
      'repo_path': repoPath,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getImageReference(String notePath, String source) async {
    final database = await db;
    final rows = await database.query(
      'image_refs',
      where: 'note_path = ? AND source = ?',
      whereArgs: [notePath, source],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['repo_path'] as String;
  }

  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final database = await db;
    final q = '%${query.toLowerCase()}%';
    final rows = await database.rawQuery(
      '''
      SELECT f.path, f.name, f.folder_path,
             folders.name as subject,
             nc.content
      FROM files f
      LEFT JOIN note_content nc ON nc.path = f.path
      LEFT JOIN folders ON folders.path = f.folder_path
      WHERE LOWER(f.name) LIKE ? OR LOWER(nc.content) LIKE ?
    ''',
      [q, q],
    );
    return rows.map((r) {
      final content = r['content'] as String? ?? '';
      final idx = content.toLowerCase().indexOf(query.toLowerCase());
      String preview = '';
      if (idx != -1) {
        final start = (idx - 40).clamp(0, content.length);
        final end = (idx + 80).clamp(0, content.length);
        preview =
            '...${content.substring(start, end).replaceAll('\n', ' ')}...';
      }
      return {
        'path': r['path'],
        'name': r['name'],
        'subject': r['subject'] ?? '',
        'folder_path': r['folder_path'],
        'preview': preview,
      };
    }).toList();
  }
}
