import { encryptPassword as portalEncrypt } from './crypto.js';

const BASE_URL = 'https://info.aec.edu.in';
const PREFIX = '/aus';

async function request(url, options, cookieJar) {
  const fetchOptions = { ...options, redirect: 'manual' };
  fetchOptions.headers = fetchOptions.headers || {};
  fetchOptions.headers['User-Agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';
  fetchOptions.headers['Accept-Language'] = 'en-US,en;q=0.9';
  fetchOptions.headers['Accept-Encoding'] = 'gzip, deflate, br, zstd';
  fetchOptions.headers['Sec-Ch-Ua'] = '"Chromium";v="146", "Not-A.Brand";v="24", "Google Chrome";v="146"';
  fetchOptions.headers['Sec-Ch-Ua-Mobile'] = '?0';
  fetchOptions.headers['Sec-Ch-Ua-Platform'] = '"Linux"';
  
  if (fetchOptions.method === 'POST') {
    fetchOptions.headers['Cache-Control'] = 'max-age=0';
    fetchOptions.headers['Origin'] = BASE_URL;
    fetchOptions.headers['Referer'] = url;
  }
  
  if (cookieJar && Object.keys(cookieJar).length) {
    fetchOptions.headers.Cookie = Object.entries(cookieJar)
      .map(([k, v]) => `${k}=${v}`)
      .join('; ');
  }
  const response = await fetch(url, fetchOptions);
  const body = await response.text();
  
  // Debug: log raw headers
  const setCookieRaw = response.headers.get('set-cookie');
  const locationRaw = response.headers.get('location');
  console.log('[AUS] Request URL:', url);
  console.log('[AUS] Response status:', response.status);
  console.log('[AUS] set-cookie raw:', setCookieRaw);
  console.log('[AUS] location raw:', locationRaw);
  
  if (cookieJar) {
    const setCookieRaw = response.headers.get('set-cookie');
    if (setCookieRaw) {
      const entries = setCookieRaw.split(/,(?=[^ ])/);
      for (const entry of entries) {
        const nameValue = entry.split(';')[0].trim();
        const eqIdx = nameValue.indexOf('=');
        if (eqIdx === -1) continue;
        const name = nameValue.substring(0, eqIdx).trim();
        const value = nameValue.substring(eqIdx + 1).trim();
        if (name) cookieJar[name] = value;
      }
    }
    console.log('[AUS] CookieJar after:', JSON.stringify(cookieJar));
  }
  return { response, body };
}

async function extractHiddenInputs(html) {
  const viewstate = (html.match(/id="__VIEWSTATE"\s+value="([^"]+)"/) || [])[1] || '';
  const generator = (html.match(/id="__VIEWSTATEGENERATOR"\s+value="([^"]+)"/) || [])[1] || '';
  const validation = (html.match(/id="__EVENTVALIDATION"\s+value="([^"]+)"/) || [])[1] || '';
  return { viewstate, generator, validation };
}

async function login(rollNumber, password, cookieJar) {
  // Step 1: GET default.aspx - check for gate redirect
  let { response: resp1, body: html } = await request(`${BASE_URL}${PREFIX}/default.aspx`, {}, cookieJar);
  
  // Check if redirected to authcheck (gate page)
  const location = resp1.headers.get('location');
  if (location && location.includes('authcheck')) {
    console.log('[AUS] Gate detected, following authcheck redirect');
    // Follow authcheck, then retry default.aspx
    await request(`${BASE_URL}${PREFIX}/authcheck.aspx`, {}, cookieJar);
    const gateResult = await request(`${BASE_URL}${PREFIX}/default.aspx`, {}, cookieJar);
    html = gateResult.body;
  }
  
  let { viewstate, generator, validation } = await extractHiddenInputs(html);
  
  // Step 2: Encrypt password
  const encrypted = await portalEncrypt(password);
  
  // Step 3: POST login
  const body = new URLSearchParams();
  body.append('__VIEWSTATE', viewstate);
  body.append('__VIEWSTATEGENERATOR', generator);
  body.append('__EVENTVALIDATION', validation);
  body.append('userType', 'rbtStudent');
  body.append('txtUserId', rollNumber);
  body.append('txtPassword', encrypted);
  body.append('hdnpwd', encrypted);
  body.append('btnLogin', 'LOGIN');
  
  const { response: resp } = await request(`${BASE_URL}${PREFIX}/default.aspx`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString()
  }, cookieJar);

  // Step 4: Verify login success
  console.log('[AUS] POST login response status:', resp.status);
  console.log('[AUS] CookieJar after POST:', JSON.stringify(cookieJar));
  
  const isRedirect = resp.status === 301 || resp.status === 302 || resp.status === 303;
  const hasFrmAuth = cookieJar['frmAuth'] !== undefined;
  const redirectLocation = resp.headers.get('location') || '';
  
  // Check for successful redirect to StudentMaster and frmAuth cookie
  if (isRedirect && redirectLocation.includes('StudentMaster.aspx') && hasFrmAuth) {
    // Follow redirect to establish full session
    const fullUrl = redirectLocation.startsWith('/') ? `${BASE_URL}${redirectLocation}` : redirectLocation;
    console.log('[AUS] Following session redirect to:', fullUrl);
    await request(fullUrl, {}, cookieJar);
    return true;
  }
  
  // Check for error redirect
  if (redirectLocation.includes('errorpage')) {
    throw new Error('Invalid credentials');
  }
  
  throw new Error('Invalid credentials');
}

