// =============================================================================
//  Utopia App – Attendance Google Apps Script Middleware
//  File: attendance_gas_script.gs
// =============================================================================
//
//  DEPLOYMENT INSTRUCTIONS
//  ─────────────────────────────────────────────────────────────────────────
//  1. Go to https://script.google.com and create a new project.
//  2. Replace the default Code.gs content with the ENTIRE contents of this
//     file (no changes needed unless explicitly noted).
//  3. Click  Deploy → New deployment.
//     • Type          : Web app
//     • Execute as    : Me  (your Google account)
//     • Who has access: Anyone
//  4. Click Deploy, then copy the  Web app URL.
//  5. Paste the URL into the Flutter app:
//       lib/services/gas_attendance_service.dart
//         → GasAttendanceService.ausGasUrl   (for AUS)
//         → GasAttendanceService.acetGasUrl  (for ACET)
//     Both colleges share a SINGLE deployment of this script; the college is
//     selected from the JSON body sent by the app.
//  6. Every time you update the script, create a NEW deployment (or manage
//     existing deployment) and update the URL in the Flutter app.
//
//  REQUEST FORMAT (POST, Content-Type: application/json)
//  ─────────────────────────────────────────────────────────────────────────
//  {
//    "rollNumber": "25B11ME038",          // required
//    "password":   "yourPortalPassword",  // required – plain text; HTTPS only
//    "college":    "aus" | "acet",        // required
//    "fromDate":   "dd-MM-yyyy",          // optional (empty = full semester)
//    "toDate":     "dd-MM-yyyy"           // optional
//  }
//
//  RESPONSE FORMAT (JSON)
//  ─────────────────────────────────────────────────────────────────────────
//  Success:
//  {
//    "success": true,
//    "data": {
//      "overallPercentage": 85.0,
//      "totalClasses":      120,
//      "totalAttended":     102,
//      "studentName":       "STUDENT NAME",
//      "hasReport":         true,
//      "subjects": [
//        { "subject": "Engineering Maths", "totalClasses": 30,
//          "attendedClasses": 27, "percentage": 90.0 },
//        ...
//      ]
//    }
//  }
//
//  Error:
//  {
//    "success": false,
//    "error": "Invalid credentials"   // human-readable message
//  }
//
//  SECURITY NOTE
//  ─────────────────────────────────────────────────────────────────────────
//  • All traffic goes over HTTPS (script.google.com enforces TLS).
//  • The plain-text password is used only to encrypt it with AES-128-CBC
//    before sending to info.aec.edu.in – it is never stored or logged by
//    this script.
//  • For extra safety you may add an API-key check:
//      var API_KEY = 'your-secret-key';
//      if (body.apiKey !== API_KEY) return errorResponse('Unauthorized');
//
// =============================================================================

// ─── Portal constants ─────────────────────────────────────────────────────────

var PORTAL_HOST   = 'https://info.aec.edu.in';
// AES_SECRET is the portal-wide hardcoded AES-128 key & IV used by info.aec.edu.in
// to encrypt passwords before transmission. It is NOT a secret we choose –
// it is baked into the portal's own JavaScript (same value on all AUS/ACET accounts).
var AES_SECRET    = '8701661282118308';
var USER_AGENT    =
  'Mozilla/5.0 (Linux; Android 14; vivo I2305) ' +
  'AppleWebKit/537.36 (KHTML, like Gecko) ' +
  'Chrome/123.0.0.0 Mobile Safari/537.36';

// Per-college path prefixes ─────────────────────────────────────────────────
var COLLEGE_CONFIG = {
  aus: {
    prefix         : '/aus',
    loginPath      : '/aus/default.aspx',
    studentMaster  : '/aus/StudentMaster.aspx',
    attendancePage : '/aus/Academics/studentattendance.aspx?scrid=3&showtype=SA',
    attendancePath : '/aus/Academics/studentattendance.aspx/ShowAttendance',
    ajaxJsPath     : '/aus/JSFiles/AjaxMethods.js',
  },
  acet: {
    prefix         : '/acet',
    loginPath      : '/acet/default.aspx',
    studentMaster  : '/acet/StudentMaster.aspx',
    attendancePage : '/acet/Academics/StudentAttendance.aspx?scrid=3&showtype=SA',
    attendancePath : '/acet/Academics/studentattendance.aspx/ShowAttendance',
    ajaxJsPath     : '/acet/JSFiles/AjaxMethods.js',
    authCheckPath  : '/acet/authcheck.aspx',
  },
};

// =============================================================================
//  ENTRY POINT
// =============================================================================

/**
 * HTTP POST handler — Apps Script web-app entry point.
 */
