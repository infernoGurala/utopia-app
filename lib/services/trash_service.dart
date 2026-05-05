import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'supabase_global_service.dart';

/// Service for managing community notes soft-deletion (trash).
///
/// Items moved to trash are stored in Firestore under:
///   `community_trash/{universityId}/items/{docId}`
///
/// Each trash document stores:
///   - path: original file/folder path in the repo
///   - name: display name
///   - type: 'file' or 'dir'
///   - deletedAt: server timestamp
///   - deletedBy: uid of user who deleted
///   - deletedByName: display name
///   - permanentDeleteAt: timestamp 30 days from deletion
///   - restored: boolean (set to true when restored)
class TrashService {
  final String universityId;
  TrashService({required this.universityId});

  CollectionReference<Map<String, dynamic>> get _trashCol => FirebaseFirestore
      .instance
      .collection('community_trash')
      .doc(universityId)
      .collection('items');

  /// Move an item to trash (soft delete).
  Future<void> moveToTrash({
    required String path,
    required String name,
    required String type,
    required String universityId,
    SupabaseGlobalService? github,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Check if already in trash (prevent duplicates)
      final existing = await _trashCol
          .where('path', isEqualTo: path)
          .limit(5)
          .get();

      final isAlreadyTrashed = existing.docs.any(
        (d) => (d.data()['restored'] ?? false) == false,
      );
      if (isAlreadyTrashed) {
        debugPrint("TRASH: Item already in trash: $path");
        return;
      }

      final now = DateTime.now();
      final permanentDeleteDate = now.add(const Duration(days: 30));

      // Actually hide the item in Supabase
      if (github != null) {
        try {
          if (type == 'file') {
            await github.hideNote(path);
          } else {
            await github.hideFolder(path);
          }
        } catch (e) {
          debugPrint("TRASH: Failed to hide $path in Supabase: $e");
        }
      }

      await _trashCol.add({
        'path': path,
        'name': name,
        'type': type,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': user.uid,
        'deletedByName': user.displayName ?? 'Unknown',
        'permanentDeleteAt': Timestamp.fromDate(permanentDeleteDate),
        'restored': false,
        'universityId': universityId,
      });
      debugPrint("TRASH: Successfully moved to trash: $path");
    } catch (e) {
      debugPrint("TRASH: Failed to move to trash: $e");
      rethrow;
    }
  }

  /// Check if a given path is in the trash (soft-deleted).
  Future<bool> isInTrash(String path) async {
    final snap = await _trashCol
        .where('path', isEqualTo: path)
        .where('restored', isEqualTo: false)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Get all trashed item paths (for filtering display).
  Future<Set<String>> getTrashedPaths() async {
    final snap = await _trashCol.where('restored', isEqualTo: false).get();
    return snap.docs.map((d) => d.data()['path'] as String).toSet();
  }

  /// Stream of all trashed items (for trash view).
  Stream<QuerySnapshot<Map<String, dynamic>>> trashStream() {
    return _trashCol.orderBy('deletedAt', descending: true).snapshots();
  }

  /// Restore an item from trash.
  Future<void> restore(String docId, {SupabaseGlobalService? github}) async {
    // Get the trash item data first
    final doc = await _trashCol.doc(docId).get();
    final data = doc.data();
    if (data != null && github != null) {
      final path = data['path'] as String;
      final type = data['type'] as String;
      // Unhide in Supabase
      try {
        if (type == 'file') {
          await github.unhideNote(path);
        } else {
          await github.unhideFolder(path);
        }
      } catch (e) {
        debugPrint("TRASH: Failed to unhide $path: $e");
      }
    }

    await _trashCol.doc(docId).update({
      'restored': true,
      'restoredAt': FieldValue.serverTimestamp(),
      'restoredBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  /// Request permanent deletion. Actually deletes the file/folder
  /// via the provided callback and removes the trash record.
  Future<void> permanentlyDelete({
    required String docId,
    required Future<void> Function() deleteCallback,
  }) async {
    await deleteCallback();
    await _trashCol.doc(docId).delete();
  }

  /// Get days remaining until permanent auto-deletion.
  int daysRemaining(Timestamp? permanentDeleteAt) {
    if (permanentDeleteAt == null) return 30;
    final deadline = permanentDeleteAt.toDate();
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining.clamp(0, 30);
  }
}
