import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;

class AttendanceService {
  static const String _portalHost = 'info.aec.edu.in';
  static const String _loginPath = '/aus/default.aspx';
  static const String _attendancePath =
      '/aus/Academics/studentattendance.aspx/ShowAttendance';
  static const String _attendancePagePath =
      '/aus/Academics/studentattendance.aspx?scrid=3&showtype=SA';
  static const String _aesSecret = '8701661282118308';
  static const Duration _timeout = Duration(seconds: 20);
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14; vivo I2305) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/123.0.0.0 Mobile Safari/537.36';

  static Future<String> _encryptPassword(String password) async {
    final key = encrypt.Key.fromUtf8(_aesSecret);
    final iv = encrypt.IV.fromUtf8(_aesSecret);
    final aes = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    return aes.encrypt(password, iv: iv).base64;
  }

  static Future<Map<String, String>> _getLoginTokens(
    HttpClient client,
    Map<String, String> cookies,
  ) async {
    final response = await _sendRequest(
      client,
      method: 'GET',
      path: _loginPath,
      cookies: cookies,
      followRedirects: true,
    );
    _debugResponse('GET login page', response.statusCode, response.body);

    final viewState = _extractHiddenInput(response.body, '__VIEWSTATE');
    final viewStateGenerator = _extractHiddenInput(
      response.body,
      '__VIEWSTATEGENERATOR',
    );
    final eventValidation = _extractHiddenInput(
      response.body,
      '__EVENTVALIDATION',
    );

    return {
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      '__EVENTVALIDATION': eventValidation,
    };
  }

  static Future<Map<String, String>> _login(
    HttpClient client,
    String rollNumber,
    String password,
    Map<String, String> cookies,
  ) async {
    try {
      final tokens = await _getLoginTokens(client, cookies);
      final encryptedPassword = await _encryptPassword(password);
      final formBody = <String, String>{
        '__VIEWSTATE': tokens['__VIEWSTATE'] ?? '',
        '__VIEWSTATEGENERATOR': tokens['__VIEWSTATEGENERATOR'] ?? '',
        '__EVENTVALIDATION': tokens['__EVENTVALIDATION'] ?? '',
        'txtId1': '',
        'txtPwd1': encryptedPassword,
        'txtId2': rollNumber.trim(),
        'txtPwd2': encryptedPassword,
        'imgBtn2.x': '36',
        'imgBtn2.y': '4',
        'txtId3': '',
        'txtPwd3': '',
        'hdnpwd1': encryptedPassword,
        'hdnpwd2': encryptedPassword,
        'hdnpwd3': '',
      };

      final response = await _sendRequest(
        client,
        method: 'POST',
        path: _loginPath,
        cookies: cookies,
        followRedirects: false,
        contentType: 'application/x-www-form-urlencoded',
        body: Uri(queryParameters: formBody).query,
        extraHeaders: {
          'origin': 'https://$_portalHost',
          HttpHeaders.refererHeader: 'https://$_portalHost$_loginPath',
        },
      );
      _debugResponse('POST login', response.statusCode, response.body);

      final location = response.location ?? '';
      final sessionId = cookies['ASP.NET_SessionId'];
      final frmAuth = cookies['frmAuth'];
      final redirectedToStudentMaster =
          (response.statusCode == HttpStatus.movedTemporarily ||
              response.statusCode == HttpStatus.found ||
              response.statusCode == HttpStatus.movedPermanently) &&
          location.toLowerCase().contains('studentmaster.aspx');

      if (!redirectedToStudentMaster ||
          sessionId == null ||
          frmAuth == null ||
          sessionId.isEmpty ||
          frmAuth.isEmpty) {
        throw Exception('Invalid credentials');
      }

      return {'sessionId': sessionId, 'frmAuth': frmAuth};
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is Exception && e.toString().contains('Invalid credentials')) {
        rethrow;
      }
      throw Exception('Could not sign in to the college portal');
    }
  }

  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String fromDate = '',
    String toDate = '',
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    final cookies = <String, String>{};
    try {
      await _login(client, rollNumber, password, cookies);
      final attendanceBody = jsonEncode({
        'fromDate': fromDate,
        'toDate': toDate,
        'excludeothersubjects': false,
      });
      // ignore: avoid_print
      print('Attendance request url: https://$_portalHost$_attendancePath');
      // ignore: avoid_print
      print('Attendance request body: $attendanceBody');
      final response = await _sendRequest(
        client,
        method: 'POST',
        path: _attendancePath,
        cookies: cookies,
        followRedirects: false,
        contentType: 'application/json; charset=UTF-8',
        body: attendanceBody,
        extraHeaders: {
          'origin': 'https://$_portalHost',
          HttpHeaders.refererHeader: 'https://$_portalHost$_attendancePagePath',
          'x-requested-with': 'XMLHttpRequest',
        },
      );
      _debugResponse('POST attendance', response.statusCode, response.body);

      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Could not fetch attendance right now');
      }

      // Response is now JSON: {"d": "<HTML>"}
      String attendanceHtml;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        attendanceHtml = decoded['d'] as String? ?? '';
      } catch (_) {
        // Fallback: treat as raw HTML for backwards compatibility
        attendanceHtml = response.body;
      }
      // ignore: avoid_print
      print('Attendance extracted HTML:\n$attendanceHtml');

      final parsed = _parseAttendanceHtml(attendanceHtml);
      final hasReport = parsed['hasReport'] as bool? ?? false;
      if ((parsed['subjects'] as List).isEmpty && !hasReport) {
        throw Exception('Attendance data was not found in the portal response');
      }
      return parsed;
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('Invalid credentials') ||
              e.toString().contains('Attendance data was not found') ||
              e.toString().contains('Could not fetch attendance'))) {
        rethrow;
      }
      throw Exception('Unable to load attendance right now');
    } finally {
      client.close(force: true);
    }
  }

  static Future<_PortalResponse> _sendRequest(
    HttpClient client, {
    required String method,
    required String path,
    required Map<String, String> cookies,
    required bool followRedirects,
    String? body,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) async {
    var currentUri = Uri.parse('https://$_portalHost$path');
    var currentMethod = method;
    var redirectCount = 0;

    while (true) {
      final request = await _openRequest(client, currentMethod, currentUri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-IN,en;q=0.9');
      if (cookies.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, _cookieHeader(cookies));
      }
      if (contentType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      extraHeaders?.forEach(request.headers.set);
      if (body != null) {
        final bytes = utf8.encode(body);
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close().timeout(_timeout);
      final responseBody = await _readResponseBody(response);
      _captureCookies(response.cookies, cookies);

      if (!followRedirects || !_isRedirect(response.statusCode)) {
        return _PortalResponse(
          statusCode: response.statusCode,
          body: responseBody,
          location: response.headers.value(HttpHeaders.locationHeader),
        );
      }

      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) {
        return _PortalResponse(
          statusCode: response.statusCode,
          body: responseBody,
        );
      }
      if (redirectCount >= 8) {
        throw Exception('Portal redirected too many times');
      }

      currentUri = currentUri.resolve(location);
      currentMethod = 'GET';
      redirectCount += 1;
    }
  }

  static Future<HttpClientRequest> _openRequest(
    HttpClient client,
    String method,
    Uri uri,
  ) {
    switch (method.toUpperCase()) {
      case 'POST':
        return client.postUrl(uri);
      case 'GET':
      default:
        return client.getUrl(uri);
    }
  }

  static bool _isRedirect(int statusCode) {
    return statusCode == HttpStatus.movedPermanently ||
        statusCode == HttpStatus.found ||
        statusCode == HttpStatus.movedTemporarily ||
        statusCode == HttpStatus.seeOther ||
        statusCode == HttpStatus.temporaryRedirect ||
        statusCode == HttpStatus.permanentRedirect;
  }

  static void _captureCookies(
    List<Cookie> responseCookies,
    Map<String, String> cookies,
  ) {
    for (final cookie in responseCookies) {
      cookies[cookie.name] = cookie.value;
    }
  }

  static String _cookieHeader(Map<String, String> cookies) {
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  static Map<String, dynamic> _parseAttendanceHtml(String html) {
    final subjects = <Map<String, dynamic>>[];
    int? totalHeldFromReport;
    int? totalAttendedFromReport;
    double? totalPercentageFromReport;
    var hasReport = false;
    final plainText = _cleanHtmlText(html);
    final studentName = _extractLabeledValue(plainText, 'Student Name');
    final rowMatches = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final row in rowMatches) {
      final rowHtml = row.group(1) ?? '';
      final cellMatches = RegExp(
        r'<t[dh][^>]*>(.*?)</t[dh]>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(rowHtml);
      if (cellMatches.length < 4) {
        continue;
      }

      final cells = cellMatches
          .map((cell) => _cleanHtmlText(cell.group(1) ?? ''))
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.length < 4) {
        continue;
      }

      final subjectIndex = cells.indexWhere(_looksLikeSubjectCell);
      if (subjectIndex == -1) {
        continue;
      }

      final subject = cells[subjectIndex];
      final numericTail = cells.sublist(subjectIndex + 1);
      final totalClasses = _firstInt(numericTail);
      final attendedClasses = _secondInt(numericTail);
      final percentage = _extractPercentage(numericTail);

      if (subject.toLowerCase() == 'total') {
        hasReport = true;
        totalHeldFromReport = totalClasses;
        totalAttendedFromReport = attendedClasses;
        totalPercentageFromReport = percentage;
        continue;
      }

      if (subject.toLowerCase().contains('subject') ||
          totalClasses == null ||
          attendedClasses == null ||
          percentage == null) {
        continue;
      }

      subjects.add({
        'subject': subject,
        'totalClasses': totalClasses,
        'attendedClasses': attendedClasses,
        'percentage': percentage,
      });
    }

    final totalHeld = subjects.fold<int>(
      0,
      (sum, item) => sum + ((item['totalClasses'] as int?) ?? 0),
    );
    final totalAttended = subjects.fold<int>(
      0,
      (sum, item) => sum + ((item['attendedClasses'] as int?) ?? 0),
    );
    final overallPercentage = totalHeld == 0
        ? 0.0
        : (totalAttended / totalHeld) * 100;

    return {
      'overallPercentage': double.parse(
        (totalPercentageFromReport ?? overallPercentage).toStringAsFixed(1),
      ),
      'totalClasses': totalHeldFromReport ?? totalHeld,
      'totalAttended': totalAttendedFromReport ?? totalAttended,
      'subjects': subjects,
      'studentName': studentName,
      'hasReport': hasReport,
      'rawHtml': html,
    };
  }

  static String? _extractLabeledValue(String plainText, String label) {
    final match = RegExp(
      '$label\\s*:\\s*(.*?)\\s*(?=RollNo\\s*:|Student Name\\s*:|Course\\s*:|Branch\\s*:|Semester\\s*:|\$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(plainText);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String _extractHiddenInput(String html, String fieldName) {
    final patterns = [
      RegExp(
        'id="$fieldName"[^>]*value="([^"]*)"',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        'name="$fieldName"[^>]*value="([^"]*)"',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        "id='$fieldName'[^>]*value='([^']*)'",
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        "name='$fieldName'[^>]*value='([^']*)'",
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = match?.group(1);
      if (value != null) {
        return value;
      }
    }

    throw const FormatException('Portal login tokens were not found');
  }

  static bool _looksLikeSubjectCell(String value) {
    final lower = value.toLowerCase();
    if (!RegExp(r'[a-z]').hasMatch(lower)) {
      return false;
    }
    return !lower.contains('percentage') &&
        !lower.contains('attended') &&
        !lower.contains('held') &&
        !lower.contains('total');
  }

  static int? _firstInt(List<String> values) {
    for (final value in values) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  static int? _secondInt(List<String> values) {
    var seen = 0;
    for (final value in values) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match == null) {
        continue;
      }
      seen += 1;
      if (seen == 2) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  static double? _extractPercentage(List<String> values) {
    for (final value in values.reversed) {
      final normalized = value.startsWith('.') ? '0$value' : value;
      final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!);
        if (parsed != null && parsed <= 100) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String _cleanHtmlText(String input) {
    final withoutTags = input.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final decoded = withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Future<String> _readResponseBody(HttpClientResponse response) async {
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, data) => buffer..addAll(data),
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  static void _debugResponse(String label, int statusCode, String body) {
    final preview = body.length <= 500 ? body : body.substring(0, 500);
    // ignore: avoid_print
    print('$label response code: $statusCode');
    // ignore: avoid_print
    print('$label response body preview: $preview');
  }
}

class _PortalResponse {
  const _PortalResponse({
    required this.statusCode,
    required this.body,
    this.location,
  });

  final int statusCode;
  final String body;
  final String? location;
}