function doPost(e) {
  try {
    // ── Parse body ────────────────────────────────────────────────────────────
    var rawBody = (e && e.postData && e.postData.contents) ? e.postData.contents : '{}';
    log_('[ENTRY] raw body len=' + rawBody.length);

    var body;
    try {
      body = JSON.parse(rawBody);
    } catch (parseErr) {
      log_('[ENTRY] JSON parse error: ' + parseErr);
      return errorResponse('Invalid request body (expected JSON)');
    }

    var rollNumber = trim_(body.rollNumber || '');
    var password   = body.password || '';
    var college    = trim_((body.college || 'aus').toLowerCase());
    var fromDate   = trim_(body.fromDate || '');
    var toDate     = trim_(body.toDate   || '');

    log_(
      '[ENTRY] college=' + college +
      ' roll=' + rollNumber +
      ' fromDate=' + (fromDate || 'empty') +
      ' toDate='   + (toDate   || 'empty')
    );

    // ── Validate ──────────────────────────────────────────────────────────────
    if (!rollNumber) return errorResponse('Roll number is required');
    if (!password)   return errorResponse('Password is required');
    if (college !== 'aus' && college !== 'acet') {
      return errorResponse('Invalid college value (must be "aus" or "acet")');
    }

    // ── Fetch ─────────────────────────────────────────────────────────────────
    var data = fetchAttendance_(rollNumber, password, college, fromDate, toDate);
    log_('[ENTRY] success — subjects=' + data.subjects.length);
    return successResponse(data);

  } catch (err) {
    var msg = err.message || err.toString();
    log_('[ENTRY][ERROR] ' + msg);
    // Preserve friendly portal-level messages unchanged
    if (
      msg.indexOf('Invalid credentials') !== -1 ||
      msg.indexOf('Attendance data was not found') !== -1 ||
      msg.indexOf('Could not fetch attendance') !== -1 ||
      msg.indexOf('temporarily unavailable') !== -1
    ) {
      return errorResponse(msg.replace('Error: ', '').replace('Exception: ', '').trim());
    }
    return errorResponse('Unable to load attendance right now');
  }
}

/**
 * HTTP GET handler — returns a simple status message so you can verify the
 * deployment URL works without sending credentials.
 */
function doGet() {
  return ContentService
    .createTextOutput(JSON.stringify({ status: 'ok', service: 'Utopia Attendance GAS' }))
    .setMimeType(ContentService.MimeType.JSON);
}

// =============================================================================
//  CORE ATTENDANCE FLOW
// =============================================================================

function fetchAttendance_(rollNumber, password, college, fromDate, toDate) {
  var cfg     = COLLEGE_CONFIG[college];
  var cookies = {};   // mutable cookie jar shared across all requests

  // ── Step 1: Login ────────────────────────────────────────────────────────
  log_('[FLOW] Step 1: login');
  login_(rollNumber, password, college, cfg, cookies);

  // ── Step 2: Load StudentMaster (session warm-up) ─────────────────────────
  log_('[FLOW] Step 2: GET StudentMaster');
  fetch_(PORTAL_HOST + cfg.studentMaster, { method: 'GET', cookies: cookies, followRedirects: true });

  // ── Step 3: Load attendance page (extract web-method token) ─────────────
  log_('[FLOW] Step 3: GET attendance page');
  var attPageRes = fetch_(
    PORTAL_HOST + cfg.attendancePage,
    { method: 'GET', cookies: cookies, followRedirects: true }
  );
  var webMethodToken = extractWebMethodToken_(attPageRes.body);
  log_('[FLOW] webMethodToken found=' + (webMethodToken ? 'yes' : 'no'));

  // ── Step 4: Load AjaxMethods.js (browser-parity) ─────────────────────────
  log_('[FLOW] Step 4: GET AjaxMethods.js');
  fetch_(PORTAL_HOST + cfg.ajaxJsPath, { method: 'GET', cookies: cookies, followRedirects: true });

  // ── Step 5: POST ShowAttendance ───────────────────────────────────────────
  log_('[FLOW] Step 5: POST ShowAttendance fromDate=' + (fromDate || 'empty') + ' toDate=' + (toDate || 'empty'));

  var reqBody = JSON.stringify({
    fromDate              : fromDate,
    toDate                : toDate,
    excludeothersubjects  : false,
  });

  var extraHeaders = {
    'origin'            : PORTAL_HOST,
    'referer'           : PORTAL_HOST + cfg.attendancePage,
    'x-requested-with'  : 'XMLHttpRequest',
    'accept'            : 'application/json, text/javascript, */*; q=0.01',
    'cache-control'     : 'no-cache',
    'pragma'            : 'no-cache',
  };
  if (webMethodToken) {
    extraHeaders['x-auth-token'] = webMethodToken;
  }

  var attRes = fetch_(
    PORTAL_HOST + cfg.attendancePath,
    {
      method         : 'POST',
      cookies        : cookies,
      followRedirects: false,
      contentType    : 'application/json; charset=UTF-8',
      payload        : reqBody,
      headers        : extraHeaders,
    }
  );

  log_('[FLOW] ShowAttendance status=' + attRes.statusCode + ' bodyLen=' + attRes.body.length);

  if (attRes.statusCode === 401) {
    throw new Error(
      'The portal attendance server is temporarily unavailable. Please try again later.'
    );
  }
  if (attRes.statusCode !== 200) {
    throw new Error('Could not fetch attendance right now (HTTP ' + attRes.statusCode + ')');
  }

  // ── Step 6: Parse HTML ────────────────────────────────────────────────────
  var attendanceHtml;
  try {
    var decoded = JSON.parse(attRes.body);
    attendanceHtml = decoded.d || '';
  } catch (_) {
    attendanceHtml = attRes.body;
  }

  log_('[FLOW] parsing attendance HTML len=' + attendanceHtml.length);
  var parsed = parseAttendanceHtml_(attendanceHtml);
  log_(
    '[FLOW] parse result: subjects=' + parsed.subjects.length +
    ' hasReport=' + parsed.hasReport
  );

  if (parsed.subjects.length === 0 && !parsed.hasReport) {
    throw new Error('Attendance data was not found in the portal response');
  }

  return parsed;
}

