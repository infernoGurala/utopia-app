import { parseAttendanceHtml } from './parser.js';
import { encryptPassword } from './crypto.js';

const BASE_URL = 'https://info.aec.edu.in';
const PREFIX = '/acet';

async function request(url, options, cookieJar) {
  const fetchOptions = { ...options, redirect: 'manual' };
  fetchOptions.headers = fetchOptions.headers || {};
  fetchOptions.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  if (cookieJar && Object.keys(cookieJar).length) {
    fetchOptions.headers.Cookie = Object.entries(cookieJar)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');
  }
  const response = await fetch(url, fetchOptions);

  // Read body once and return both response and body
  const body = await response.text();
  console.log('[ACET] Request URL:', url);
  console.log('[ACET] Response status:', response.status);
  const setCookie = response.headers.get('set-cookie');
  const location = response.headers.get('location');
  console.log('[ACET] Response headers - set-cookie:', setCookie);
  console.log('[ACET] Response headers - location:', location);
  console.log('[ACET] Response body (first 1000):', body.substring(0, 1000));
  console.log('[ACET] CookieJar contents:', JSON.stringify(cookieJar));

  if (cookieJar) {
    let rawCookies = [];
    const hasGetAll = typeof response.headers.getAll === 'function';
    console.log('[ACET] headers.getAll exists:', hasGetAll);
    try {
      if (hasGetAll) {
        rawCookies = response.headers.getAll('set-cookie');
      }
    } catch (e) {
      console.log('[ACET] getAll error:', e.message);
      rawCookies = [];
    }
    console.log('[ACET] rawCookies from getAll:', JSON.stringify(rawCookies));
    if (!rawCookies.length) {
      const raw = response.headers.get('set-cookie');
      console.log('[ACET] raw from get:', raw);
      if (raw) rawCookies = [raw];
    }
    console.log('[ACET] Raw cookies array:', JSON.stringify(rawCookies));
    for (const cookie of rawCookies) {
      const parts = cookie.split(';');
      const main = parts[0];
      const eqIdx = main.indexOf('=');
      if (eqIdx === -1) continue;
      const name = main.substring(0, eqIdx).trim();
      const value = main.substring(eqIdx + 1).trim();
      if (name) cookieJar[name] = value;
    }
    console.log('[ACET] CookieJar after update:', JSON.stringify(cookieJar));
  }
  return { response, body };
}

async function handleGate(cookieJar) {
  // If initial page is blocked (gate), hit authcheck.aspx then retry default.aspx
  let { body: html } = await request(`${BASE_URL}${PREFIX}/default.aspx`, {}, cookieJar);
  if (!html.includes('__VIEWSTATE') && !html.includes('txtUserId')) {
    await request(`${BASE_URL}${PREFIX}/authcheck.aspx`, {}, cookieJar);
    const result = await request(`${BASE_URL}${PREFIX}/default.aspx`, {}, cookieJar);
    html = result.body;
  }
  return html;
}

function detectLoginFields(html) {
  // ACET portal uses these specific field names
  // Dynamic detection is unreliable — field names are stable
  return { userField: 'txtId2', pwdField: 'txtPwd2' };
}

async function login(rollNumber, password, cookieJar) {
  let html = await handleGate(cookieJar);
  const { userField, pwdField } = detectLoginFields(html);
  
  // Extract viewstate if present
  const viewstate = (html.match(/id="__VIEWSTATE"\s+value="([^"]+)"/) || [])[1] || '';
  const generator = (html.match(/id="__VIEWSTATEGENERATOR"\s+value="([^"]+)"/) || [])[1] || '';
  const validation = (html.match(/id="__EVENTVALIDATION"\s+value="([^"]+)"/) || [])[1] || '';
  
  console.log('[ACET] Extracted values (first 50 chars each):');
  console.log('[ACET]   __VIEWSTATE:', viewstate.substring(0, 50));
  console.log('[ACET]   __VIEWSTATEGENERATOR:', generator.substring(0, 50));
  console.log('[ACET]   __EVENTVALIDATION:', validation.substring(0, 50));
  console.log('[ACET]   Detected userField:', userField);
  console.log('[ACET]   Detected pwdField:', pwdField);
  
  // Encrypt password for ACET (same as AUS)
  const encryptedPwd = await encryptPassword(password);
  console.log('[ACET] Password encrypted, length:', encryptedPwd.length);
  
  // Build payload with multiple variations (portal often expects several)
  const body = new URLSearchParams();
  if (viewstate) body.append('__VIEWSTATE', viewstate);
  if (generator) body.append('__VIEWSTATEGENERATOR', generator);
  if (validation) body.append('__EVENTVALIDATION', validation);
  // Add common fields
  body.append('txtId1', rollNumber);
  body.append('txtId2', rollNumber);
  body.append('txtId3', rollNumber);
  body.append('txtPwd1', encryptedPwd);
  body.append('txtPwd2', encryptedPwd);
  body.append('txtPwd3', encryptedPwd);
  body.append('hdnpwd1', encryptedPwd);
  body.append('hdnpwd2', encryptedPwd);
  body.append('hdnpwd3', encryptedPwd);
  // Image button coordinates
  body.append('imgBtn2.x', '42');
  body.append('imgBtn2.y', '6');
  
console.log('[ACET] Full form body:', body.toString());
  
  const { response: resp } = await request(`${BASE_URL}${PREFIX}/default.aspx`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString()
  }, cookieJar);
  
  // Success if redirect OR frmAuth cookie set OR StudentMaster.aspx not showing login
  const success = (resp.status === 301 || resp.status === 302 || resp.status === 303) ||
                  cookieJar['frmAuth'] !== undefined;
  if (success) return true;
  
  // Check StudentMaster.aspx to confirm
  const { body: checkHtml } = await request(`${BASE_URL}${PREFIX}/StudentMaster.aspx`, {}, cookieJar);
  if (!checkHtml.includes('btnLogin') && !checkHtml.includes('txtUserId')) {
    return true; // Not login page => success
  }
  throw new Error('Invalid credentials');
}

