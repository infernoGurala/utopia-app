# ACET Attendance Portal - Technical Documentation

## Overview

The ACET Attendance Portal is hosted at `info.aec.edu.in` under the `/acet` prefix. This document describes the complete flow for authenticating and fetching attendance data from the ACET portal.

## Key Difference from AUS

ACET uses a **different authentication pattern** than AUS:
- **AUS:** Redirect-based (302 redirect + two cookies: `ASP.NET_SessionId` + `frmAuth`)
- **ACET:** Session-based (200 OK + one cookie: `ASP.NET_SessionId` only)

## Portal Configuration

```dart
static const String _portalHost = 'info.aec.edu.in';
static const String _prefix = '/acet';
static const String _loginPath = '$_prefix/default.aspx';
static const String _studentMasterPath = '$_prefix/StudentMaster.aspx';
static const String _attendancePagePath = '$_prefix/Academics/studentattendance.aspx?scrid=3&showtype=SA';
static const String _attendancePath = '$_prefix/Academics/studentattendance.aspx/ShowAttendance';
static const String _ajaxJsPath = '$_prefix/JSFiles/AjaxMethods.js';
```

## Authentication Flow

### Step 1: Fetch Login Tokens

**Request:**
- Method: `GET`
- Path: `/acet/default.aspx`
- Purpose: Retrieve ASP.NET ViewState tokens required for login

**Response Parsing:**
Identical to AUS - extract hidden form fields:
1. `__VIEWSTATE`
2. `__VIEWSTATEGENERATOR`
3. `__EVENTVALIDATION`

### Step 2: Password Encryption

Same AES-128-CBC encryption as AUS:

```dart
Key: UTF-8 bytes of '8701661282118308'
IV: UTF-8 bytes of '8701661282118308'
Output: Base64 encoded
```

### Step 3: Submit Login Form

**Request:**
- Method: `POST`
- Path: `/acet/default.aspx`
- Content-Type: `application/x-www-form-urlencoded`
- Body: Form-encoded with tokens + credentials

**Form Fields (same as AUS):**
```
__VIEWSTATE=<from step 1>
__VIEWSTATEGENERATOR=<from step 1>
__EVENTVALIDATION=<from step 1>
userType=rbtStudent
txtUserId=<roll_number>
txtPassword=<encrypted_password>
hdnpwd=<encrypted_password>
btnLogin=LOGIN
```

### Step 4: Validate Login Success (ACET-SPECIFIC)

ACET uses a **session-based** authentication pattern - **completely different from AUS**:

**Success Criteria:**
1. Response status code is **200 OK** (NOT a redirect)
2. Server must set `ASP.NET_SessionId` cookie
3. Response body must **NOT contain login form fields**

**Cookies Set on Success:**
- `ASP.NET_SessionId` - Session identifier
- **NO `frmAuth` cookie** (ACET does not use it)

**Login Failure Detection:**
```dart
final sessionId = cookies['ASP.NET_SessionId'];
final loginFailed =
    response.body.contains('txtId2') ||
    response.body.contains('txtPwd2');

if (sessionId == null || sessionId.isEmpty || loginFailed) {
  throw Exception('Invalid credentials');
}
```

The presence of `txtId2` or `txtPwd2` in the response body indicates the login form was returned, meaning authentication failed.

## Attendance Fetching Flow

After successful authentication, the attendance fetching flow is **identical to AUS**:

### Step 1: Access Student Master

**Request:**
- Method: `GET`
- Path: `/acet/StudentMaster.aspx`
- Cookies: Include `ASP.NET_SessionId`

### Step 2: Load Attendance Page

**Request:**
- Method: `GET`
- Path: `/acet/Academics/studentattendance.aspx?scrid=3&showtype=SA`
- Cookies: Session cookie
- Purpose: Load the attendance page and extract web method token

**Web Method Token:**
```javascript
var _tkn = '<token_value>';
```

### Step 3: Load AJAX Methods Script

**Request:**
- Method: `GET`
- Path: `/acet/JSFiles/AjaxMethods.js`
- Purpose: Load JavaScript functions

### Step 4: Fetch Attendance Data

**Request:**
- Method: `POST`
- Path: `/acet/Academics/studentattendance.aspx/ShowAttendance`
- Content-Type: `application/json; charset=UTF-8`
- Headers: Same as AUS

**Request Body:**
```json
{
  "fromDate": "<date_in_dd/mm/yyyy_format>",
  "toDate": "<date_in_dd/mm/yyyy_format>",
  "excludeothersubjects": false
}
```

**Response:**
```json
{
  "d": "<HTML_string_containing_attendance_table>"
}
```

## Response Parsing

**Identical to AUS** - the HTML structure is the same:
1. Look for `<table id="tblReport">`
2. Extract subject-wise data from table rows
3. Calculate totals and percentages

### Parsing Logic (Same as AUS)

1. **Header Detection:** Find column indices from `<th>` elements
2. **Data Row Processing:** Extract cell values per row
3. **Percentage Calculation:** From held/attended if not in HTML
4. **Special Rows:** Skip headers, capture totals

## Error Handling

| Error Type | Detection | Message |
|------------|----------|---------|
| Invalid credentials | Missing `ASP.NET_SessionId` OR response is login page | "Invalid credentials" |
| No attendance data | Empty subjects list AND no report | "Attendance data was not found" |
| Network error | HTTP status != 200 | "Could not fetch attendance right now" |
| General error | Any other exception | "Unable to load attendance right now" |

## Comparison: AUS vs ACET

| Aspect | AUS | ACET |
|--------|-----|------|
| URL Prefix | `/aus` | `/acet` |
| Login Response | 302 redirect | 200 OK |
| Required Cookies | `ASP.NET_SessionId` + `frmAuth` | `ASP.NET_SessionId` only |
| Success Detection | Check redirect + cookies | Check session cookie + no login form |
| `frmAuth` Cookie | Required | Not used |

## Security Considerations

- Password is encrypted client-side before transmission
- Only `ASP.NET_SessionId` cookie required (no additional auth tokens)
- Origin and Referer headers prevent CSRF attacks
- Login failure detected by presence of form fields in response
- All communication is over HTTPS

## Constants

```dart
static const String _portalHost = 'info.aec.edu.in';
static const String _aesSecret = '8701661282118308';
static const Duration _timeout = Duration(seconds: 20);
static const String _userAgent = 'Mozilla/5.0 (Linux; Android 14; ...)';
```

## Debugging Tips

If ACET login fails:

1. **Check response status code** - should be 200, not 302
2. **Check cookies** - should contain `ASP.NET_SessionId`
3. **Check response body** - should NOT contain `txtId2` or `txtPwd2`
4. **Verify session persistence** - same cookies must be sent in subsequent requests