// =============================================================================
//  LOGIN
// =============================================================================

function login_(rollNumber, password, college, cfg, cookies) {
  var encryptedPassword = encryptAesCbc_(password, AES_SECRET, AES_SECRET);
  log_('[LOGIN] password encrypted (len=' + encryptedPassword.length + ')');

  if (college === 'aus') {
    loginAus_(rollNumber, encryptedPassword, cfg, cookies);
  } else {
    loginAcet_(rollNumber, encryptedPassword, cfg, cookies);
  }
}

// ── AUS login ─────────────────────────────────────────────────────────────────

function loginAus_(rollNumber, encryptedPassword, cfg, cookies) {
  // GET login page → extract ASP.NET hidden tokens
  log_('[LOGIN][AUS] GET default.aspx');
  var loginPageRes = fetch_(
    PORTAL_HOST + cfg.loginPath,
    { method: 'GET', cookies: cookies, followRedirects: true }
  );
  log_('[LOGIN][AUS] status=' + loginPageRes.statusCode);

  var viewState          = extractHiddenInput_(loginPageRes.body, '__VIEWSTATE');
  var viewStateGenerator = extractHiddenInput_(loginPageRes.body, '__VIEWSTATEGENERATOR');
  var eventValidation    = extractHiddenInput_(loginPageRes.body, '__EVENTVALIDATION');

  log_(
    '[LOGIN][AUS] tokens: VS=' + (viewState ? 'found' : 'MISSING') +
    ' VSG=' + (viewStateGenerator ? 'found' : 'MISSING') +
    ' EV=' + (eventValidation ? 'found' : 'MISSING')
  );

  if (!viewState) {
    throw new Error('Portal login tokens were not found (AUS)');
  }

  // POST login form
  var formData =
    '__VIEWSTATE='          + encodeURIComponent(viewState)          +
    '&__VIEWSTATEGENERATOR=' + encodeURIComponent(viewStateGenerator || '') +
    '&__EVENTVALIDATION='   + encodeURIComponent(eventValidation || '')   +
    '&userType=rbtStudent'                                             +
    '&txtUserId='           + encodeURIComponent(rollNumber)           +
    '&txtPassword='         + encodeURIComponent(encryptedPassword)    +
    '&hdnpwd='              + encodeURIComponent(encryptedPassword)    +
    '&btnLogin=LOGIN';

  log_('[LOGIN][AUS] POST default.aspx');
  var postRes = fetch_(
    PORTAL_HOST + cfg.loginPath,
    {
      method         : 'POST',
      cookies        : cookies,
      followRedirects: false,
      contentType    : 'application/x-www-form-urlencoded',
      payload        : formData,
      headers        : {
        'origin'  : PORTAL_HOST,
        'referer' : PORTAL_HOST + cfg.loginPath,
      },
    }
  );

  log_(
    '[LOGIN][AUS] POST status=' + postRes.statusCode +
    ' location=' + (postRes.location || '-') +
    ' hasFrmAuth=' + (cookies['frmAuth'] ? 'yes' : 'no') +
    ' hasSession=' + (cookies['ASP.NET_SessionId'] ? 'yes' : 'no')
  );

  var redirectedToStudentMaster =
    (postRes.statusCode === 302 || postRes.statusCode === 301 ||
     postRes.statusCode === 303 || postRes.statusCode === 200) &&
    ((postRes.location || '').toLowerCase().indexOf('studentmaster') !== -1 ||
     cookies['frmAuth']);

  if (!redirectedToStudentMaster || !cookies['ASP.NET_SessionId']) {
    log_('[LOGIN][AUS] login failed — invalid credentials');
    throw new Error('Invalid credentials');
  }

  log_('[LOGIN][AUS] login success');
}

// ── ACET login ────────────────────────────────────────────────────────────────

