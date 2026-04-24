import 'package:flutter/foundation.dart';
import 'attendance_cache_service.dart';
import 'gas_attendance_service.dart';

export 'attendance_cache_service.dart' show CachedAttendance;

enum AttendanceRangeMode { period, tillNow }

class AttendanceService {
  /// Fetches attendance via the Google Apps Script middleware.
  /// On success → saves to Firestore cache.
  /// On failure → falls back to Firestore cache.
  ///
  /// Returns a map with an extra key:
  ///   'fromCache': true/false
  ///   'cachedAt': DateTime? (only when fromCache == true)
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
    AttendanceRangeMode mode = AttendanceRangeMode.period,
  }) async {
    debugPrint(
      '[AttendanceService] fetchAttendance: college=$college, '
      'roll=$rollNumber, fromDate=$fromDate, toDate=$toDate, mode=$mode',
    );
    try {
      // ── Live fetch via Google Apps Script middleware ──
      final Map<String, dynamic> result;
      result = await GasAttendanceService.fetchAttendance(
        rollNumber,
        password,
        college: college,
        fromDate: fromDate,
        toDate: toDate,
      );

      // Save to cache (non-blocking)
      AttendanceCacheService.save(
        rollNumber: rollNumber,
        data: result,
        college: college,
      ).catchError((e) {
        debugPrint('AttendanceService: background cache save failed: $e');
        return null;
      });

      return {...result, 'fromCache': false, 'cachedAt': null};
    } catch (liveError) {
      debugPrint('AttendanceService: live fetch failed ($liveError), trying cache…');

      // ── Cache fallback ──
      final cached = await AttendanceCacheService.load(rollNumber);
      if (cached != null) {
        return {
          ...cached.data,
          'fromCache': true,
          'cachedAt': cached.cachedAt,
          'cacheAgeLabel': cached.ageLabel,
        };
      }

      // No cache available — rethrow original error
      rethrow;
    }
  }
}
