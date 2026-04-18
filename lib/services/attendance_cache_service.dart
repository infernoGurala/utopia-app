import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Persists attendance data to Firestore so it survives portal outages.
/// Collection: attendance_cache/{uid}/records/{rollNumber}
class AttendanceCacheService {
  static final _firestore = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? _ref(String rollNumber) {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('attendance_cache')
        .doc(uid)
        .collection('records')
        .doc(rollNumber.toUpperCase().trim());
  }

  /// Save a successful attendance fetch to Firestore.
  static Future<void> save({
    required String rollNumber,
    required Map<String, dynamic> data,
    required String college,
  }) async {
    final ref = _ref(rollNumber);
    if (ref == null) return;
    try {
      // Subjects list must be JSON-safe (no mixed types)
      final subjects = (data['subjects'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      await ref.set({
        'rollNumber': rollNumber.toUpperCase().trim(),
        'college': college,
        'cachedAt': FieldValue.serverTimestamp(),
        'overallPercentage': data['overallPercentage'] ?? 0.0,
        'totalClasses': data['totalClasses'] ?? 0,
        'totalAttended': data['totalAttended'] ?? 0,
        'studentName': data['studentName'] ?? '',
        'hasReport': data['hasReport'] ?? false,
        'subjectsJson': jsonEncode(subjects),
      });
    } catch (e) {
      debugPrint('AttendanceCacheService: save failed: $e');
    }
  }

  /// Load cached attendance from Firestore.
  /// Returns null if no cache exists.
  static Future<CachedAttendance?> load(String rollNumber) async {
    final ref = _ref(rollNumber);
    if (ref == null) return null;
    try {
      final doc = await ref.get();
      if (!doc.exists || doc.data() == null) return null;

      final d = doc.data()!;
      final cachedAt = (d['cachedAt'] as Timestamp?)?.toDate();
      if (cachedAt == null) return null;

      final subjectsJson = d['subjectsJson'] as String? ?? '[]';
      final subjects = (jsonDecode(subjectsJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();

      return CachedAttendance(
        cachedAt: cachedAt,
        data: {
          'overallPercentage': (d['overallPercentage'] as num?)?.toDouble() ?? 0.0,
          'totalClasses': d['totalClasses'] ?? 0,
          'totalAttended': d['totalAttended'] ?? 0,
          'studentName': d['studentName'] ?? '',
          'hasReport': d['hasReport'] ?? false,
          'subjects': subjects,
        },
      );
    } catch (e) {
      debugPrint('AttendanceCacheService: load failed: $e');
      return null;
    }
  }

  /// Delete cached attendance (called on disconnect).
  static Future<void> clear(String rollNumber) async {
    final ref = _ref(rollNumber);
    if (ref == null) return;
    try {
      await ref.delete();
    } catch (e) {
      debugPrint('AttendanceCacheService: clear failed: $e');
    }
  }
}

class CachedAttendance {
  const CachedAttendance({required this.cachedAt, required this.data});
  final DateTime cachedAt;
  final Map<String, dynamic> data;

  String get ageLabel {
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