function loginAcet_(rollNumber, encryptedPassword, cfg, cookies) {
  // GET login page (with authcheck gate handling)
  log_('[LOGIN][ACET] GET default.aspx (initial)');
  var loginPageRes = fetch_(
    PORTAL_HOST + cfg.loginPath,
    { method: 'GET', cookies: cookies, followRedirects: true }
  );
  log_('[LOGIN][ACET] initial status=' + loginPageRes.statusCode);

  // If no __VIEWSTATE, try authcheck gate + retry
  if (loginPageRes.body.indexOf('__VIEWSTATE') === -1) {
    log_('[LOGIN][ACET] No VIEWSTATE – trying authcheck gate');
    fetch_(
      PORTAL_HOST + cfg.authCheckPath,
      { method: 'GET', cookies: cookies, followRedirects: true }
    );
    loginPageRes = fetch_(
      PORTAL_HOST + cfg.loginPath,
      { method: 'GET', cookies: cookies, followRedirects: true }
    );
    log_('[LOGIN][ACET] retry status=' + loginPageRes.statusCode);
  }

  // Parse hidden fields from entire HTML
  var hiddenFields = parseAllHiddenFields_(loginPageRes.body);
  log_('[LOGIN][ACET] hiddenFields count=' + Object.keys(hiddenFields).length);

  // Build login form: include all hidden fields + credential fields
  var formParts = [];
  for (var key in hiddenFields) {
    formParts.push(encodeURIComponent(key) + '=' + encodeURIComponent(hiddenFields[key]));
  }

  // Credential fields – ACET uses txtId1/2/3 and txtPwd1/2/3
  formParts.push('txtId1=' + encodeURIComponent(rollNumber));
  formParts.push('txtId2=' + encodeURIComponent(rollNumber));
  formParts.push('txtId3=' + encodeURIComponent(rollNumber));
  formParts.push('txtPwd1=' + encodeURIComponent(encryptedPassword));
  formParts.push('txtPwd2=' + encodeURIComponent(encryptedPassword));
  formParts.push('txtPwd3=' + encodeURIComponent(encryptedPassword));

  // hdnpwd fields (if present in form)
  if (hiddenFields['hdnpwd1'] !== undefined) {
    formParts.push('hdnpwd1=' + encodeURIComponent(encryptedPassword));
  }
  if (hiddenFields['hdnpwd2'] !== undefined) {
    formParts.push('hdnpwd2=' + encodeURIComponent(encryptedPassword));
  }
  if (hiddenFields['hdnpwd3'] !== undefined) {
    formParts.push('hdnpwd3=' + encodeURIComponent(encryptedPassword));
  }

  // Submit button (Chrome DevTools shows imgBtn2)
  formParts.push('imgBtn2.x=42');
  formParts.push('imgBtn2.y=6');

  var formData = formParts.join('&');
  log_('[LOGIN][ACET] POST default.aspx formKeys=' + formParts.length);

  var postRes = fetch_(
    PORTAL_HOST + cfg.loginPath,
    {
      method         : 'POST',
      cookies        : cookies,
      followRedirects: true,   // ACET may redirect to StudentMaster directly
      contentType    : 'application/x-www-form-urlencoded',
      payload        : formData,
      headers        : {
        'origin'  : PORTAL_HOST,
        'referer' : PORTAL_HOST + cfg.loginPath,
      },
    }
  );

  log_(
    '[LOGIN][ACET] POST status=' + postRes.statusCode +
    ' location=' + (postRes.location || '-') +
    ' hasFrmAuth=' + (cookies['frmAuth'] ? 'yes' : 'no') +
    ' hasSession=' + (cookies['ASP.NET_SessionId'] ? 'yes' : 'no')
  );

  // Verify: GET StudentMaster should NOT show login page
  var smRes = fetch_(
    PORTAL_HOST + cfg.studentMaster,
    {
      method         : 'GET',
      cookies        : cookies,
      followRedirects: true,
      headers        : { 'referer': PORTAL_HOST + cfg.loginPath },
    }
  );

  var smIsLoginPage = looksLikeLoginPage_(smRes.body);
  log_('[LOGIN][ACET] StudentMaster loginPage=' + smIsLoginPage);

  var loginSuccess =
    (postRes.statusCode === 302 || postRes.statusCode === 200 || cookies['frmAuth']) &&
    !smIsLoginPage;

  if (!loginSuccess) {
    log_('[LOGIN][ACET] login failed — invalid credentials');
    throw new Error('Invalid credentials');
  }

  log_('[LOGIN][ACET] login success');
}

// =============================================================================
//  HTTP HELPER  (cookie-aware UrlFetchApp wrapper)
// =============================================================================

/**
 * Makes an HTTP request, manages the cookie jar, and handles redirects.
 *
 * @param {string} url
 * @param {{
 *   method?         : 'GET'|'POST',
 *   cookies?        : Object,
 *   followRedirects?: boolean,
 *   contentType?    : string,
 *   payload?        : string,
 *   headers?        : Object
 * }} options
 * @returns {{ statusCode: number, body: string, location: string|null }}
 */
function fetch_(url, options) {
  options = options || {};
  var method          = (options.method || 'GET').toUpperCase();
  var cookies         = options.cookies || {};
  var followRedirects = options.followRedirects !== false;  // default true
  var contentType     = options.contentType || null;
  var payload         = options.payload || null;
  var extraHeaders    = options.headers || {};

  var MAX_REDIRECTS = 8;
  var currentUrl    = url;
  var currentMethod = method;
  var redirectCount = 0;

  while (true) {
    // Build request options ───────────────────────────────────────────────────
    var reqOptions = {
      method            : currentMethod,
      followRedirects   : false,           // we handle redirects ourselves
      muteHttpExceptions: true,
      headers           : {
        'User-Agent'     : USER_AGENT,
        'Accept'         : 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-IN,en;q=0.9',
      },
    };

    // Merge extra headers
    for (var h in extraHeaders) {
      reqOptions.headers[h] = extraHeaders[h];
    }

    // Cookie header
    var cookieStr = buildCookieHeader_(cookies);
    if (cookieStr) {
      reqOptions.headers['Cookie'] = cookieStr;
    }

    if (contentType) {
      reqOptions.headers['Content-Type'] = contentType;
    }

    if (payload && (currentMethod === 'POST')) {
      reqOptions.payload = payload;
    }

    log_(
      '[HTTP] ' + currentMethod + ' ' + currentUrl.substring(0, 120) +
      ' cookies=[' + Object.keys(cookies).join(', ') + ']'
    );

    var res;
    try {
      res = UrlFetchApp.fetch(currentUrl, reqOptions);
    } catch (fetchErr) {
      log_('[HTTP] UrlFetchApp error: ' + fetchErr);
      throw new Error('Could not reach the college portal. Check your internet connection.');
    }

    var statusCode  = res.getResponseCode();
    var body        = res.getContentText('UTF-8');
    var resHeaders  = res.getAllHeaders();
    var location    = resHeaders['Location'] || resHeaders['location'] || null;

    // Capture Set-Cookie ──────────────────────────────────────────────────────
    captureCookies_(res, cookies);

    log_(
      '[HTTP] status=' + statusCode +
      ' bodyLen=' + body.length +
      ' location=' + (location ? location.substring(0, 80) : '-') +
      ' cookies=[' + Object.keys(cookies).join(', ') + ']'
    );

    // Redirect handling ───────────────────────────────────────────────────────
    var isRedirect =
      statusCode === 301 || statusCode === 302 || statusCode === 303 ||
      statusCode === 307 || statusCode === 308;

    if (!followRedirects || !isRedirect || !location) {
      return { statusCode: statusCode, body: body, location: location };
    }

    if (redirectCount >= MAX_REDIRECTS) {
      throw new Error('Portal redirected too many times');
    }

    // Resolve relative redirects
    if (location.indexOf('http') !== 0) {
      var base = currentUrl.match(/^(https?:\/\/[^\/]+)/);
      location = (base ? base[1] : PORTAL_HOST) + (location.charAt(0) === '/' ? '' : '/') + location;
    }

    redirectCount++;
    currentUrl    = location;
    currentMethod = 'GET';   // POST → GET after redirect (RFC 7231 §6.4.3)
    contentType   = null;
    payload       = null;
    log_('[HTTP] redirect #' + redirectCount + ' → ' + currentUrl.substring(0, 100));
  }
}