async function fetchAttendanceData(cookieJar) {
  await request(`${BASE_URL}${PREFIX}/StudentMaster.aspx`, {}, cookieJar);

  const { body: html } = await request(`${BASE_URL}${PREFIX}/Academics/StudentProfile.aspx?scrid=17`, {}, cookieJar);

  const rollNoMatch = html.match(/id="ctl00_CapPlaceHolder_txtRollNo"[^>]*value="([^"]+)"/);
  const rollNo = rollNoMatch ? rollNoMatch[1] : '';
  console.log('[AUS] Roll number:', rollNo);

  const authToken = cookieJar['AuthToken'] || '';
  console.log('[AUS] AuthToken from cookie:', authToken);

  const { body: jsonText, response: showResp } = await request(
    `${BASE_URL}${PREFIX}/Academics/studentprofile.aspx/ShowStudentProfileNew`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
        'X-Auth-Token': authToken,
        'Accept': 'application/json, text/javascript, */*',
        'Referer': `${BASE_URL}${PREFIX}/Academics/StudentProfile.aspx?scrid=17`,
        'Origin': BASE_URL,
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-origin'
      },
      body: JSON.stringify({ RollNo: rollNo, isImageDisplay: false })
    },
    cookieJar
  );
  console.log('[AUS] ShowStudentProfileNew status:', showResp.status);
  console.log('[AUS] ShowStudentProfileNew response (300):', jsonText.substring(0, 300));

  if (showResp.status !== 200) throw new Error(`ShowStudentProfileNew returned ${showResp.status}`);

  const json = JSON.parse(jsonText);
  if (!json.d) throw new Error('No profile data in response');

  const profileHtml = json.d;
  const profileSectionStart = profileHtml.indexOf("<div id='divProfile_Present'>");
  if (profileSectionStart === -1) throw new Error('Profile section not found');
  const profileSectionEnd = profileHtml.indexOf("</div>", profileSectionStart);
  const profileSection = profileHtml.substring(profileSectionStart, profileSectionEnd);

  const tableStart = profileSection.indexOf('<table');
  if (tableStart === -1) throw new Error('Attendance table not found');
  const tableEnd = profileSection.indexOf('</table>', tableStart);
  const tableHtml = profileSection.substring(tableStart, tableEnd + 8);

  const rows = [];
  const trRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/gi;
  let trMatch;
  while ((trMatch = trRegex.exec(tableHtml)) !== null) {
    rows.push(trMatch[1]);
  }

  if (rows.length < 2) throw new Error('No attendance data found');

  const subjects = [];
  let totalHeld = 0, totalAttended = 0, overallPercentage = 0;
  const headerCells = rows[0].match(/<t[hd][^>]*>([\s\S]*?)<\/t[hd]>/gi) || [];
  const subjIdx = 1, heldIdx = 2, attendIdx = 3, percentIdx = 4;

  for (let i = 1; i < rows.length; i++) {
    const cells = rows[i].match(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi) || [];
    if (cells.length === 0) continue;

    const firstCell = cells[0] || '';
    if (firstCell.includes('colspan="2"') || firstCell.includes("colspan='2'")) {
      const text = firstCell.replace(/<[^>]+>/g, '').trim().toLowerCase();
      if (text.includes('total')) {
        totalHeld = parseInt(cells[1]?.replace(/<[^>]+>/g, '').trim(), 10) || 0;
        totalAttended = parseInt(cells[2]?.replace(/<[^>]+>/g, '').trim(), 10) || 0;
        const pctText = cells[3]?.replace(/<[^>]+>/g, '').trim() || '';
        overallPercentage = parseFloat(pctText) || 0;
      }
      continue;
    }

    const subjectName = cells[subjIdx] ? cells[subjIdx].replace(/<[^>]+>/g, '').trim() : '';
    const cleanSubjectName = subjectName.toLowerCase();
    if (!subjectName || cleanSubjectName === 'subject' || cleanSubjectName === 'sl.no.' || /^[\d]+$/.test(cleanSubjectName)) continue;

    const held = parseInt(cells[heldIdx]?.replace(/<[^>]+>/g, '').trim(), 10) || 0;
    const attended = parseInt(cells[attendIdx]?.replace(/<[^>]+>/g, '').trim(), 10) || 0;
    const pctText = cells[percentIdx]?.replace(/<[^>]+>/g, '').trim() || '';
    const percentage = parseFloat(pctText) || 0;

    subjects.push({
      subject: subjectName,
      totalClasses: held,
      attendedClasses: attended,
      percentage
    });
  }

  const bioDataStart = profileHtml.indexOf('>Name<');
  let studentName = '';
  if (bioDataStart !== -1) {
    const afterName = profileHtml.substring(bioDataStart);
    const nameTdMatch = afterName.match(/<td[^>]*colspan='3'[^>]*>([^<]+)<\/td>/i);
    if (nameTdMatch) {
      studentName = nameTdMatch[1].replace(/<[^>]+>/g, '').trim();
    }
  }

  return {
    overallPercentage,
    totalClasses: totalHeld,
    totalAttended,
    subjects,
    studentName,
    hasReport: subjects.length > 0
  };
}

export async function fetchAttendance({ rollNumber, password, fromDate = '', toDate = '', mode = 'tillNow' }) {
  const cookieJar = {};
  await login(rollNumber, password, cookieJar);
  const result = await fetchAttendanceData(cookieJar);
  return result;
}