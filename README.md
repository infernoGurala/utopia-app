# UTOPIA — The Student Productivity Platform

> **One app. Every academic need. Works offline.**

![Flutter](https://img.shields.io/badge/Flutter-3.41.5-02569B?style=flat-square&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.11.3-0175C2?style=flat-square&logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?style=flat-square&logo=firebase)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-brightgreen?style=flat-square)
![License](https://img.shields.io/badge/License-Private-red?style=flat-square)

---

## What is UTOPIA?

UTOPIA is a cross-platform student productivity app built for **college students**. It replaces every scattered academic tool — college portals, attendance trackers, note-sharing groups — with a single offline-first app that just works.

Built by a first-year mechanical engineering student with zero prior coding experience, using Flutter and a fully free infrastructure stack.

**Website:** [utopia.inferalis.space](https://utopia.inferalis.space)

---

## Features

### Notes & Files
- Browse subjects → units → topics in a clean folder structure
- Markdown notes rendered natively, mirroring the Obsidian vault structure
- File attachments (PDFs, slides) shown as tappable bars at the top of each note
- Files downloaded from Google Drive on first tap, cached forever for offline use
- Full-text search across all markdown content
- Auto-sync with GitHub on app open — silent, no background drain

### Morning Notifications
- Every morning at 5:00 AM IST, all students receive the day's schedule automatically
- Luna-style format: Morning Schedule, Afternoon Schedule, Must Carry items, Quote of the Day
- Fully automated via GitHub Actions — zero daily maintenance needed
- Holiday detection with custom holiday messages
- Quotes pool — random motivational quote selected each morning

### Attendance
- Directly fetches data from `info.aec.edu.in` — the official college portal
- AES-128-CBC password encryption (matches the portal's own client-side encryption)
- Credentials stored securely on-device using flutter_secure_storage — never sent to any server other than the college portal
- Subject-wise breakdown with progress bars, colour-coded by percentage
- Overall attendance summary

### Campus Map
- Google Maps locked to Aditya University campus bounds
- Real-time friend location sharing (8AM–10PM IST only)
- All UTOPIA users visible to each other
- Catppuccin dark map theme
- Location sharing toggle per user

### Developer Mode (for class reps / writers)
- Send morning notification manually at any time
- Edit timetable with a friendly UI — no JSON editing
- Edit quotes pool
- Holiday toggle for tomorrow
- Writer broadcast — send urgent message to all students instantly
- Timetable editor saves directly to GitHub via API

### Notification System
- Bell icon with unread badge in AppBar
- Full notification history with mark-all-read
- Tap any notification → in-app popup dialog
- Persistent notifications in system tray

---

## Tech Stack

| Layer | Technology |
|---|---|
| App framework | Flutter 3.41.5 (Dart 3.11.3) |
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore + Firebase Realtime Database |
| Push notifications | Firebase Cloud Messaging (FCM) |
| Content storage | GitHub (`utopia-content` repo) |
| File storage | Google Drive (shared folder) |
| Automation | GitHub Actions (morning notification, broadcasts) |
| Maps | Google Maps SDK for Android |
| Attendance | Direct scraping of `info.aec.edu.in` |
| Design system | Material 3 + Catppuccin Mocha |

**Monthly cost: ₹0** — entire stack runs on free tiers.

---

## Design System

UTOPIA uses the **Catppuccin Mocha** colour palette with Material 3 components.

| Token | Colour | Hex |
|---|---|---|
| Background | Base | `#1E1E2E` |
| Surface | Surface0 | `#313244` |
| Primary | Mauve | `#CBA6F7` |
| Text | Text | `#CDD6F4` |
| Accent | Teal | `#94E2D5` |
| Error | Red | `#F38BA8` |

Dark theme primary. Typography follows the Material 3 type scale.

---

## Repository Structure

```
utopia-content/         ← Separate GitHub repo for all content
├── timetable.json      ← Weekly class schedule (editable via app)
├── quotes.json         ← Morning quote pool (editable via app)
├── morning_notif.json  ← Holiday override flag
├── Thermodynamics/
│   ├── 01 Introduction.md
│   └── 02 First Law.md
├── BEEE/
├── Mathematics/
├── Chemistry/
├── C Programming/
└── .github/
    └── workflows/
        ├── morning_notification.yml   ← Fires at 5AM IST daily
        └── broadcast.yml              ← Triggered by app for urgent messages
```



## Key Decisions

- **No background sync** — app syncs only when opened. Battery saver.
- **No Play Store yet** — APK distributed via GitHub Releases. Play Store later (₹1,750 one-time).
- **No backend** — GitHub Actions replaces a server for all automation.
- **Offline first** — all content cached locally after first sync.
- **File bars at top** — file attachments always appear above markdown text. Non-negotiable.
- **Single codebase** — Android and Windows share identical Flutter code.
- **Free only** — every integration uses a free tier that covers 60 users.

---

## Target Users

- **~60 students** — readers (browse notes, get notifications, check attendance)
- **2–5 class reps** — writers (edit notes, manage timetable, send broadcasts)
- **Campus:** Aditya University, Visakhapatnam (Mechanical Engineering, Batch 2025)

---

## Author

**John Moses Gurala**
First-year Mechanical Engineering student, Aditya University
[johnmosesg160@gmail.com](mailto:johnmosesg160@gmail.com)
GitHub: infernoGurala

---

*UTOPIA — utopia.inferalis.space · Built with Flutter · March 2026*
