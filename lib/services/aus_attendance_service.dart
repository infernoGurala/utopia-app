import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide Cookie;

import 'attendance_service.dart';

class AusAttendanceService {
  static const String _portalHost = 'info.aec.edu.in';
  static const String _aesSecret = '8701661282118308';
  static const String _prefix = '/aus';
  static const String _loginPath = '$_prefix/default.aspx';
  static const String _studentMasterPath = '$_prefix/StudentMaster.aspx';
  static const String _attendancePagePath =
      '$_prefix/Academics/studentattendance.aspx?scrid=3&showtype=SA';
  static const String _attendancePath =
      '$_prefix/Academics/studentattendance.aspx/ShowAttendance';
  static const String _ajaxJsPath = '$_prefix/JSFiles/AjaxMethods.js';

  static const Duration _timeout = Duration(seconds: 20);
  static String _userAgent =
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

  static Future<Map<String, String>> _loginViaWebView(
    String rollNumber,
    String password,
  ) async {
    print('[AusAttendanceService] _loginViaWebView: started for $rollNumber');
    final completer = Completer<Map<String, String>>();
    final encryptedPassword = await _encryptPassword(password);
    print('[AusAttendanceService] _loginViaWebView: password encrypted');
    
    HeadlessInAppWebView? headlessWebView;
    Timer? timeoutTimer;

    void cleanup() {
      print('[AusAttendanceService] _loginViaWebView: cleaning up...');
      timeoutTimer?.cancel();
      try {
        headlessWebView?.dispose();
        print('[AusAttendanceService] _loginViaWebView: WebView disposed.');
      } catch (e) {
        print('[AusAttendanceService] _loginViaWebView: dispose error: $e');
      }
    }

    timeoutTimer = Timer(const Duration(seconds: 30), () {
      print('[AusAttendanceService] _loginViaWebView: 30s TIMEOUT reached!');
      cleanup();
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Could not sign in to the college portal'),
        );
      }
    });

    print('[AusAttendanceService] _loginViaWebView: constructing HeadlessInAppWebView');
    headlessWebView = HeadlessInAppWebView(
      initialSize: const Size(360, 800),
      initialUrlRequest: URLRequest(
        url: WebUri('https://$_portalHost$_loginPath'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        thirdPartyCookiesEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        userAgent: _userAgent,
      ),
      onLoadStart: (controller, url) {
        print('[AusAttendanceService] WebView LoadStart: $url');
      },
      onLoadStop: (controller, url) async {
        final currentUrl = url?.toString() ?? '';
        print('[AusAttendanceService] WebView LoadStop: $currentUrl');
        
        if (currentUrl.contains('default.aspx')) {
          print('[AusAttendanceService] WebView default.aspx detected. Waiting for DOM...');
          
          // 1. Wait for username input to be present in DOM
          bool isFormReady = false;
          for (int i = 0; i < 20; i++) {
            if (completer.isCompleted) {
              print('[AusAttendanceService] WebView: task completed/timed out during DOM check. Aborting.');
              return;
            }
            final checkForm = "document.querySelector('#txtUserId') !== null";
            final res = await controller.evaluateJavascript(source: checkForm);
            if (res == true) {
              isFormReady = true;
              break;
            }
            await Future.delayed(const Duration(milliseconds: 300));
          }
          print('[AusAttendanceService] WebView form ready: $isFormReady');
          
          if (!isFormReady) {
            print('[AusAttendanceService] WebView: Form elements not detected. Aborting.');
            return;
          }

          // 2. Check if Turnstile captcha is actually present on the page
          final checkTurnstilePresence = "document.querySelector('.cf-turnstile') !== null || document.querySelector('[class*=\"cf-\"]') !== null || document.querySelector('iframe[src*=\"cloudflare\"]') !== null || document.querySelector('[name=\"cf-turnstile-response\"]') !== null";
          final hasTurnstile = await controller.evaluateJavascript(source: checkTurnstilePresence) == true;
          print('[AusAttendanceService] WebView hasTurnstile: $hasTurnstile');

          if (hasTurnstile) {
            print('[AusAttendanceService] WebView polling for Turnstile token...');
            String turnstileToken = '';
            for (int i = 0; i < 30; i++) {
              if (completer.isCompleted) {
                print('[AusAttendanceService] WebView: task completed/timed out during Turnstile check. Aborting.');
                return;
              }
              final checkToken = "var el = document.querySelector('[name=\"cf-turnstile-response\"]'); el ? el.value : '';";
              final tokenRes = await controller.evaluateJavascript(source: checkToken);
              if (tokenRes != null && tokenRes.toString().isNotEmpty) {
                turnstileToken = tokenRes.toString();
                print('[AusAttendanceService] WebView Turnstile solved! Token length: ${turnstileToken.length}');
                break;
              }
              print('[AusAttendanceService] WebView Turnstile not solved yet (attempt ${i + 1}/30)...');
              await Future.delayed(const Duration(milliseconds: 500));
            }

            if (turnstileToken.isEmpty) {
              print('[AusAttendanceService] WebView WARNING: Turnstile token is still empty after 15s!');
            }
          } else {
            print('[AusAttendanceService] WebView: No Turnstile detected. Skipping Turnstile token polling.');
          }

          if (completer.isCompleted) {
            print('[AusAttendanceService] WebView: task completed/timed out before JS injection. Aborting.');
            return;
          }

          print('[AusAttendanceService] WebView Injecting JS credentials...');
          final jsCode = """
            (function() {
              var txtUserId = document.querySelector('#txtUserId') || document.querySelector('#txtId2') || document.querySelector('#txtid2') || document.querySelector('[id*="txtUserId"]') || document.querySelector('[id*="txtId2"]');
              var txtPassword = document.querySelector('#txtPassword') || document.querySelector('#txtPwd2') || document.querySelector('#txtpwd2') || document.querySelector('[id*="txtPassword"]') || document.querySelector('[id*="txtPwd2"]');
              var hdnpwd = document.querySelector('#hdnpwd') || document.querySelector('#hdnpwd1') || document.querySelector('#hdnpwd2') || document.querySelector('#hdnpwd3') || document.querySelector('[id*="hdnpwd"]');
              var rbtStudent = document.querySelector('#rbtStudent') || document.querySelector('#rbtStudent2') || document.querySelector('[id*="rbtStudent"]');

              if (txtUserId) txtUserId.value = '${rollNumber.trim()}';
              if (txtPassword) txtPassword.value = '$encryptedPassword';
              if (hdnpwd) hdnpwd.value = '$encryptedPassword';
              if (rbtStudent) rbtStudent.checked = true;

              // Prioritize clicking the submit button directly
              var loginBtn = document.querySelector('#btnLogin') || document.querySelector('[id*="btnLogin"]') || document.querySelector('#imgBtn2') || document.querySelector('[id*="imgBtn2"]');
              if (loginBtn) {
                loginBtn.click();
              } else if (typeof __doPostBack === 'function') {
                __doPostBack('btnLogin', '');
              } else {
                var form = document.querySelector('form');
                if (form) form.submit();
              }
            })();
          """;

          try {
            await controller.evaluateJavascript(source: jsCode);
            print('[AusAttendanceService] WebView JS credentials successfully injected and submitted.');
          } catch (e) {
            print('[AusAttendanceService] WebView JS evaluation error: $e');
          }
        } else if (currentUrl.contains('StudentMaster.aspx')) {
          if (completer.isCompleted) return;
          print('[AusAttendanceService] WebView StudentMaster.aspx detected! Extracting cookies...');
          try {
            // Extract the actual WebView User-Agent to align all subsequent HttpClient requests
            final ua = await controller.evaluateJavascript(source: "navigator.userAgent");
            if (ua != null && ua.toString().isNotEmpty) {
              _userAgent = ua.toString();
              print('[AusAttendanceService] WebView resolved native User-Agent: $_userAgent');
            }
            final cookieManager = CookieManager.instance();
            final cookiesList = await cookieManager.getCookies(
              url: WebUri(currentUrl),
            );
            final extractedCookies = <String, String>{};
            for (final cookie in cookiesList) {
              extractedCookies[cookie.name] = cookie.value.toString();
            }
            print('[AusAttendanceService] WebView extracted cookies: ${extractedCookies.keys.toList()}');

            final sessionId = extractedCookies['ASP.NET_SessionId'];
            final frmAuth = extractedCookies['frmAuth'];

            if (sessionId == null ||
                sessionId.isEmpty ||
                frmAuth == null ||
                frmAuth.isEmpty) {
              print('[AusAttendanceService] WebView error: SessionId or frmAuth missing/empty!');
              if (!completer.isCompleted) {
                completer.completeError(Exception('Invalid credentials'));
              }
            } else {
              print('[AusAttendanceService] WebView login successful! Resolving extracted cookies.');
              if (!completer.isCompleted) {
                completer.complete(extractedCookies);
              }
            }
          } catch (e) {
            print('[AusAttendanceService] WebView cookie extraction exception: $e');
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          } finally {
            cleanup();
          }
        }
      },
      onReceivedError: (controller, request, error) {
        print('[AusAttendanceService] WebView Error: ${error.description} (code: ${error.type})');
      },
      onReceivedHttpError: (controller, request, errorResponse) {
        print('[AusAttendanceService] WebView HTTP Error: ${errorResponse.statusCode} - ${errorResponse.reasonPhrase}');
      },
      onConsoleMessage: (controller, consoleMessage) {
        print('[AusAttendanceService] WebView Console: [${consoleMessage.messageLevel}] ${consoleMessage.message}');
      },
    );

    try {
      print('[AusAttendanceService] WebView running headlessWebView...');
      await headlessWebView.run();
      print('[AusAttendanceService] WebView headless run initiated.');
    } catch (e) {
      print('[AusAttendanceService] WebView run() error: $e');
      cleanup();
      completer.completeError(e);
    }

    return completer.future;
  }

  static Future<void> _login(
    HttpClient client,
    String rollNumber,
    String password,
    Map<String, String> cookies,
  ) async {
    try {
      final webViewCookies = await _loginViaWebView(rollNumber, password);
      cookies.addAll(webViewCookies);

      final sessionId = cookies['ASP.NET_SessionId'];
      final frmAuth = cookies['frmAuth'];
      if (sessionId == null ||
          frmAuth == null ||
          sessionId.isEmpty ||
          frmAuth.isEmpty) {
        throw Exception('Invalid credentials');
      }
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is Exception && e.toString().contains('Invalid credentials')) {
        rethrow;
      }
      throw Exception('Could not sign in to the college portal');
    }
  }


  static final List<RegExp> _webMethodTokenPatterns = [
    RegExp(r"var\s+_tkn\s*=\s*'([^']+)'"),
    RegExp(r'var\s+_tkn\s*=\s*"([^"]+)"'),
    RegExp(r"""['"]_tkn['"]\s*:\s*'([^']+)'"""),
    RegExp(r'''['"]_tkn['"]\s*:\s*"([^"]+)"'''),
  ];

  static final List<RegExp> _genericTokenPatterns = [
    RegExp(r"var\s+token\s*=\s*'([^']+)'", caseSensitive: false),
    RegExp(r'var\s+token\s*=\s*"([^"]+)"', caseSensitive: false),
    RegExp(r'var\s+authToken\s*=\s*"([^"]+)"', caseSensitive: false),
    RegExp(r"var\s+authToken\s*=\s*'([^']+)'", caseSensitive: false),
    RegExp(r'var\s+_token\s*=\s*"([^"]+)"', caseSensitive: false),
    RegExp(r"var\s+_token\s*=\s*'([^']+)'", caseSensitive: false),
    RegExp(r'var\s+tkn\s*=\s*"([^"]+)"', caseSensitive: false),
    RegExp(r"var\s+tkn\s*=\s*'([^']+)'", caseSensitive: false),
  ];

  static final RegExp _scriptSrcPattern = RegExp(
    r'''<script[^>]+src\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _hiddenInputTokenPattern = RegExp(
    r'''<input\s+[^>]*type\s*=\s*["']hidden["'][^>]*>''',
    caseSensitive: false,
    dotAll: true,
  );


  static final RegExp _inputNameAttrPattern = RegExp(
    r'''name\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  static final RegExp _inputIdAttrPattern = RegExp(
    r'''id\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  static final RegExp _inputValueAttrPattern = RegExp(
    r'''value\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  static Future<String?> _extractTokenMultiStrategy({
    required HttpClient client,
    required Map<String, String> cookies,
    required String attendancePageHtml,
  }) async {
    String? token;

    for (final pattern in _webMethodTokenPatterns) {
      final match = pattern.firstMatch(attendancePageHtml);
      final tkn = match?.group(1)?.trim();
      if (tkn != null && tkn.isNotEmpty) {
        token = tkn;
        return token;
      }
    }

    final hiddenMatches = _hiddenInputTokenPattern.allMatches(
      attendancePageHtml,
    );
    for (final hiddenMatch in hiddenMatches) {
      final inputTag = hiddenMatch.group(0) ?? '';

      String? name;
      final nameMatch = _inputNameAttrPattern.firstMatch(inputTag);
      if (nameMatch != null) name = nameMatch.group(1);

      String? id;
      final idMatch = _inputIdAttrPattern.firstMatch(inputTag);
      if (idMatch != null) id = idMatch.group(1);

      final fieldKey = (name ?? id ?? '').toLowerCase();
      if (fieldKey.contains('tkn') || fieldKey.contains('token')) {
        final valueMatch = _inputValueAttrPattern.firstMatch(inputTag);
        final value = valueMatch?.group(1)?.trim();
        if (value != null && value.isNotEmpty) {
          token = value;
          return token;
        }
      }
    }

    for (final pattern in _genericTokenPatterns) {
      final match = pattern.firstMatch(attendancePageHtml);
      final tkn = match?.group(1)?.trim();
      if (tkn != null && tkn.isNotEmpty) {
        token = tkn;
        return token;
      }
    }

    final scriptMatches = _scriptSrcPattern.allMatches(attendancePageHtml);
    final jsPaths = <String>[];
    for (final match in scriptMatches) {
      final src = match.group(1) ?? '';
      if (src.contains('JSFiles') || src.contains('.js')) {
        jsPaths.add(src.split('?').first);
      }
    }

    for (final jsPath in jsPaths) {
      if (!jsPath.contains(_portalHost)) continue;

      try {
        final jsPathOnly = jsPath.split('?').first;
        final jsResponse = await _sendRequest(
          client,
          method: 'GET',
          path: jsPathOnly,
          cookies: cookies,
          followRedirects: true,
        );

        final jsBody = jsResponse.body;

        for (final pattern in _webMethodTokenPatterns) {
          final match = pattern.firstMatch(jsBody);
          final tkn = match?.group(1)?.trim();
          if (tkn != null && tkn.isNotEmpty) {
            token = tkn;
            return token;
          }
        }

        for (final pattern in _genericTokenPatterns) {
          final match = pattern.firstMatch(jsBody);
          final tkn = match?.group(1)?.trim();
          if (tkn != null && tkn.isNotEmpty) {
            token = tkn;
            return token;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static String _extractDefaultDate(String html, String fieldKey) {
    final inputPattern = RegExp(
      r'<input\s+([^>]*?)>',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = inputPattern.allMatches(html);
    for (final match in matches) {
      final tagContent = match.group(1) ?? '';
      final hasFieldKey = tagContent.toLowerCase().contains(fieldKey.toLowerCase());
      if (hasFieldKey) {
        final valuePattern = RegExp(
          r'''value\s*=\s*["']([^"']*)["']''',
          caseSensitive: false,
        );
        final valMatch = valuePattern.firstMatch(tagContent);
        if (valMatch != null) {
          final val = valMatch.group(1)?.trim() ?? '';
          if (val.isNotEmpty) {
            return val;
          }
        }
      }
    }
    return '';
  }

  static Future<Map<String, dynamic>> fetchAttendance(
    String rollNumber,
    String password, {
    String fromDate = '',
    String toDate = '',
    AttendanceRangeMode mode = AttendanceRangeMode.period,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    final cookies = <String, String>{};
    try {
      await _login(client, rollNumber, password, cookies);

      await _sendRequest(
        client,
        method: 'GET',
        path: _studentMasterPath,
        cookies: cookies,
        followRedirects: true,
      );

      final attendancePageResponse = await _sendRequest(
        client,
        method: 'GET',
        path: _attendancePagePath,
        cookies: cookies,
        followRedirects: true,
      );

      final webMethodToken = await _extractTokenMultiStrategy(
        client: client,
        cookies: cookies,
        attendancePageHtml: attendancePageResponse.body,
      );

      await _sendRequest(
        client,
        method: 'GET',
        path: _ajaxJsPath,
        cookies: cookies,
        followRedirects: true,
      );

      String formattedFromDate;
      String formattedToDate;

      if (mode == AttendanceRangeMode.tillNow) {
        final defaultFrom = _extractDefaultDate(attendancePageResponse.body, 'txtFromDate');
        final defaultTo = _extractDefaultDate(attendancePageResponse.body, 'txtToDate');

        if (defaultFrom.isNotEmpty && defaultTo.isNotEmpty) {
          formattedFromDate = defaultFrom;
          formattedToDate = defaultTo;
        } else {
          formattedFromDate = '';
          formattedToDate = '';
        }
      } else {
        DateTime fromDt;
        DateTime toDt;

        if (fromDate.isEmpty || toDate.isEmpty) {
          fromDt = DateTime.now();
          toDt = DateTime.now();
        } else {
          final parts = fromDate.split('-');
          final fromDay = int.tryParse(parts[0]) ?? 1;
          final fromMonth = int.tryParse(parts[1]) ?? 1;
          final fromYear = int.tryParse(parts[2]) ?? DateTime.now().year;
          fromDt = DateTime(fromYear, fromMonth, fromDay);

          final toParts = toDate.split('-');
          final toDay = int.tryParse(toParts[0]) ?? 1;
          final toMonth = int.tryParse(toParts[1]) ?? 1;
          final toYear = int.tryParse(toParts[2]) ?? DateTime.now().year;
          toDt = DateTime(toYear, toMonth, toDay);
        }

        if (fromDt.isAfter(toDt)) {
          final temp = fromDt;
          fromDt = toDt;
          toDt = temp;
        }

        final today = DateTime.now();
        final todayDateOnly = DateTime(today.year, today.month, today.day);
        if (toDt.isAfter(todayDateOnly)) {
          toDt = todayDateOnly;
        }

        final fromDayStr = fromDt.day.toString().padLeft(2, '0');
        final fromMonthStr = fromDt.month.toString().padLeft(2, '0');
        formattedFromDate = '$fromDayStr-$fromMonthStr-${fromDt.year}';

        final toDayStr = toDt.day.toString().padLeft(2, '0');
        final toMonthStr = toDt.month.toString().padLeft(2, '0');
        formattedToDate = '$toDayStr-$toMonthStr-${toDt.year}';
      }

      final attendanceBody = jsonEncode({
        'fromDate': formattedFromDate,
        'toDate': formattedToDate,
        'excludeothersubjects': false,
      });

      final extraHeaders = <String, String>{
        'Origin': 'https://$_portalHost',
        HttpHeaders.refererHeader: 'https://$_portalHost$_attendancePagePath',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept': 'application/json, text/javascript, */*',
      };
      if (webMethodToken != null && webMethodToken.trim().isNotEmpty) {
        extraHeaders['X-Auth-Token'] = webMethodToken;
      }

      final showResp = await _sendRequest(
        client,
        method: 'POST',
        path: _attendancePath,
        cookies: cookies,
        followRedirects: false,
        contentType: 'application/json; charset=UTF-8',
        body: attendanceBody,
        extraHeaders: extraHeaders,
      );

      if (showResp.statusCode == HttpStatus.unauthorized) {
        throw Exception(
          'The portal attendance server is temporarily unavailable. '
          'Please try again later.',
        );
      }
      if (showResp.statusCode != HttpStatus.ok) {
        throw Exception('Could not fetch attendance right now');
      }

      String attendanceHtml;
      try {
        final decoded = jsonDecode(showResp.body) as Map<String, dynamic>;
        attendanceHtml = decoded['d'] as String? ?? '';
      } catch (_) {
        attendanceHtml = showResp.body;
      }

      final parsed = _parseAttendanceHtml(attendanceHtml);
      final parsedMap = Map<String, dynamic>.from(parsed);

      final hasReport = parsedMap['hasReport'] as bool? ?? false;
      if ((parsedMap['subjects'] as List).isEmpty && !hasReport) {
        throw Exception('Attendance data was not found in the portal response');
      }
      return parsedMap;
    } on FormatException {
      rethrow;
    } catch (e) {
      if (e is Exception &&
          (e.toString().contains('Invalid credentials') ||
              e.toString().contains('Attendance data was not found') ||
              e.toString().contains('Could not fetch attendance') ||
              e.toString().contains('temporarily unavailable'))) {
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

    String tableHtml = html;
    final tblReportMatch = RegExp(
      r'''<table[^>]*id=["']tblReport["'][^>]*>(.*?)</table>''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (tblReportMatch != null) {
      tableHtml = tblReportMatch.group(1) ?? html;
    }

    final plainText = _cleanHtmlText(tableHtml);
    final studentName = _extractLabeledValue(plainText, 'Student Name');
    final rowMatches = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(tableHtml);

    int? subjectIdx;
    int? heldIdx;
    int? attendIdx;
    int? percentIdx;

    for (final row in rowMatches.toList()) {
      final rowHtml = row.group(1) ?? '';

      final isHeaderRow = RegExp(
        r'<th\b',
        caseSensitive: false,
      ).hasMatch(rowHtml);

      final cellMatches = RegExp(
        r'<t[dh][^>]*>(.*?)</t[dh]>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(rowHtml);

      final cleanedCells = cellMatches
          .map((c) => _cleanHtmlText(c.group(1) ?? ''))
          .toList();

      if (isHeaderRow) {
        for (int i = 0; i < cleanedCells.length; i++) {
          final lower = cleanedCells[i].toLowerCase().trim();
          if (lower.contains('subject') ||
              lower.contains('course') ||
              lower.contains('paper')) {
            subjectIdx = i;
          } else if (lower.contains('held')) {
            heldIdx = i;
          } else if (lower.contains('attend') &&
              !lower.contains('attendance')) {
            attendIdx = i;
          } else if (lower == '%' || lower.contains('percent')) {
            percentIdx = i;
          }
        }
        continue;
      }

      if (cleanedCells.where((c) => c.isNotEmpty).length < 3) continue;

      String? subjectName;
      int? totalClasses;
      int? attendedClasses;
      double? percentage;

      if (subjectIdx != null && heldIdx != null && attendIdx != null) {
        if (subjectIdx < cleanedCells.length) {
          final s = cleanedCells[subjectIdx].trim();
          if (s.isNotEmpty) subjectName = s;
        }
        if (heldIdx < cleanedCells.length) {
          totalClasses = int.tryParse(cleanedCells[heldIdx].trim());
        }
        if (attendIdx < cleanedCells.length) {
          attendedClasses = int.tryParse(cleanedCells[attendIdx].trim());
        }
        if (percentIdx != null && percentIdx < cleanedCells.length) {
          final raw = cleanedCells[percentIdx].trim();
          final normalized = raw.startsWith('.') ? '0$raw' : raw;
          percentage = double.tryParse(normalized);
        }
      } else {
        int subjectCellIdx = -1;
        for (int i = 0; i < cleanedCells.length; i++) {
          final cell = cleanedCells[i];
          if (cell.isNotEmpty &&
              (cell.toLowerCase().trim() == 'total' ||
                  _looksLikeSubjectCell(cell))) {
            subjectCellIdx = i;
            subjectName = cell;
            break;
          }
        }
        if (subjectCellIdx >= 0) {
          final intCellsAfterSubject = <int>[];
          for (int i = subjectCellIdx + 1; i < cleanedCells.length; i++) {
            final v = int.tryParse(cleanedCells[i].trim());
            if (v != null) intCellsAfterSubject.add(v);
          }
          if (intCellsAfterSubject.length >= 2) {
            totalClasses = intCellsAfterSubject[0];
            attendedClasses = intCellsAfterSubject[1];
          }
        }
      }

      if (percentage == null) {
        for (final cell in cleanedCells.reversed) {
          final trimmed = cell.trim();
          final normalized = trimmed.startsWith('.') ? '0$trimmed' : trimmed;
          if (normalized.contains('.')) {
            final parsed = double.tryParse(normalized);
            if (parsed != null && parsed >= 0.0 && parsed <= 100.0) {
              percentage = parsed;
              break;
            }
          }
        }
      }

      if (percentage == null &&
          totalClasses != null &&
          totalClasses > 0 &&
          attendedClasses != null) {
        percentage = (attendedClasses / totalClasses) * 100;
      }
      percentage ??= 0.0;

      if (subjectName == null) continue;
      if (totalClasses == null || attendedClasses == null) continue;

      final lowerSubject = subjectName.toLowerCase().trim();

      if (lowerSubject == 'total') {
        hasReport = true;
        totalHeldFromReport = totalClasses;
        totalAttendedFromReport = attendedClasses;
        totalPercentageFromReport = percentage;
        continue;
      }

      if (lowerSubject.contains('subject') ||
          lowerSubject.contains('sr') ||
          lowerSubject.contains('sl')) {
        continue;
      }

      subjects.add({
        'subject': subjectName,
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
