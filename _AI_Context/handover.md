# UTOPIA v3 — AI Handover Document
> For the next AI continuing this implementation session.
> Read this + the spec files the user shares alongside this document.
> Current date: April 2026 | App version: v2.2.4 → building v3.0

---

## What is UTOPIA?

A Flutter student productivity app for college students. Built by John Moses Gurala (first-year ME student, Aditya University, Vizag). Zero prior coding experience — designed by him, coded with AI assistance.

- **Stack:** Flutter + Firebase Auth + Firestore + SQLite (CacheService) + GitHub as content backend
- **Design:** Material 3 + Catppuccin Mocha + Outfit font (`GoogleFonts.outfit()`)
- **Color tokens:** `U.bg`, `U.surface`, `U.text`, `U.subtext`, `U.accent` — do NOT use `U.base`, `U.surface0`, etc. The correct token for background is `U.bg`.
- **Rules:** `StatefulWidget` + `setState` ONLY. No Riverpod. No GoRouter. No new pubspec dependencies unless explicitly discussed.
- **App shell:** `AppShell` in `lib/screens/app_shell.dart` — `BottomNavigationBar` with 4 tabs: Library (index 0), Attendance (index 1), University (index 2), Profile (index 3)

---

## Firestore Structure

```
config/github          ← OLD repo config (utopia-content) — DO NOT TOUCH
config/github-global   ← NEW repo config fields: repo, branch, pat
                          repo = "theutopiadomain/utopia-global"
                          branch = "main"
universities/{universityId}   ← fields: id, name, shortName
classes/{classId}             ← fields: classId, classCode, name, universityId, creatorUid, writerUids, createdAt, memberCount
users/{uid}                   ← fields: displayName, email, photoUrl, lastSeen, themeAccent, iaaEnabled, role, fcmToken, fcmTokens, tokenUpdatedAt, selectedUniversityId
users/{uid}/memberships/{classId}  ← fields: classId, universityId, joinedAt, role ("reader" or "writer")
```

**Firestore Security Rules** — these have been added and are working:
```
match /universities/{universityId} { allow read, write: if isSignedIn(); }
match /classes/{classId} { allow read, write: if isSignedIn(); }
match /users/{uid}/memberships/{classId} { allow read, write: if isOwner(uid); }
```

---

## GitHub Repo Structure (utopia-global)

```
utopia-global/
├── README.md
├── aditya-university/
│   └── {classId}/
│       └── Notes/
│           └── .keep      ← auto-created on class creation
```

- University folder name = slugified university name (lowercase, spaces → hyphens)
  e.g. "Aditya University" → `aditya-university`
- classId = full UUID (e.g. `f62d8dab-ce1e-498f-8303-36addb959584`)
- GitHub Contents API: `GET https://api.github.com/repos/{repo}/contents/{path}?ref={branch}`
  with header `Authorization: token {pat}`

---

## Services Created in v3

### `UniversityService` (`lib/services/university_service.dart`)
- `fetchAllUniversities()` — hits `http://universities.hipolabs.com/search?country=India`, parses JSON, returns sorted list of `UniversityModel`
- `getUserSelectedUniversity(uid)` — reads `users/{uid}.selectedUniversityId`
- `setUserSelectedUniversity(uid, universityId)` — writes to `users/{uid}`

### `ClassService` (`lib/services/class_service.dart`)
- `getClassesForUser(uid)` — reads memberships, fetches each class doc
- `createClass(name, universityId, creatorUid)` — generates UUID classId + 6-char alphanumeric classCode, writes to Firestore
- `joinClassByCode(code, uid)` — queries classes where classCode == code, writes membership

### `GitHubGlobalService` (`lib/services/github_global_service.dart`)
- `ensureUniversityFolderExists(universityName)` — creates `{universityName}/.keep` if not exists
- `ensureClassFolderExists(universityName, classId)` — creates `{universityName}/{classId}/Notes/.keep` if not exists
- Reads config from `config/github-global`
- All errors caught silently — never throws, never blocks UI

---

## Screens Created in v3