// =============================================================================
//  COOKIE MANAGEMENT
// =============================================================================

/**
 * Extracts cookies from a UrlFetchApp response and merges them into the jar.
 * GAS returns Set-Cookie headers as a single string or array.
 */
function captureCookies_(response, cookieJar) {
  var headers = response.getAllHeaders();

  // GAS may give 'Set-Cookie' as array or scalar
  var setCookieRaw = headers['Set-Cookie'] || headers['set-cookie'];
  if (!setCookieRaw) return;

  var setCookieList = Array.isArray(setCookieRaw) ? setCookieRaw : [setCookieRaw];

  setCookieList.forEach(function(headerValue) {
    // Split on commas that separate distinct Set-Cookie entries.
    // Pattern: split only when what follows looks like a new "name=value" pair
    // (no semicolon or comma in either the name or the value portion), so that
    // cookie values that legitimately contain commas (e.g. Expires dates) are
    // NOT split incorrectly.
    var parts = headerValue.split(/,\s*(?=[^;,]+=[^;,]+)/);
    parts.forEach(function(part) {
      var segments = part.trim().split(/\s*;\s*/);
      if (!segments.length) return;
      var kv = segments[0].split('=');
      if (kv.length < 2) return;
      var name  = kv[0].trim();
      var value = kv.slice(1).join('=').trim();
      if (name) {
        cookieJar[name] = value;
        log_('[COOKIE] Set ' + name + '=<value len=' + value.length + '>');
      }
    });
  });
}

function buildCookieHeader_(cookieJar) {
  return Object.keys(cookieJar).map(function(k) {
    return k + '=' + cookieJar[k];
  }).join('; ');
}

// =============================================================================
//  HTML PARSING
// =============================================================================

/**
 * Extracts ASP.NET hidden form fields (__VIEWSTATE, __EVENTVALIDATION, etc.)
 */
function extractHiddenInput_(html, fieldName) {
  // Try id="fieldName" value="..." and name="fieldName" value="..."
  var patterns = [
    new RegExp('id=["\']' + fieldName + '["\'][^>]*value=["\']([^"\']*)["\']', 'i'),
    new RegExp('name=["\']' + fieldName + '["\'][^>]*value=["\']([^"\']*)["\']', 'i'),
    new RegExp('value=["\']([^"\']*)["\'][^>]*id=["\']' + fieldName + '["\']', 'i'),
    new RegExp('value=["\']([^"\']*)["\'][^>]*name=["\']' + fieldName + '["\']', 'i'),
  ];

  for (var i = 0; i < patterns.length; i++) {
    var m = patterns[i].exec(html);
    if (m && m[1] !== undefined) return m[1];
  }
  return null;
}

/**
 * Parses ALL hidden input fields from a login page HTML into a flat object.
 */
function parseAllHiddenFields_(html) {
  var fields  = {};
  // Match <input ... type="hidden" ...>
  var inputRe = /<input\b([^>]*)>/gi;
  var m;
  while ((m = inputRe.exec(html)) !== null) {
    var attrs = m[1];
    var typeM = /type\s*=\s*["']([^"']*)["']/i.exec(attrs);
    if (!typeM || typeM[1].toLowerCase() !== 'hidden') continue;

    var nameM  = /name\s*=\s*["']([^"']*)["']/i.exec(attrs);
    var idM    = /id\s*=\s*["']([^"']*)["']/i.exec(attrs);
    var valueM = /value\s*=\s*["']([^"']*)["']/i.exec(attrs);

    var key   = (nameM && nameM[1]) || (idM && idM[1]) || '';
    var value = (valueM && valueM[1]) || '';

    if (key) fields[key] = value;
  }
  return fields;
}

/**
 * Extracts the web method token from the attendance page HTML.
 * Tries several common variable naming patterns.
 */