async function extractToken(html, cookieJar) {
  // Strategy A: var _tkn = '...'
  let match = html.match(/var\s+_tkn\s*=\s*'([^']+)'/);
  if (match) {
    console.log('[ACET] Extracted token (strategy A):', match[1]);
    return match[1];
  }
  // Strategy B: hidden input with name/id containing token
  match = html.match(/<input[^>]*(?:name|id)=["'][^"']*(?:tkn|token)[^"']*["'][^>]*value=["']([^"']+)["']/i);
  if (match) {
    console.log('[ACET] Extracted token (strategy B):', match[1]);
    return match[1];
  }
  // Strategy C: var token = '...', var authToken = '...'
  match = html.match(/var\s+(?:token|authToken)\s*=\s*'([^']+)'/i);
  if (match) {
    console.log('[ACET] Extracted token (strategy C):', match[1]);
    return match[1];
  }
  // Strategy D: fetch linked JS and search (simplify: try common JS file)
  const jsMatch = html.match(/<script[^>]*src=["']([^"']+\.js)["']/i);
  if (jsMatch) {
    const jsUrl = jsMatch[1].startsWith('http') ? jsMatch[1] : `${BASE_URL}${PREFIX}/${jsMatch[1]}`;
    const { body: jsText } = await request(jsUrl, {}, cookieJar);
    match = jsText.match(/['"]_tkn['"]\s*:\s*['"]([^'"]+)['"]/);
    if (match) {
      console.log('[ACET] Extracted token (strategy D):', match[1]);
      return match[1];
    }
  }
  console.log('[ACET] No token found');
  return '';
}

async function fetchAttendanceData(cookieJar, fromDate, toDate, mode) {
  console.log('[ACET] fetchAttendanceData called');
  // Build date params: mode = 'tillNow' -> empty strings; else use provided
  let attFromDate = '', attToDate = '';
  if (mode === 'period') {
    // format as DD-MM-YYYY (already should be)
    attFromDate = fromDate;
    attToDate = toDate;
  }
  // Fetch attendance page to get token
  let { body: html } = await request(`${BASE_URL}${PREFIX}/Academics/studentattendance.aspx?scrid=3&showtype=SA`, {}, cookieJar);
  let token = await extractToken(html, cookieJar);
  console.log('[ACET] Token value after extractToken:', token);
  
  const showUrl = `${BASE_URL}${PREFIX}/Academics/studentattendance.aspx/ShowAttendance`;
  const payload = { fromDate: attFromDate, toDate: attToDate, excludeothersubjects: false };
  const headers = {
    'Content-Type': 'application/json; charset=UTF-8',
    'x-requested-with': 'XMLHttpRequest',
    'cache-control': 'no-cache',
    'pragma': 'no-cache'
  };
  if (token) headers['x-auth-token'] = token;
  
  const { body: rawText } = await request(showUrl, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload)
  }, cookieJar);
  
  console.log('[ACET] ShowAttendance raw response (first 500):', rawText.substring(0, 500));
  let json;
  try {
    json = JSON.parse(rawText);
  } catch(e) {
    throw new Error('ShowAttendance returned HTML, not JSON: ' + rawText.substring(0, 200));
  }
  if (!json.d) throw new Error('No attendance data received');
  console.log('[ACET] json.d decoded (first 500):', json.d.substring(0, 500));
  const parsed = parseAttendanceHtml(json.d);
if (!parsed.hasReport && (!parsed.subjects || parsed.subjects.length === 0)) throw new Error('Attendance table not found');
  return parsed;
}

export async function fetchAttendance({ rollNumber, password, fromDate, toDate, mode = 'tillNow' }) {
  console.log('[ACET] fetchAttendance called with rollNumber:', rollNumber);
  const cookieJar = {};
  await login(rollNumber, password, cookieJar);
  const result = await fetchAttendanceData(cookieJar, fromDate, toDate, mode);
  return result;
}