### `UniversitySelectionScreen` (`lib/screens/university_selection_screen.dart`)
- Shown on first login (no `selectedUniversityId`) or from Profile → Change University
- Search bar + scrollable list from Hipolabs API
- On select: writes `selectedUniversityId` to Firestore, navigates to app shell

### `LibraryHomeScreen` (`lib/screens/library_home_screen.dart`)
- Replaces old `HomeScreen` at index 0 in `AppShell`
- Shows "library." header + university short name subheader
- 2-column grid: University Notes (pinned top-left) → user's classes → Create a Class → Join a class
- Create bottom sheet → calls `ClassService.createClass()`
- Join bottom sheet → calls `ClassService.joinClassByCode()`
- On load: calls `GitHubGlobalService.ensureUniversityFolderExists()` silently via `unawaited()`

### `ClassDetailScreen` (`lib/screens/class_detail_screen.dart`)
- Constructor: `ClassDetailScreen({ required ClassModel classModel, required String universityFolderName })`
- Currently: shows class name in AppBar + class code display with copy button
- **Stage 3 will replace the body** with the notes file browser

### `ClassModel` / `ClassMembershipModel` / `UniversityModel`
- Dart model classes with `toMap()` / `fromMap()` — exist from Stage 1

---

## Implementation Status

### ✅ DONE — Stage 1: Data Models + University Selection
- `UniversityModel`, `ClassModel`, `ClassMembershipModel` Dart classes
- `UniversityService`, `ClassService`
- `UniversitySelectionScreen` with Hipolabs API + search
- Android manifest: `android:usesCleartextTraffic="true"` added (needed for HTTP to Hipolabs)
- Login flow: new user → university selection → app; existing user → straight to app

### ✅ DONE — Stage 2: Library Home Screen + Create/Join Class
- `LibraryHomeScreen` with 2-column grid (Catppuccin Mocha themed)
- `GitHubGlobalService` for background GitHub folder init
- Create a Class bottom sheet — working, Firestore write confirmed
- Join a Class bottom sheet — working, tested with 6-char code
- `ClassDetailScreen` placeholder with class code display + copy button
- AppShell updated: index 0 now shows `LibraryHomeScreen` (old `HomeScreen` import retained but not rendered)
- Firestore security rules updated for `classes/` and `users/{uid}/memberships/`
- GitHub repo structure confirmed: `aditya-university/{classId}/Notes/.keep` auto-created ✅

### 🔲 NEXT — Stage 3: Notes File Browser
The body of `ClassDetailScreen` needs to be replaced with a file browser.

**Spec for Stage 3:**
- Fetch `{universityFolderName}/{classId}/Notes/` from GitHub Contents API
- Show folders (navigate deeper) and `.md` files (open viewer)
- Hide `.keep` files from UI
- Empty state: "No notes yet."
- `NoteViewerScreen`: fetches raw markdown from `download_url`, renders with `flutter_markdown` (already in pubspec)
- AppBar title = file name without `.md` extension
- `universityFolderName` passed from `LibraryHomeScreen` (it equals `selectedUniversityId`, e.g. `aditya-university`)

**Prompt to give coder for Stage 3:**

