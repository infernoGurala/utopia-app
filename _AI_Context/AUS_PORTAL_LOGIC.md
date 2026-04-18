# AUS Attendance Portal - Technical Documentation

## Overview

The AUS Attendance Portal is hosted at `info.aec.edu.in` under the `/aus` prefix. This document describes the complete flow for authenticating and fetching attendance data from the AUS portal.

## Portal Configuration

```dart
static const String _portalHost = 'info.aec.edu.in';
static const String _prefix = '/aus';
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
- Path: `/aus/default.aspx`
- Purpose: Retrieve ASP.NET ViewState tokens required for login

**Response Parsing:**
The login page contains hidden ASP.NET form fields that must be extracted and included in the login POST request:

1. `__VIEWSTATE` - Main view state token
2. `__VIEWSTATEGENERATOR` - View state generator token
3. `__EVENTVALIDATION` - Event validation token

These are extracted using regex patterns that match both `id=` and `name=` attributes with either `"` or `'` quotes.

### Step 2: Password Encryption

The password must be encrypted using AES-128-CBC with PKCS7 padding before sending:

```dart
Key: UTF-8 bytes of '8701661282118308'
IV: UTF-8 bytes of '8701661282118308'
Output: Base64 encoded
```

### Step 3: Submit Login Form

**Request:**
- Method: `POST`
- Path: `/aus/default.aspx`
- Content-Type: `application/x-www-form-urlencoded`
- Body: Form-encoded with tokens + credentials
- Headers: `origin` and `referer` pointing to login page

**Form Fields:**
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

### Step 4: Validate Login Success

AUS uses a **redirect-based** authentication pattern:

**Success Criteria:**
1. Response status code must be 302 (or 301/307 redirect)
2. `Location` header must contain `studentmaster.aspx`
3. Server must set `ASP.NET_SessionId` cookie
4. Server must set `frmAuth` cookie

**Cookies Set on Success:**
- `ASP.NET_SessionId` - Session identifier
- `frmAuth` - Authentication token (AUS-specific)

**Failure Detection:**
If any of the above conditions fail, the server typically returns the login page again with an error message embedded in the HTML.

## Attendance Fetching Flow

After successful authentication:

### Step 1: Access Student Master

**Request:**
- Method: `GET`
- Path: `/aus/StudentMaster.aspx`
- Cookies: Include `ASP.NET_SessionId` and `frmAuth`
- Purpose: Establish session on the student master page

### Step 2: Load Attendance Page

**Request:**
- Method: `GET`
- Path: `/aus/Academics/studentattendance.aspx?scrid=3&showtype=SA`
- Cookies: Session cookies
- Purpose: Load the attendance page and extract web method token

**Web Method Token Extraction:**
The attendance page contains JavaScript with a token variable:
```javascript
var _tkn = '<token_value>';
```
This token is extracted via regex and used in subsequent AJAX requests.

### Step 3: Load AJAX Methods Script

**Request:**
- Method: `GET`
- Path: `/aus/JSFiles/AjaxMethods.js`
- Cookies: Session cookies
- Purpose: Ensure all required JavaScript functions are loaded

### Step 4: Fetch Attendance Data

**Request:**
- Method: `POST`
- Path: `/aus/Academics/studentattendance.aspx/ShowAttendance`
- Content-Type: `application/json; charset=UTF-8`
- Headers:
  - `origin`: `https://info.aec.edu.in`
  - `referer`: Attendance page URL
  - `x-requested-with`: `XMLHttpRequest`
  - `x-auth-token`: Web method token (if available)
  - `accept`: `application/json, text/javascript, */*; q=0.01`

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

The HTML response is parsed to extract attendance data:

1. Look for `<table id="tblReport">` - preferred table for parsing
2. If not found, parse the main content
3. Extract subject-wise data from table rows
4. Calculate totals and percentages

### Parsing Logic

1. **Header Detection:** Find `<th>` elements to determine column indices
   - Subject name column
   - Classes held column
   - Classes attended column
   - Percentage column

2. **Data Row Processing:** For each `<tr>` with data:
   - Extract cell values
   - Parse integers for classes held/attended
   - Parse percentage
   - If percentage missing, calculate from held/attended

3. **Special Rows:**
   - Skip header-like rows (containing "subject", "sr", "sl")
   - Capture "Total" row for report-based totals

## Error Handling

| Error Type | Detection | Message |
|------------|----------|---------|
| Invalid credentials | Missing cookies OR response is login page | "Invalid credentials" |
| No attendance data | Empty subjects list AND no report | "Attendance data was not found" |
| Network error | HTTP status != 200 | "Could not fetch attendance right now" |
| General error | Any other exception | "Unable to load attendance right now" |

## Security Considerations

- Password is encrypted client-side before transmission
- Session cookies are required for all authenticated requests
- `frmAuth` cookie is AUS-specific and validated server-side
- Origin and Referer headers prevent CSRF attacks
- All communication is over HTTPS

## Constants

```dart
static const String _portalHost = 'info.aec.edu.in';
static const String _aesSecret = '8701661282118308';
static const Duration _timeout = Duration(seconds: 20);
static const String _userAgent = 'Mozilla/5.0 (Linux; Android 14; ...)';
```
