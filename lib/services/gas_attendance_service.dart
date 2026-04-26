import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Cloudflare Worker attendance API service.
///
/// Replaces the old Google Apps Script middleware. The Worker handles
/// portal login + scraping server-side and returns clean JSON.
class GasAttendanceService {
  static const String _workerUrl =
      'https://attendance-api.inferalis.space/login';

  static const String _healthUrl =
      'https://attendance-api.inferalis.space/health';

  static const Duration _timeout = Duration(seconds: 45);

  /// Fetches attendance via the Cloudflare Worker endpoint.
  ///
  /// [college] must be `'aus'` or `'acet'`.
  /// [fromDate] / [toDate] are accepted for API compatibility but
  /// the Worker always returns full-semester data.
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
  }) async {
    final trimmedRoll = rollNumber.trim();

    debugPrint('[ATT] ═══════════════════════════════════════════');
    debugPrint('[ATT] Starting fetch for roll: $trimmedRoll, college: $college');
    debugPrint('[ATT] Password length: ${password.length}');
    debugPrint('[ATT] API URL: $_workerUrl');
    debugPrint('[ATT] Using http package: ${http.Client}');

    // ── Health check ──
    try {
      debugPrint('[ATT] Running health check: $_healthUrl');
      final healthResponse = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 10));
      debugPrint('[ATT] Health check status: ${healthResponse.statusCode}');
      debugPrint(
        '[ATT] Health check body: '
        '${healthResponse.body.substring(0, min(200, healthResponse.body.length))}',
      );
    } catch (healthError) {
      debugPrint('[ATT] Health check FAILED: $healthError');
      debugPrint('[ATT] This indicates a network/DNS/URL issue');
    }

    // ── Build request ──
    final body = {
      'rollNumber': trimmedRoll,
      'password': password,
      'college': college,
    };
    final payload = jsonEncode(body);

    debugPrint('[ATT] Request body: $payload');
    debugPrint('[ATT] Request body size: ${payload.length} bytes');

    // ── Make the API call ──
    final http.Response response;
    try {
      debugPrint('[ATT] Sending POST request...');
      response = await http
          .post(
            Uri.parse(_workerUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(_timeout);
    } catch (e, stackTrace) {
      debugPrint('[ATT] Network exception type: ${e.runtimeType}');
      debugPrint('[ATT] Network exception message: $e');
      debugPrint('[ATT] Stack trace: $stackTrace');
      throw Exception(
        'Could not reach the attendance server. Check your internet connection.',
      );
    }

    // ── Log raw response ──
    debugPrint('[ATT] Response status code: ${response.statusCode}');
    debugPrint(
      '[ATT] Response body (first 500 chars): '
      '${response.body.substring(0, min(500, response.body.length))}',
    );
    debugPrint('[ATT] Response body length: ${response.body.length}');
    debugPrint('[ATT] Response headers: ${response.headers}');

    if (response.statusCode != 200) {
      debugPrint('[ATT] Non-200 status code, throwing error');
      throw Exception(
        'Attendance server returned an error (${response.statusCode})',
      );
    }

    // ── Parse JSON ──
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[ATT] JSON parsed successfully');
      debugPrint('[ATT] Top-level keys: ${json.keys.toList()}');
    } catch (e, stackTrace) {
      debugPrint('[ATT] JSON decode error: $e');
      debugPrint('[ATT] JSON decode stack: $stackTrace');
      throw Exception('Unexpected response from the attendance server');
    }

    // ── Check ok field ──
    final ok = json['ok'] as bool? ?? false;
    debugPrint('[ATT] Parsed ok field: $ok');

    if (!ok) {
      final error = (json['error'] as String?)?.trim() ?? '';
      debugPrint('[ATT] Server returned ok=false, error="$error"');
      if (error.isEmpty) {
        throw Exception('Could not fetch attendance right now');
      }
      throw Exception(error);
    }

    // ── Extract data ──
    final data = json['data'];
    debugPrint('[ATT] data field type: ${data.runtimeType}');

    if (data == null || data is! Map<String, dynamic>) {
      debugPrint('[ATT] Response missing "data" field or wrong type');
      debugPrint('[ATT] Full response keys: ${json.keys.toList()}');
      throw Exception(
        'Attendance data was not found in the server response',
      );
    }

    debugPrint('[ATT] Parsed data keys: ${data.keys.toList()}');
    debugPrint('[ATT] Subject count: ${(data['subjects'] as List?)?.length}');
    debugPrint('[ATT] Overall percentage: ${data['overallPercentage']}');
    debugPrint('[ATT] Total classes: ${data['totalClasses']}');
    debugPrint('[ATT] Total attended: ${data['totalAttended']}');
    debugPrint('[ATT] Student name: ${data['studentName']}');
    debugPrint('[ATT] Has report: ${data['hasReport']}');

    // Log first subject for verification
    final subjects = data['subjects'] as List?;
    if (subjects != null && subjects.isNotEmpty) {
      final first = subjects[0];
      debugPrint('[ATT] First subject sample: $first');
      debugPrint('[ATT]   subject: ${first['subject']}');
      debugPrint('[ATT]   totalClasses: ${first['totalClasses']}');
      debugPrint('[ATT]   attendedClasses: ${first['attendedClasses']}');
      debugPrint('[ATT]   percentage: ${first['percentage']}');
    }

    debugPrint('[ATT] ✓ fetchAttendance completed successfully');
    debugPrint('[ATT] ═══════════════════════════════════════════');

    return data;
  }
}