```
You are continuing the UTOPIA Flutter app. Stage 2 is complete. This is Stage 3 — the notes file browser inside a class.

Context:
- GitHub repo: read from Firestore config/github-global (fields: repo, branch, pat)
- Base path for any class: {universityFolderName}/{classId}/Notes/
- universityFolderName is the slugified university name (e.g. aditya-university)
- classId is a full UUID
- GitHub Contents API: GET https://api.github.com/repos/{repo}/contents/{path}?ref={branch}
- Response is a JSON array. Each item has: name (String), type ("file" or "dir"), path (String), download_url (String or null)
- Hide any item where name == '.keep'
- Material 3 + Catppuccin Mocha + GoogleFonts.outfit() + U.bg, U.surface, U.text, U.subtext color tokens
- StatefulWidget + setState only — no Riverpod
- No new pubspec dependencies

What to implement:

1. Replace ClassDetailScreen body with a file browser that:
- On load, fetches contents of {universityFolderName}/{classId}/Notes/ from GitHub
- Shows loading spinner while fetching
- Folders: folder icon (Icons.folder_rounded, color U.accent), tap navigates deeper via Navigator.push with same screen at new path
- Files: document icon (Icons.article_rounded, color U.subtext), tap opens NoteViewerScreen
- Hides .keep files
- Empty state (nothing visible after hiding .keep): show "No notes yet." centered
- ListTile design: GoogleFonts.outfit(color: U.text) title, subtitle shows file size for files (e.g. "2.1 KB")
- Background: U.bg

2. NoteViewerScreen (lib/screens/note_viewer_screen.dart):
- Accepts: fileName (String), downloadUrl (String)
- HTTP GET to downloadUrl → fetch raw markdown
- Render with flutter_markdown (already in pubspec — do NOT add again)
- AppBar title: fileName without .md extension
- AppBar background: U.bg
- Loading spinner while fetching
- Error state: "Failed to load note." centered

3. universityFolderName is already passed into ClassDetailScreen constructor.
Update navigation from LibraryHomeScreen if needed.

Before writing any code, confirm:
- Is flutter_markdown present in pubspec.yaml?
- Show the current ClassDetailScreen constructor signature
- Show the Navigator.push call in LibraryHomeScreen that opens ClassDetailScreen
```

---

### 🔲 Future Stages (after Stage 3)

**Stage 4 — Community Notes / University Notes**
- University Notes card opens a shared notes space for the whole university
- Everyone has writer access (community mode)
- Deletion requires 3-person approval
- Warning screen on entry
- Auto-creates branch folders (e.g. Mechanical, Civil) on first university setup
- See `Community_notes_v3.md` for full spec

**Stage 5 — Class Settings**
- Only visible to users with writer role
- Edit writers (add/remove from class members, max 6 total)
- Share class link (classes.inferalis.space/join/{classCode})
- Delete class (danger flow with confirmation)
- Timetable editing per class
- See `class_settings.md` for full spec

**Stage 6 — Timetable v3**
- User selects a timetable from their joined classes OR creates a custom one
- Config stored in class GitHub folder: `{universityName}/{classId}/Workflows/timetable.json`
- Class notification toggle (on/off per class)
- If selected class has no timetable: warning shown
- See `Timetable_v3.md` for full spec

**Stage 7 — Attendance v3**
- Attendance tab disabled/greyed out for non-AEC university users
- Only visible and functional for `selectedUniversityId == "aditya-university"` (or AEC domain)
- See `Attandance_v3.md` for full spec

**Stage 8 — Super User / Admin**
- Super user = app-level admin (only the creator)
- Has extra university management features
- See `Super_User_v3.md` for full spec

**Stage 9 — Edit Mode (Notes Editor)**
- In-app markdown editor for writers
- See `new_Edit_mode.md` for full spec (TBD)

---

## Important Rules for the Next AI

1. **Never use `U.base`, `U.surface0`, `U.surface1`** — correct tokens are `U.bg`, `U.surface`, `U.card`
2. **Never use Riverpod, GoRouter, or add new pubspec packages** without explicit discussion
3. **Never touch `GitHubService` or `HomeScreen`** — old v2 system, kept for reference only
4. **Always give staged prompts** — one stage at a time, test before next stage
5. **Always ask a pre-implementation question** before writing code for a new stage — confirm current state of relevant files first
6. **GitHub folder creation runs silently** — always `unawaited()`, always wrapped in try/catch, never blocks UI
7. **classId = full UUID**, classCode = 6-char alphanumeric (for joining), they are different things
8. **universityFolderName = universityId** — they are the same slugified string (e.g. `aditya-university`)
9. The user is a designer, not a coder — keep explanations simple, avoid jargon dumps
10. Test checklist after every stage before proceeding: confirm Firestore writes, GitHub folder creation, and UI navigation all work on device

---

## Contact / Repo Info

- **Developer:** John Moses Gurala — johnmosesg160@gmail.com
- **App repo:** github.com/infernoGurala/utopia-app
- **Content repo (old v2):** utopia-content (DO NOT MODIFY)
- **Library repo (v3):** github.com/theutopiadomain/utopia-global
- **Website:** utopia.inferalis.space