function extractWebMethodToken_(html) {
  var patterns = [
    /var\s+_tkn\s*=\s*'([^']+)'/,
    /var\s+_tkn\s*=\s*"([^"]+)"/,
    /'_tkn'\s*:\s*'([^']+)'/,
    /"_tkn"\s*:\s*"([^"]+)"/,
    /var\s+token\s*=\s*'([^']+)'/i,
    /var\s+token\s*=\s*"([^"]+)"/i,
    /var\s+authToken\s*=\s*'([^']+)'/i,
    /var\s+authToken\s*=\s*"([^"]+)"/i,
  ];

  for (var i = 0; i < patterns.length; i++) {
    var m = patterns[i].exec(html);
    if (m && m[1] && m[1].trim()) return m[1].trim();
  }
  return null;
}

/**
 * Returns true when the page body looks like the portal login page
 * (used to detect failed logins).
 */
function looksLikeLoginPage_(body) {
  var lower = body.toLowerCase();
  return (
    lower.indexOf('btnlogin') !== -1 ||
    (lower.indexOf('txtpassword') !== -1 && lower.indexOf('login') !== -1) ||
    (lower.indexOf('txtpwd') !== -1 && lower.indexOf('login') !== -1) ||
    (lower.indexOf('default.aspx') !== -1 && lower.indexOf('<form') !== -1)
  );
}

// =============================================================================
//  ATTENDANCE HTML PARSER
// =============================================================================

/**
 * Parses the attendance HTML table (same structure for AUS and ACET)
 * and returns structured data.
 *
 * @param {string} html – the raw HTML string (may be the full page or just
 *   the snippet returned in the JSON "d" field).
 * @returns {{
 *   overallPercentage: number,
 *   totalClasses: number,
 *   totalAttended: number,
 *   studentName: string|null,
 *   hasReport: boolean,
 *   subjects: Array<{subject,totalClasses,attendedClasses,percentage}>
 * }}
 */
