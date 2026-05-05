import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseGlobalService {
  static final SupabaseGlobalService instance = SupabaseGlobalService._();
  SupabaseGlobalService._();

  SupabaseClient get _supabase => Supabase.instance.client;

  String _formatName(String name) {
    return name.replaceAll(' ', '-');
  }

  Future<List<String>> getUniversities() async {
    try {
      final response = await _supabase
          .from('folders')
          .select('path')
          .eq('scope', 'university');

      return List<Map<String, dynamic>>.from(
        response,
      ).map((row) => row['path'] as String).toList();
    } catch (e) {
      throw Exception('Failed to get universities: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDirectoryContents(String path) async {
    try {
      final cleanPath = path.endsWith('/')
          ? path.substring(0, path.length - 1)
          : path;

      var folderQuery = _supabase
          .from('folders')
          .select('name, path, is_hidden, created_at, updated_at, sort_index')
          .eq('is_hidden', false);

      var notesQuery = _supabase
          .from('notes')
          .select('name, path, created_at, updated_at, sort_index');

      if (cleanPath.isEmpty) {
        folderQuery = folderQuery.filter('parent_path', 'is', null);
        notesQuery = notesQuery.filter('folder_path', 'is', null);
      } else {
        folderQuery = folderQuery.eq('parent_path', cleanPath);
        notesQuery = notesQuery.eq('folder_path', cleanPath);
      }

      final folderResponse = await folderQuery;
      final notesResponse = await notesQuery;

      final folders = List<Map<String, dynamic>>.from(
        folderResponse,
      ).map((f) => {...f, 'type': 'dir'}).toList();

      final notes = List<Map<String, dynamic>>.from(
        notesResponse,
      ).map((n) => {...n, 'type': 'file'}).toList();

      return [...folders, ...notes];
    } catch (e) {
      throw Exception('Failed to get directory contents for $path: $e');
    }
  }

  Future<String> getNoteContent(String notePath) async {
    try {
      final response = await _supabase
          .from('notes')
          .select('content')
          .eq('path', notePath)
          .maybeSingle();

      if (response == null) return '';
      return (response['content'] as String?) ?? '';
    } catch (e) {
      throw Exception('Failed to get note content for $notePath: $e');
    }
  }

  Future<void> createFolder(
    String parentPath,
    String name,
    String scope,
    String? universityId,
    String? classId,
    String createdByUid,
  ) async {
    try {
      final formattedName = _formatName(name);
      final path = parentPath.isEmpty
          ? formattedName
          : '$parentPath/$formattedName';

      await _supabase.from('folders').insert({
        'path': path,
        'name': name,
        'parent_path': parentPath.isEmpty ? null : parentPath,
        'scope': scope,
        'university_id': universityId,
        'class_id': classId,
        'is_hidden': false,
        'created_by': createdByUid,
      });
    } catch (e) {
      throw Exception('Failed to create folder $name: $e');
    }
  }

  Future<void> createNote(
    String folderPath,
    String name,
    String content,
    String scope,
    String? universityId,
    String? classId,
    String createdByUid,
  ) async {
    try {
      final formattedName = _formatName(name);
      final path = '$folderPath/$formattedName.md';

      await _supabase.from('notes').insert({
        'path': path,
        'name': name,
        'folder_path': folderPath,
        'content': content,
        'scope': scope,
        'university_id': universityId,
        'class_id': classId,
        'created_by': createdByUid,
      });
    } catch (e) {
      throw Exception('Failed to create note $name: $e');
    }
  }

  Future<void> updateNote(
    String notePath,
    String content,
    String updatedByUid,
    String updatedByName,
  ) async {
    try {
      final currentNote = await _supabase
          .from('notes')
          .select('content')
          .eq('path', notePath)
          .maybeSingle();

      if (currentNote != null) {
        final currentContent = currentNote['content'] as String?;
        if (currentContent != null) {
          await _supabase.from('note_versions').insert({
            'note_path': notePath,
            'content': currentContent,
            'saved_by': updatedByUid,
            'saved_by_name': updatedByName,
          });

          final versions = await _supabase
              .from('note_versions')
              .select('id')
              .eq('note_path', notePath)
              .order('saved_at', ascending: false);

          final versionList = List<Map<String, dynamic>>.from(versions);
          if (versionList.length > 20) {
            final idsToDelete = versionList
                .skip(20)
                .map((v) => v['id'] as String)
                .toList();
            for (final id in idsToDelete) {
              await _supabase.from('note_versions').delete().eq('id', id);
            }
          }
        }
      }

      await _supabase
          .from('notes')
          .update({
            'content': content,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('path', notePath);
    } catch (e) {
      throw Exception('Failed to update note $notePath: $e');
    }
  }

  Future<void> deleteNote(String notePath) async {
    try {
      await _supabase.from('notes').delete().eq('path', notePath);
    } catch (e) {
      throw Exception('Failed to delete note $notePath: $e');
    }
  }

  Future<void> deleteFolder(String folderPath) async {
    try {
      // recursively delete all notes starting with folderPath/
      await _supabase.from('notes').delete().like('path', '$folderPath/%');
      // recursively delete all folders starting with folderPath/
      await _supabase.from('folders').delete().like('path', '$folderPath/%');
      // delete the target folder itself
      await _supabase.from('folders').delete().eq('path', folderPath);
    } catch (e) {
      throw Exception('Failed to delete folder $folderPath: $e');
    }
  }

  Future<void> renameFolder(String oldPath, String newName) async {
    try {
      final parts = oldPath.split('/');
      parts.removeLast();
      final parentPath = parts.join('/');
      final formattedName = _formatName(newName);
      final newPath = parentPath.isEmpty
          ? formattedName
          : '$parentPath/$formattedName';

      String replacePrefix(String path, String oldPrefix, String newPrefix) {
        if (path.startsWith(oldPrefix)) {
          return newPrefix + path.substring(oldPrefix.length);
        }
        return path;
      }

      final childFolders = await _supabase
          .from('folders')
          .select('path, parent_path')
          .like('path', '$oldPath/%');

      final childNotes = await _supabase
          .from('notes')
          .select('path, folder_path')
          .like('path', '$oldPath/%');

      // Update the parent folder first
      await _supabase
          .from('folders')
          .update({'name': newName, 'path': newPath})
          .eq('path', oldPath);

      // Update paths of all child folders
      for (final folder in List<Map<String, dynamic>>.from(childFolders)) {
        final currentPath = folder['path'] as String;
        final currentParent = folder['parent_path'] as String?;

        final updatedPath = replacePrefix(currentPath, oldPath, newPath);
        final updatedParent = currentParent != null
            ? replacePrefix(currentParent, oldPath, newPath)
            : null;

        await _supabase
            .from('folders')
            .update({'path': updatedPath, 'parent_path': updatedParent})
            .eq('path', currentPath);
      }

      // Update paths of all child notes
      for (final note in List<Map<String, dynamic>>.from(childNotes)) {
        final currentPath = note['path'] as String;
        final currentFolder = note['folder_path'] as String;

        final updatedPath = replacePrefix(currentPath, oldPath, newPath);
        final updatedFolder = replacePrefix(currentFolder, oldPath, newPath);

        await _supabase
            .from('notes')
            .update({'path': updatedPath, 'folder_path': updatedFolder})
            .eq('path', currentPath);
      }
    } catch (e) {
      throw Exception('Failed to rename folder $oldPath: $e');
    }
  }

  Future<void> renameNote(String oldPath, String newName) async {
    try {
      final parts = oldPath.split('/');
      parts.removeLast();
      final folderPath = parts.join('/');
      final formattedName = _formatName(newName);
      final newPath = folderPath.isEmpty
          ? '$formattedName.md'
          : '$folderPath/$formattedName.md';

      await _supabase
          .from('notes')
          .update({'path': newPath, 'name': newName})
          .eq('path', oldPath);
    } catch (e) {
      throw Exception('Failed to rename note $oldPath: $e');
    }
  }

  Future<Map<String, String>> getFolderIcons(String basePath) async {
    try {
      final response = await _supabase
          .from('folder_icons')
          .select('folder_path, icon_key')
          .like('folder_path', '$basePath%');

      final icons = List<Map<String, dynamic>>.from(response);
      final map = <String, String>{};
      for (var row in icons) {
        map[row['folder_path'] as String] = row['icon_key'] as String;
      }
      return map;
    } catch (e) {
      throw Exception('Failed to get folder icons for $basePath: $e');
    }
  }

  Future<void> setFolderIcon(String folderPath, String iconKey) async {
    try {
      await _supabase.from('folder_icons').upsert({
        'folder_path': folderPath,
        'icon_key': iconKey,
      });
    } catch (e) {
      throw Exception('Failed to set folder icon for $folderPath: $e');
    }
  }

  Future<DateTime?> getLastModified(String notePath) async {
    try {
      final response = await _supabase
          .from('notes')
          .select('updated_at')
          .eq('path', notePath)
          .maybeSingle();

      if (response != null && response['updated_at'] != null) {
        return DateTime.parse(response['updated_at'] as String);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get last modified for $notePath: $e');
    }
  }

  Future<void> updateSortOrder(List<Map<String, dynamic>> items) async {
    try {
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final path = item['path'] as String;
        final isFolder = item['type'] == 'dir';
        final table = isFolder ? 'folders' : 'notes';

        await _supabase.from(table).update({'sort_index': i}).eq('path', path);
      }
    } catch (e) {
      throw Exception('Failed to update sort order: $e');
    }
  }

  /// Hide a note (soft delete - move to trash)
  Future<void> hideNote(String notePath) async {
    // Note: 'notes' table doesn't have is_hidden. 
    // Hiding is handled via TrashService (Firestore).
  }

  /// Hide a folder (soft delete - move to trash)
  Future<void> hideFolder(String folderPath) async {
    try {
      // Hide the folder itself
      await _supabase
          .from('folders')
          .update({'is_hidden': true})
          .eq('path', folderPath);
      // Hide all subfolders
      await _supabase
          .from('folders')
          .update({'is_hidden': true})
          .like('path', '$folderPath/%');
    } catch (e) {
      throw Exception('Failed to hide folder $folderPath: $e');
    }
  }

  /// Unhide a note (restore from trash)
  Future<void> unhideNote(String notePath) async {
    // Hiding is handled via TrashService (Firestore).
  }

  /// Unhide a folder (restore from trash)
  Future<void> unhideFolder(String folderPath) async {
    try {
      // Unhide the folder itself
      await _supabase
          .from('folders')
          .update({'is_hidden': false})
          .eq('path', folderPath);
      // Unhide all subfolders
      await _supabase
          .from('folders')
          .update({'is_hidden': false})
          .like('path', '$folderPath/%');
    } catch (e) {
      throw Exception('Failed to unhide folder $folderPath: $e');
    }
  }
}
