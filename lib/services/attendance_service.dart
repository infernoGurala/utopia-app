import 'package:flutter/foundation.dart';
import 'acet_attendance_service.dart';
import 'attendance_cache_service.dart';
import 'attendance_server_preference.dart';
import 'aus_attendance_service.dart';
import 'gas_attendance_service.dart';

export 'attendance_cache_service.dart' show CachedAttendance;

enum AttendanceRangeMode { period, tillNow }

class AttendanceService {
  /// Fetches attendance using the user's preferred server.
  ///
  /// Server 1 (In-App): scrapes directly via AUS/ACET services on-device.
  ///   On failure → automatically retries with Server 2 (Cloud) as fallback.
  /// Server 2 (Cloud): calls Cloudflare Worker via GasAttendanceService.
  ///   No fallback.
  ///
  /// On success → saves to Firestore cache.
  /// On failure → falls back to Firestore cache.
  ///
  /// Returns a map with extra keys:
  ///   'fromCache': true/false
  ///   'cachedAt': DateTime? (only when fromCache == true)
  ///   'serverUsed': 'server1' | 'server2' (which server produced the data)
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
    AttendanceRangeMode mode = AttendanceRangeMode.period,
  }) async {
    final server = await AttendanceServerPreference.getServer();
    debugPrint(
      '[AttendanceService] fetchAttendance: server=$server, college=$college, '
      'roll=$rollNumber, fromDate=$fromDate, toDate=$toDate, mode=$mode',
    );

    try {
      Map<String, dynamic> result;
      String actualServer = server;

      if (server == AttendanceServerPreference.kServer1) {
        // ── Server 1: In-App scraping ──
        try {
          debugPrint('[AttendanceService] Trying Server 1 (In-App)…');
          if (college == 'acet') {
            result = await AcetAttendanceService.fetchAttendance(
              rollNumber,
              password,
              fromDate: fromDate,
              toDate: toDate,
              mode: mode,
            );
          } else {
            result = await AusAttendanceService.fetchAttendance(
              rollNumber,
              password,
              fromDate: fromDate,
              toDate: toDate,
            );
          }
          actualServer = AttendanceServerPreference.kServer1;
        } catch (server1Error) {
          // Server 1 failed → fallback to Server 2 (Cloud)
          debugPrint(
            '[AttendanceService] Server 1 failed ($server1Error), '
            'falling back to Server 2 (Cloud)…',
          );
          try {
            final fallbackResult = await GasAttendanceService.fetchAttendance(
              rollNumber,
              password,
              college: college,
              fromDate: fromDate,
              toDate: toDate,
            );
            result = fallbackResult;
            actualServer = AttendanceServerPreference.kServer2;
          } catch (server2Error) {
            debugPrint(
              '[AttendanceService] Server 2 fallback also failed: $server2Error',
            );
            // Both servers failed — rethrow original Server 1 error
            throw server1Error;
          }
        }
      } else {
        // ── Server 2: Cloud (no fallback) ──
        debugPrint('[AttendanceService] Using Server 2 (Cloud) directly…');
        result = await GasAttendanceService.fetchAttendance(
          rollNumber,
          password,
          college: college,
          fromDate: fromDate,
          toDate: toDate,
        );
        actualServer = AttendanceServerPreference.kServer2;
      }

      debugPrint('[AttendanceService] Success via $actualServer');

      // Save to cache (non-blocking)
      AttendanceCacheService.save(
        rollNumber: rollNumber,
        data: result,
        college: college,
      ).catchError((e) {
        debugPrint('AttendanceService: background cache save failed: $e');
        return null;
      });

      return {
        ...result,
        'fromCache': false,
        'cachedAt': null,
        'serverUsed': actualServer,
      };
    } catch (liveError) {
      debugPrint(
        'AttendanceService: live fetch failed ($liveError), trying cache…',
      );

      // ── Cache fallback ──
      final cached = await AttendanceCacheService.load(rollNumber);
      if (cached != null) {
        return {
          ...cached.data,
          'fromCache': true,
          'cachedAt': cached.cachedAt,
          'cacheAgeLabel': cached.ageLabel,
          'serverUsed': 'cache',
        };
      }

      // No cache available — rethrow original error
      rethrow;
    }
  }
}
