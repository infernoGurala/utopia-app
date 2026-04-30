import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseNotesService {
  final _supabase = Supabase.instance.client;

  String _slug(String name) {
    return name.toLowerCase().replaceAll(' ', '-');
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    try {
      final response = await _supabase
          .from('folders')
          .select('name, path, is_hidden, sort_index')
          .eq('scope', 'legacy')
          .isFilter('parent_path', null);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get folders: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getFiles(String folderPath) async {
    try {
      final response = await _supabase
          .from('notes')
          .select('name, path, updated_at')
          .eq('folder_path', folderPath);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get files for $folderPath: $e');
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

  Future<void> createFolder(String name) async {
    try {
      await _supabase.from('folders').insert({
        'path': _slug(name),
        'name': name,
        'scope': 'legacy',
        'is_hidden': false,
        'created_by': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      throw Exception('Failed to create folder $name: $e');
    }
  }

  Future<void> createNote(String folderPath, String name, String content) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final path = '$folderPath/${_slug(name)}.md';

      await _supabase.from('notes').insert({
        'path': path,
        'name': name,
        'folder_path': folderPath,
        'content': content,
        'scope': 'legacy',
        'created_by': uid,
      });
    } catch (e) {
      throw Exception('Failed to create note $name in $folderPath: $e');
    }
  }

  Future<void> updateNote(String notePath, String content, String updatedByUid, String updatedByName) async {
    try {
      // Get current note content to save as a version
      final currentNote = await _supabase
          .from('notes')
          .select('content')
          .eq('path', notePath)
          .maybeSingle();

      if (currentNote != null) {
        final currentContent = currentNote['content'] as String?;
        if (currentContent != null) {
          // Insert into note_versions
          await _supabase.from('note_versions').insert({
            'note_path': notePath,
            'content': currentContent,
            'saved_by': updatedByUid,
            'saved_by_name': updatedByName,
          });

          // Keep max 20 versions per note
          final versions = await _supabase
              .from('note_versions')
              .select('id')
              .eq('note_path', notePath)
              .order('saved_at', ascending: false);

          final versionList = List<Map<String, dynamic>>.from(versions);
          if (versionList.length > 20) {
            final idsToDelete = versionList.skip(20).map((v) => v['id'] as String).toList();
            for (final id in idsToDelete) {
              await _supabase.from('note_versions').delete().eq('id', id);
            }
          }
        }
      }

      // Update the main note
      await _supabase.from('notes').update({
        'content': content,
        'updated_by': updatedByUid,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('path', notePath);
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
      // delete notes in folder
      await _supabase.from('notes').delete().eq('folder_path', folderPath);
      // delete folder itself
      await _supabase.from('folders').delete().eq('path', folderPath);
    } catch (e) {
      throw Exception('Failed to delete folder $folderPath: $e');
    }
  }

  Future<void> renameNote(String oldPath, String newName) async {
    try {
      final parts = oldPath.split('/');
      parts.removeLast(); // remove the old filename.md
      final folderPath = parts.join('/');
      final newPath = folderPath.isEmpty ? '${_slug(newName)}.md' : '$folderPath/${_slug(newName)}.md';

      await _supabase.from('notes').update({
        'path': newPath,
        'name': newName,
      }).eq('path', oldPath);
    } catch (e) {
      throw Exception('Failed to rename note $oldPath to $newName: $e');
    }
  }

  Future<void> setFolderHidden(String folderPath, bool hidden) async {
    try {
      await _supabase.from('folders').update({
        'is_hidden': hidden,
      }).eq('path', folderPath);
    } catch (e) {
      throw Exception('Failed to set folder $folderPath hidden to $hidden: $e');
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
}
