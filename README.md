## UTOPIA — Student Productivity & life Simplified

> **One app. Every academic need. Works offline.**

What is UTOPIA?
===============

UTOPIA is a student productivity app built for **college students**. It replaces every scattered academic tool — college portals, attendance trackers, note-sharing groups, class schedules, community help — with a single offline-first app that just works.

Built by a first-year mechanical engineering student with zero prior coding experience, using Flutter and a fully free infrastructure stack. 

**Website:** [Inferalis.space](https://inferalis.space)

---

## Features

### 📚 Library — Notes & Files
- **Community noets** → Allows users to share notes and files with global write access
- Markdown notes rendered natively with support for LaTeX math (`flutter_math_fork`), embedded images, and etc. md features.
- File attachments (PDFs, slides) shown as tappable bars at the top of each note — downloaded from Google Drive on first tap, cached forever for offline use
- Full-text search across all cached markdown content via SQLite
- Auto-sync with database on app open — silent, no background drain
- Note segment sharing — tap any heading, paragraph, or code block to share it directly as a chat message
- Image pre-fetching — all images referenced in a note are resolved and cached locally for offline access
- Hidden folders — writers can hide/show folders from the reader view via the developer panel

### 🤖 Luna — Intelligent Academic Assistant (IAA)
- AI-powered academic assistant living inside UTOPIA
- Multi-provider architecture — configurable via Firestore with automatic failover across providers, API keys, and models (Groq Llama 3.3 70B, Llama 3.1 8B, Gemini, and any OpenAI-compatible endpoint)
- Context-aware — builds a system prompt from the student's real-time timetable, attendance data, available notes, and relevant note excerpts
- Attendance-aware — gives definitive YES/NO answers to "can I skip class?" based on the 75% attendance threshold per subject
- Conversation history — maintains the last 20 messages for multi-turn context
- Clean markdown responses — uses headings, bullets, tables, and fenced code blocks for structured answers
- Offline detection — shows clear error states when connectivity is lost

### 📊 Attendance
- Directly fetches data from `info.aec.edu.in` — the official college portal
- AES-128-CBC password encryption (matches the portal's own client-side encryption)
- Credentials stored securely on-device using `flutter_secure_storage` — never sent to any server other than the college portal
- Subject-wise breakdown with progress bars, colour-coded by percentage
- Overall attendance summary with total classes held and attended
- HTML response parsing with robust regex-based extraction

### 💬 Chat & Friends
- Real-time 1-on-1 messaging between all UTOPIA users via Firestore
- Custom kawaii emoji system — 120+ illustrated emojis across 7 categories (Smileys, People, Animals, Food, Travel, Objects, Symbols), rendered as inline image spans
- Typing indicators and online/offline presence tracking (`lastSeen` within 5 minutes = online)
- Message actions — reply, edit, unsend (soft delete)
- Note sharing — share any note segment directly into a chat conversation
- Unread message badges on the bottom navigation bar
- Chat notifications via GitHub Actions workflow dispatch → FCM push
- Sorted friend list — most recently messaged users appear first

### 🗺️ Campus Map
- Google Maps locked to Aditya University campus bounds
- Real-time friend location sharing (8AM–10PM IST only) via Firebase Realtime Database
- All UTOPIA users visible to each other on the map
- Catppuccin-themed dark map style
- Per-user location sharing toggle
- Auto-refresh location markers

### 🧩 SciWordle — Daily Science Word Game
- Daily science-themed Wordle game with variable word length
- New question generated daily from Firestore (`sciwordle_daily` collection)
- Scoring system — word score (based on attempt number) + streak bonus (2 points for playing consecutive days)
- Streak tracking — playing every day builds a streak; missing a day resets it
- In-progress persistence — guesses saved to Firestore so closing the app mid-game doesn't reset progress
- Anti-cheat — once played today, the result is locked and cannot be replayed
- Leaderboard — ranked by total score, with tiebreaking by timestamp (earliest scorer wins)
- Game statistics screen with personal performance history
- Confetti animation on win 🎉

### 🏆 Gamification & Champion System
- Real-time champion badges for top SciWordle players
- **Legend** badge — #1 by total score across all time
- **GOAT** badge — #1 by current active streak
- Top 3 score and streak ranks displayed with special avatar decorations and name colours in the friends list
- Live-updating via Firestore snapshots

### 🔔 Morning Notifications
- Every morning at 5:00 AM IST, all students receive the day's schedule automatically
- Luna-style format: Morning Schedule, Afternoon Schedule, Must Carry items, Quote of the Day
- Fully automated via GitHub Actions — zero daily maintenance needed
- Holiday detection with custom holiday messages
- Quotes pool — random motivational quote selected each morning

### 📅 Timetable
- View the full weekly class schedule with day tabs
- Schedule data stored as JSON in the content repository
- Writers can edit the timetable directly from the app via a friendly UI — no JSON editing

### 🔍 Search
- Global search across all cached notes via SQLite full-text queries
- Results show note title, subject folder, and a context preview snippet around the match
- Searches both note titles and full content

### 🛠️ Developer Mode (for class reps / writers)
- Role-based access — only users with `role: writer` in Firestore can access
- Send morning notification manually at any time
- Edit timetable with a visual editor — saves directly to GitHub via API
- Edit quotes pool
- Holiday toggle for tomorrow
- Writer broadcast — send urgent message to all students instantly via GitHub Actions → FCM
- Hide/unhide library folders
- Test notification sender

### 🔔 Notification System
- Bell icon with unread badge in AppBar
- Full notification history with mark-all-read
- Tap any notification → in-app popup dialog
- Persistent notifications in system tray via `flutter_local_notifications`
- Background notification handling — messages queued while app is closed are shown on next launch
- Chat notification routing — tapping a chat notification opens the correct conversation
- Notification deduplication via `messageId` tracking in Firestore

### ⬆️ In-App Updates
- Checks for new versions via Firestore `config/app_update`
- Supports optional and forced updates (minimum version enforcement)
- Downloads APK directly from configured URL with progress indicator
- Installs via Android's native package installer (via platform channel)
- Semantic version comparison for accurate update detection

---

## Tech Stack

| Layer | Technology |
|---|---|
| App framework | Flutter 3.41.5 (Dart 3.11.3) |
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore + Firebase Realtime Database |
| Local cache | SQLite (`sqflite`) + file system (`path_provider`) |
| Push notifications | Firebase Cloud Messaging (FCM) + `flutter_local_notifications` |
| Content storage | GitHub (`utopia-content` repo) |
| File storage | Google Drive (shared folder) |
| Automation | GitHub Actions (morning notifications, broadcasts, chat notifications) |
| AI providers | Groq (Llama 3.3 70B / 3.1 8B), Gemini, any OpenAI-compatible API |
| Maps | Google Maps SDK for Android |
| Attendance | Direct scraping of `info.aec.edu.in` (AES-128-CBC) |
| Markdown rendering | `flutter_markdown` + `markdown` + `flutter_math_fork` (LaTeX) |
| Security | `flutter_secure_storage` (credentials), `encrypt` (AES) |
| Design system | Material 3 + Catppuccin Mocha |
| Typography | Google Fonts (Outfit) |

**Monthly cost: ₹0** — entire stack runs on free tiers.

---

## Architecture

### Service Layer

All business logic lives in `lib/services/` — screens never touch Firebase or HTTP directly.

| Service | Responsibility |
|---|---|
| `AIService` | Multi-provider AI chat (OpenAI-compatible), failover, history |
| `AttendanceService` | Portal scraping, AES encryption, HTML parsing |
| `GitHubService` | Content sync, folder/file listing, note caching, image resolution |
| `WriterGitHubService` | Write-back to GitHub (timetable, quotes, hidden folders) |
| `CacheService` | SQLite database for folders, files, note content, image refs, settings |
| `FileCacheService` | Binary file downloads and local caching (images, attachments) |
| `ChatService` | Real-time messaging, typing state, unread counts, note sharing |
| `ChatEmojiCatalog` | 120+ custom kawaii emoji definitions with inline rendering |
| `NotificationService` | FCM, local notifications, background handling, dialog queue |
| `BroadcastService` | Writer broadcast via GitHub Actions workflow dispatch |
| `SciwordleService` | Daily game state, scoring, streaks, leaderboard, progress persistence |
| `GameChampionService` | Real-time top-3 rankings for score and streak |
| `RoleService` | Writer role checking with caching |
| `LocationService` | GPS location for campus map |
| `AppUpdateService` | Version checking, APK download, native install |
| `SecureStorageService` | Encrypted credential storage |
| `SearchService` | Full-text search across cached notes |
| `PlatformSupport` | Platform capability detection (Firebase, Maps, Notifications) |

### Screen Layer

| Screen | Description |
|---|---|
| `HomeScreen` | Library browser — folders, files, sync |
| `NoteViewerScreen` | Full markdown rendering with images, math, segment sharing |
| `AttendanceScreen` | Login, subject breakdown, progress bars |
| `UniversityScreen` | Tab container — Friends, Community, Events, Everyone |
| `FriendsScreen` | User list with presence, streaks, champion badges |
| `ChatScreen` | 1-on-1 messaging with emoji picker, replies, note shares |
| `IaaScreen` | Luna AI assistant chat interface |
| `MapScreen` | Campus map with live location sharing |
| `SciwordleScreen` | Daily word game UI |
| `SciwordleLeaderboard` | Score rankings with champion badges |
| `SciwordleStatsScreen` | Personal game statistics |
| `ProfileScreen` | User settings, theme, about, developer mode access |
| `DeveloperPanelScreen` | Writer tools hub |
| `TimetableScreen` | Weekly schedule viewer |
| `TimetableEditorScreen` | Visual timetable editor for writers |
| `EditorScreen` | Note editor for writers |
| `QuotesEditorScreen` | Quote pool manager for writers |
| `BroadcastScreen` | Urgent message sender for writers |
| `NotificationHistoryScreen` | All received notifications |
| `SearchScreen` | Global note search |
| `HowToPlayScreen` | SciWordle instructions |

### Navigation

```
AppShell (BottomNavigationBar)
├── Library (HomeScreen)
├── Attendance (AttendanceScreen)
├── University (UniversityScreen → FriendsScreen, etc.)
└── Profile (ProfileScreen)
```

Secondary screens are pushed via `Navigator.push`:
- Note Viewer, IAA, Chat, Map, SciWordle, Developer Panel, Search, etc.

---

## Design System

UTOPIA uses the **Catppuccin Mocha** colour palette with Material 3 components and **Outfit** as the primary typeface.

| Token | Colour | Hex |
|---|---|---|
| Background | Base | `#1E1E2E` |
| Surface | Surface0 | `#313244` |
| Primary | Mauve | `#CBA6F7` |
| Text | Text | `#CDD6F4` |
| Subtext | Subtext0 | `#A6ADC8` |
| Accent | Teal | `#94E2D5` |
| Green | Green | `#A6E3A1` |
| Yellow | Yellow | `#F9E2AF` |
| Error / Red | Red | `#F38BA8` |
| Border | Surface1 | `#45475A` |

The theme system (`AppTheme`) supports multiple named palettes with a flexible token-based structure, making it easy to add new themes.

---

## Content Architecture

```
utopia-content/              ← Separate GitHub repo for all content
├── timetable.json           ← Weekly class schedule (editable via app)
├── quotes.json              ← Morning quote pool (editable via app)
├── morning_notif.json       ← Holiday override flag
├── .utopia-hidden           ← JSON list of hidden folder paths
├── Thermodynamics/
│   ├── 01-Introduction.md
│   └── 02-First-Law.md
├── BEEE/
├── Mathematics/
├── Chemistry/
├── C Programming/
└── .github/
    └── workflows/
        ├── morning_notification.yml   ← Fires at 5AM IST daily
        ├── broadcast.yml              ← Triggered by app for urgent messages
        └── chat-notification.yml      ← Triggered on new chat messages
```

Notes are written in Markdown with support for:
- Standard Markdown syntax
- LaTeX math blocks (fenced and inline)
- Obsidian-style image embeds (`![[image.png]]`)
- Standard image syntax (`![alt](path)`)
- Relative and absolute image paths (fuzzy-resolved against the repo tree)

---

## Key Decisions

- **No background sync** — app syncs only when opened. Battery saver.
- **No Play Store yet** — APK distributed via GitHub Releases + in-app update system. Play Store later (₹1,750 one-time).
- **No backend** — GitHub Actions replaces a server for all automation.
- **Offline first** — all content cached locally in SQLite after first sync. Notes, folders, and images all survive airplane mode.
- **Multi-provider AI** — IAA cascades through configured providers/keys/models, so a rate-limited key automatically fails over to the next.
- **Custom emoji** — instead of using system emojis, UTOPIA ships 120+ kawaii-style illustrated emojis as bundled assets for a unique chat personality.
- **File bars at top** — file attachments always appear above markdown text. Non-negotiable.
- **Single codebase** — Android and Windows share identical Flutter code (Windows has limited platform support for Firebase, Maps, and Notifications).
- **Free only** — every integration uses a free tier that covers 60 users.
- **Anti-cheat** — SciWordle progress is persisted to Firestore immediately, preventing replay or backing out of guesses.

---

## Platform Support

| Feature | Android | Windows |
|---|---|---|
| Library / Notes | ✅ | ✅ |
| Attendance | ✅ | ✅ |
| Luna (IAA) | ✅ | ✅ |
| SciWordle | ✅ | ✅ |
| Chat | ✅ | ⚠️ No push notifications |
| Campus Map | ✅ | ❌ |
| Push Notifications | ✅ | ❌ |
| Google Sign-In | ✅ | ❌ |
| In-App Updates | ✅ | ❌ |

Windows builds work for core features (notes, attendance, AI, game) but lack Firebase Auth on desktop, push notifications, and Google Maps.

---

## Target Users

- **~60 students** — readers (browse notes, get notifications, check attendance, chat, play SciWordle)
- **2–5 class reps** — writers (edit notes, manage timetable, send broadcasts)
- **Campus:** Aditya University, Visakhapatnam (Mechanical Engineering, Batch 2025)

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.3`
- Android SDK (for Android builds)
- Firebase project with Auth, Firestore, Realtime Database, and Cloud Messaging configured
- Google Maps API key (for campus map)

### Setup
```bash
git clone https://github.com/infernoGurala/utopia-app.git
cd utopia-app
flutter pub get
flutter run
```

### Firebase Configuration
Place your `google-services.json` (Android) and/or `firebase_options.dart` in the appropriate locations. The app expects the following Firestore collections:
- `config/github` — GitHub PAT and workflow settings
- `config/iaa` — AI provider configuration (endpoints, API keys, models)
- `config/grok` — Legacy Groq provider config
- `config/gemini` — Legacy Gemini provider config
- `config/app_update` — Update version info and APK URL
- `users` — User profiles and presence
- `chats` — Chat rooms and messages
- `notifications` — Push notification history
- `sciwordle_daily` — Daily game questions
- `sciwordle_scores` — Player scores and streaks
- `sciwordle_progress` — In-progress game state

---

## Author

**John Moses Gurala**
First-year Mechanical Engineering student, Aditya University
[johnmosesg160@gmail.com](mailto:johnmosesg160@gmail.com)
GitHub: [infernoGurala](https://github.com/infernoGurala)

---

*UTOPIA v2.2.4 — utopia.inferalis.space · Built with Flutter · April 2026*