function parseAttendanceHtml_(html) {
  // Extract the tblReport table if present
  var tableHtml = html;
  var tblMatch  = /<table[^>]*id=["']tblReport["'][^>]*>([\s\S]*?)<\/table>/i.exec(html);
  if (tblMatch) tableHtml = tblMatch[1];

  var plainText   = cleanHtmlText_(tableHtml);
  var studentName = extractLabeledValue_(plainText, 'Student Name');

  var subjects                 = [];
  var totalHeldFromReport      = null;
  var totalAttendedFromReport  = null;
  var totalPercentageFromReport= null;
  var hasReport                = false;

  // Column index hints
  var subjectIdx = null, heldIdx = null, attendIdx = null, percentIdx = null;

  // Iterate over all <tr> elements
  var trRe   = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  var tdRe   = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
  var thRe   = /<th\b/i;
  var trMatch;

  while ((trMatch = trRe.exec(tableHtml)) !== null) {
    var rowHtml    = trMatch[1];
    var isHeader   = thRe.test(rowHtml);
    var cells      = [];
    var tdMatch;
    tdRe.lastIndex = 0;
    while ((tdMatch = tdRe.exec(rowHtml)) !== null) {
      cells.push(cleanHtmlText_(tdMatch[1]));
    }

    if (isHeader) {
      // Map column names to indices
      for (var ci = 0; ci < cells.length; ci++) {
        var lower = cells[ci].toLowerCase().trim();
        if (lower.indexOf('subject') !== -1 || lower.indexOf('course') !== -1 || lower.indexOf('paper') !== -1) {
          subjectIdx = ci;
        } else if (lower.indexOf('held') !== -1) {
          heldIdx = ci;
        } else if (lower.indexOf('attend') !== -1 && lower.indexOf('attendance') === -1) {
          attendIdx = ci;
        } else if (lower === '%' || lower.indexOf('percent') !== -1) {
          percentIdx = ci;
        }
      }
      continue;
    }

    // Skip sparse rows
    var nonEmpty = cells.filter(function(c) { return c.trim() !== ''; });
    if (nonEmpty.length < 3) continue;

    var subjectName      = null;
    var totalClasses     = null;
    var attendedClasses  = null;
    var percentage       = null;

    if (subjectIdx !== null && heldIdx !== null && attendIdx !== null) {
      if (subjectIdx < cells.length) {
        var sv = cells[subjectIdx].trim();
        if (sv) subjectName = sv;
      }
      if (heldIdx < cells.length)   totalClasses    = parseIntOrNull_(cells[heldIdx]);
      if (attendIdx < cells.length) attendedClasses = parseIntOrNull_(cells[attendIdx]);
      if (percentIdx !== null && percentIdx < cells.length) {
        percentage = parsePercentage_(cells[percentIdx]);
      }
    } else {
      // Fallback: find first text-like cell, then read numbers after it
      var subjectCellIdx = -1;
      for (var fi = 0; fi < cells.length; fi++) {
        var fc = cells[fi];
        if (fc && (fc.toLowerCase().trim() === 'total' || looksLikeSubjectCell_(fc))) {
          subjectCellIdx = fi;
          subjectName    = fc;
          break;
        }
      }
      if (subjectCellIdx >= 0) {
        var nums = [];
        for (var ni = subjectCellIdx + 1; ni < cells.length; ni++) {
          var n = parseIntOrNull_(cells[ni]);
          if (n !== null) nums.push(n);
        }
        if (nums.length >= 2) {
          totalClasses    = nums[0];
          attendedClasses = nums[1];
        }
      }
    }

    // Last-resort percentage extraction
    if (percentage === null) {
      for (var pi = cells.length - 1; pi >= 0; pi--) {
        var pv = parsePercentage_(cells[pi]);
        if (pv !== null) { percentage = pv; break; }
      }
    }

    // Compute percentage from held/attended if still missing
    if (percentage === null && totalClasses && totalClasses > 0 && attendedClasses !== null) {
      percentage = (attendedClasses / totalClasses) * 100;
    }
    if (percentage === null) percentage = 0;

    if (subjectName === null)   continue;
    if (totalClasses === null || attendedClasses === null) continue;

    var lsub = subjectName.toLowerCase().trim();

    if (lsub === 'total') {
      hasReport                = true;
      totalHeldFromReport      = totalClasses;
      totalAttendedFromReport  = attendedClasses;
      totalPercentageFromReport= percentage;
      continue;
    }

    // Skip header-like rows
    if (lsub.indexOf('subject') !== -1 || lsub === 'sr' || lsub === 'sl') continue;

    subjects.push({
      subject        : subjectName,
      totalClasses   : totalClasses,
      attendedClasses: attendedClasses,
      percentage     : roundOne_(percentage),
    });
  }

  // Compute aggregates from subject list (fallback when no "total" row)
  var sumHeld     = subjects.reduce(function(s, x) { return s + x.totalClasses;    }, 0);
  var sumAttended = subjects.reduce(function(s, x) { return s + x.attendedClasses; }, 0);
  var overallPct  = sumHeld === 0 ? 0 : (sumAttended / sumHeld) * 100;

  return {
    overallPercentage: roundOne_(totalPercentageFromReport !== null ? totalPercentageFromReport : overallPct),
    totalClasses     : totalHeldFromReport !== null ? totalHeldFromReport : sumHeld,
    totalAttended    : totalAttendedFromReport !== null ? totalAttendedFromReport : sumAttended,
    studentName      : studentName,
    hasReport        : hasReport,
    subjects         : subjects,
  };
}

// =============================================================================
//  AES-128-CBC ENCRYPTION
//  (Pure JavaScript implementation – no external libraries required)
//  The portal expects: AES(password, key=AES_SECRET, iv=AES_SECRET, mode=CBC,
//                           padding=PKCS7), output as Base64.
// =============================================================================

/**
 * AES-128-CBC encrypt with PKCS#7 padding.
 * @param {string} plaintext
 * @param {string} keyStr   – 16-char string (128-bit key)
 * @param {string} ivStr    – 16-char string
 * @returns {string} Base64-encoded ciphertext
 */
function encryptAesCbc_(plaintext, keyStr, ivStr) {
  var keyBytes = stringToBytes_(keyStr);
  var ivBytes  = stringToBytes_(ivStr);
  var ptBytes  = stringToBytes_(plaintext);

  // PKCS#7 pad to 16-byte blocks
  var padLen    = 16 - (ptBytes.length % 16);
  var padded    = ptBytes.slice();
  for (var i = 0; i < padLen; i++) padded.push(padLen);

  // Expand AES key schedule
  var w = aesKeyExpansion_(keyBytes);

  var cipher = [];
  var prev   = ivBytes.slice();   // previous ciphertext block (starts as IV)

  for (var block = 0; block < padded.length; block += 16) {
    var pt  = padded.slice(block, block + 16);
    var xor = pt.map(function(b, idx) { return b ^ prev[idx]; });
    var ct  = aesEncryptBlock_(xor, w);
    cipher  = cipher.concat(ct);
    prev    = ct;
  }

  // Utilities.base64Encode accepts a number[] byte array in Apps Script.
  // Explicitly convert to ensure cross-runtime safety.
  return Utilities.base64Encode(cipher.map(function(b) { return b & 0xff; }));
}

// ── AES core ──────────────────────────────────────────────────────────────────

var S_BOX = [
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
];

var RCON = [0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36];

function aesKeyExpansion_(key) {
  var Nk = 4, Nr = 10;
  var w  = [];
  for (var i = 0; i < Nk; i++) {
    w[i] = [key[4*i], key[4*i+1], key[4*i+2], key[4*i+3]];
  }
  for (var i = Nk; i < 4 * (Nr + 1); i++) {
    var temp = w[i - 1].slice();
    if (i % Nk === 0) {
      temp = [
        S_BOX[temp[1]] ^ RCON[i / Nk],
        S_BOX[temp[2]],
        S_BOX[temp[3]],
        S_BOX[temp[0]],
      ];
    }
    w[i] = w[i - Nk].map(function(b, idx) { return b ^ temp[idx]; });
  }
  return w;
}

function aesEncryptBlock_(block, w) {
  var state = [
    [block[0], block[4], block[8],  block[12]],
    [block[1], block[5], block[9],  block[13]],
    [block[2], block[6], block[10], block[14]],
    [block[3], block[7], block[11], block[15]],
  ];

  addRoundKey_(state, w, 0);

  for (var round = 1; round <= 10; round++) {
    subBytes_(state);
    shiftRows_(state);
    if (round < 10) mixColumns_(state);
    addRoundKey_(state, w, round);
  }

  return [
    state[0][0], state[1][0], state[2][0], state[3][0],
    state[0][1], state[1][1], state[2][1], state[3][1],
    state[0][2], state[1][2], state[2][2], state[3][2],
    state[0][3], state[1][3], state[2][3], state[3][3],
  ];
}

function addRoundKey_(state, w, round) {
  for (var c = 0; c < 4; c++) {
    for (var r = 0; r < 4; r++) {
      state[r][c] ^= w[round * 4 + c][r];
    }
  }
}

function subBytes_(state) {
  for (var r = 0; r < 4; r++)
    for (var c = 0; c < 4; c++)
      state[r][c] = S_BOX[state[r][c]];
}

function shiftRows_(state) {
  var t;
  // Row 1: shift left by 1
  t = state[1][0]; state[1][0] = state[1][1]; state[1][1] = state[1][2]; state[1][2] = state[1][3]; state[1][3] = t;
  // Row 2: shift left by 2
  t = state[2][0]; state[2][0] = state[2][2]; state[2][2] = t;
  t = state[2][1]; state[2][1] = state[2][3]; state[2][3] = t;
  // Row 3: shift left by 3
  t = state[3][3]; state[3][3] = state[3][2]; state[3][2] = state[3][1]; state[3][1] = state[3][0]; state[3][0] = t;
}

function mixColumns_(state) {
  for (var c = 0; c < 4; c++) {
    var s0 = state[0][c], s1 = state[1][c], s2 = state[2][c], s3 = state[3][c];
    state[0][c] = gmul_(2,s0) ^ gmul_(3,s1) ^ s2         ^ s3;
    state[1][c] = s0          ^ gmul_(2,s1) ^ gmul_(3,s2) ^ s3;
    state[2][c] = s0          ^ s1          ^ gmul_(2,s2) ^ gmul_(3,s3);
    state[3][c] = gmul_(3,s0) ^ s1          ^ s2          ^ gmul_(2,s3);
  }
}

/** Galois-field multiplication mod 0x11b */
function gmul_(a, b) {
  var p = 0;
  for (var i = 0; i < 8; i++) {
    if (b & 1) p ^= a;
    var hiBit = a & 0x80;
    a = (a << 1) & 0xff;
    if (hiBit) a ^= 0x1b;
    b >>= 1;
  }
  return p;
}

// =============================================================================
//  UTILITY HELPERS
// =============================================================================

function stringToBytes_(str) {
  var bytes = [];
  for (var i = 0; i < str.length; i++) {
    bytes.push(str.charCodeAt(i) & 0xff);
  }
  return bytes;
}

function cleanHtmlText_(input) {
  return input
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g,  '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g,  "'")
    .replace(/&lt;/g,   '<')
    .replace(/&gt;/g,   '>')
    .replace(/\s+/g,    ' ')
    .trim();
}

function extractLabeledValue_(plainText, label) {
  var re = new RegExp(
    label + '\\s*:\\s*(.*?)\\s*(?=RollNo\\s*:|Student Name\\s*:|Course\\s*:|Branch\\s*:|Semester\\s*:|$)',
    'is'
  );
  var m = re.exec(plainText);
  var v = m && m[1] ? m[1].trim() : null;
  return (v && v.length > 0) ? v : null;
}

function looksLikeSubjectCell_(value) {
  var lower = value.toLowerCase();
  if (!/[a-z]/i.test(lower)) return false;
  return (
    lower.indexOf('percentage') === -1 &&
    lower.indexOf('attended')   === -1 &&
    lower.indexOf('held')       === -1 &&
    lower.indexOf('total')      === -1
  );
}

function parseIntOrNull_(str) {
  var v = parseInt(str.trim(), 10);
  return isNaN(v) ? null : v;
}

function parsePercentage_(str) {
  var trimmed = str.trim();
  if (!trimmed) return null;
  if (trimmed.charAt(0) === '.') trimmed = '0' + trimmed;
  // Accept both decimal (83.3) and whole-number (75, 100) percentages
  if (!/^\d+(\.\d*)?$/.test(trimmed)) return null;
  var v = parseFloat(trimmed);
  if (isNaN(v) || v < 0 || v > 100) return null;
  return v;
}

function roundOne_(n) {
  return Math.round(n * 10) / 10;
}

function trim_(s) {
  return (s || '').toString().replace(/^\s+|\s+$/g, '');
}

// =============================================================================
//  RESPONSE BUILDERS
// =============================================================================

function successResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify({ success: true, data: data }))
    .setMimeType(ContentService.MimeType.JSON);
}

function errorResponse(message) {
  return ContentService
    .createTextOutput(JSON.stringify({ success: false, error: message }))
    .setMimeType(ContentService.MimeType.JSON);
}

// =============================================================================
//  LOGGING
//  Logs go to Apps Script's built-in Logger (View → Logs in the editor).
//  They are NOT sent to the client – safe to log debug info here.
// =============================================================================

function log_(msg) {
  Logger.log(msg);
}

// =============================================================================
//  QUICK TEST (run from the Apps Script editor, not from the web)
// =============================================================================
//
//  function testFetch() {
//    var result = doPost({
//      postData: {
//        contents: JSON.stringify({
//          rollNumber: 'YOUR_ROLL_NUMBER',
//          password  : 'YOUR_PASSWORD',
//          college   : 'aus',          // or 'acet'
//          fromDate  : '',
//          toDate    : ''
//        })
//      }
//    });
//    Logger.log(result.getContent());
//  }
//
// =============================================================================
