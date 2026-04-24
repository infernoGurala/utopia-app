import 'dart:convert';

import 'package:http/http.dart' as http;

/// Google Apps Script (GAS) middleware service for attendance fetching.
///
/// Replace [ausGasUrl] and [acetGasUrl] with your deployed GAS web app URLs.
/// The GAS script handles login + scraping server-side so the app never
/// touches the university portal directly.
class GasAttendanceService {
  // ──────────────────────────────────────────────────────────────────────────
  // ★  Update these URLs after deploying your Google Apps Script web apps  ★
  // Both URLs MUST use HTTPS (as all script.google.com URLs do) so that
  // credentials are encrypted in transit.
  // ──────────────────────────────────────────────────────────────────────────
  static const String ausGasUrl =
      'https://script.google.com/macros/s/YOUR_AUS_SCRIPT_ID/exec';
  static const String acetGasUrl =
      'https://script.google.com/macros/s/YOUR_ACET_SCRIPT_ID/exec';
  // ──────────────────────────────────────────────────────────────────────────

  static const Duration _timeout = Duration(seconds: 45);

  /// Fetches attendance via the GAS middleware endpoint.
  ///
  /// [college] must be `'aus'` or `'acet'`.
  /// [fromDate] / [toDate] are optional date strings in `dd-MM-yyyy` format;
  /// leave empty to fetch the full semester.
  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String college = 'aus',
    String fromDate = '',
    String toDate = '',
  }) async {
    final url = college == 'acet' ? acetGasUrl : ausGasUrl;

    // Runtime guard: fail fast with a clear message if the URLs are still placeholders
    if (url.contains('YOUR_') || url.contains('_SCRIPT_ID')) {
      throw Exception(
        'Google Apps Script URL for $college has not been configured yet. '
        'Update GasAttendanceService.${college == 'acet' ? 'acetGasUrl' : 'ausGasUrl'} '
        'with your deployed GAS web app URL.',
      );
    }

    // Debug: log the outgoing request (credentials redacted in production)
    // ignore: avoid_print
    print(
      '[GAS] fetchAttendance → college=$college, '
      'roll=${rollNumber.trim()}, '
      'fromDate=${fromDate.isEmpty ? "empty" : fromDate}, '
      'toDate=${toDate.isEmpty ? "empty" : toDate}, '
      'url=$url',
    );

    final payload = jsonEncode({
      'rollNumber': rollNumber.trim(),
      'password': password,
      'college': college,
      'fromDate': fromDate,
      'toDate': toDate,
    });

    // ignore: avoid_print
    print('[GAS] POST payload size: ${payload.length} bytes');

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: payload,
          )
          .timeout(_timeout);
    } catch (e) {
      // ignore: avoid_print
      print('[GAS] Network error: $e');
      throw Exception('Could not reach the attendance server. Check your internet connection.');
    }

    // ignore: avoid_print
    print('[GAS] Response status: ${response.statusCode}');
    // ignore: avoid_print
    print(
      '[GAS] Response body preview: '
      '${response.body.length <= 600 ? response.body : response.body.substring(0, 600)}',
    );

    if (response.statusCode != 200) {
      throw Exception('Attendance server returned an error (${response.statusCode})');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      // ignore: avoid_print
      print('[GAS] JSON decode error: $e');
      throw Exception('Unexpected response from the attendance server');
    }

    final success = json['success'] as bool? ?? false;
    if (!success) {
      final error = (json['error'] as String?)?.trim() ?? '';
      // ignore: avoid_print
      print('[GAS] Server returned success=false, error=$error');
      if (error.isEmpty) {
        throw Exception('Could not fetch attendance right now');
      }
      // Preserve friendly error messages from the script (e.g. "Invalid credentials")
      throw Exception(error);
    }

    final data = json['data'];
    if (data == null || data is! Map<String, dynamic>) {
      // ignore: avoid_print
      print('[GAS] Response missing "data" field or wrong type');
      throw Exception('Attendance data was not found in the portal response');
    }

    // ignore: avoid_print
    print(
      '[GAS] fetchAttendance success — '
      'subjects=${(data['subjects'] as List?)?.length ?? 0}, '
      'overall=${data['overallPercentage']}',
    );

    return data;
  }
}
