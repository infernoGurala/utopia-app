# UTOPIA v3 — AI Handover Document

**Date:** April 2026 | **Version:** v2.2.4 → v3.0

## Tech Stack & Rules
- Flutter + Firebase Auth + Firestore + SQLite (CacheService) + GitHub API.
- Design: Material 3 + Catppuccin Mocha + `GoogleFonts.outfit()`.
- Color tokens: `U.bg`, `U.surface`, `U.text`, `U.subtext`, `U.accent`. **DO NOT USE** `U.base` or `U.surface0`.
- State management: `StatefulWidget` + `setState` **ONLY**. No Riverpod. No GoRouter.
- **Do not add new pubspec packages** without discussion.
- App shell: `BottomNavigationBar` with Library (0), Attendance (1), University (2), Profile (3).

## Firestore Structure (Summary)
- `config/github` — LEGACY, DO NOT TOUCH.
- `config/github-global` — `repo: theutopiadomain/utopia-global`, `branch: main`.
- `universities/{id}`, `classes/{id}`, `users/{uid}`, `users/{uid}/memberships/{classId}`.

## GitHub Repo Structure (`utopia-global`)
utopia-global/  
└── aditya-university/  
└── {classId}/  
└── Notes/  
└── .keep

- University folder name = slugified name (e.g., `aditya-university`).
- `classId` = full UUID.

## Services Created
- `UniversityService`: fetch from Hipolabs API, manage selection.
- `ClassService`: create/join classes, fetch memberships.
- `GitHubGlobalService`: silently ensure folders exist (never blocks UI, uses `unawaited()`).

## Screens Created
- `UniversitySelectionScreen`: first login flow.
- `LibraryHomeScreen`: 2-col grid, create/join class sheets.
- `ClassDetailScreen`: placeholder with class code.

## Implementation Stages
| Stage | Status | Description |
|-------|--------|-------------|
| 1 | ✅ Done | Data models + University selection |
| 2 | ✅ Done | Library home + Create/Join class |
| 3 | ✅ Done | Notes file browser + `NoteViewerScreen` |
| 4 | ✅ Done | Community Notes (3-person deletion, edit mode) |
| 5 | 🔲 Next | Class Settings |
| 6 | 🔲 Future | Timetable v3 |
| 7 | 🔲 Future | Attendance v3 |
| 8 | 🔲 Future | Super User |
| 9 | 🔲 Future | Edit Mode (full editor) |

## Critical Reminders for AI
- Never touch `GitHubService` or `HomeScreen` (v2 legacy).
- GitHub folder creation is silent (`unawaited`, try/catch).
- `classId` (UUID) ≠ `classCode` (6-char join code).
- `universityFolderName` = `universityId`.
- Ask a pre-implementation question before coding a new stage.