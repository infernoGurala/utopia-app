Concept
==========
Every university has a shared **Community Notes** space.
- Acts like a class where **everyone is a writer**.
- No timetable options.

Folder Structure
===================
University A  
├── Class A  
├── Class B  
└── Community Notes  
├── Civil Engineering  
│ └── Semester-1  
│ └── Course Name  
│ └── Unit-1 ... Unit-5  
├── Mechanical  
└── etc.



## Auto-Generation Logic
- Root library initially empty of programs.
- User adds a branch (e.g., "Mechanical").
- System auto-creates: 8 semester folders → Example courses (5 default) → Each course has 5 unit folders with example text.
- All folders/files can be renamed/edited without permission.

## Deletion Workflow (3-Person Approval)
- **Threshold:** `kDeletionApprovalsRequired = 3` (single constant to change).
- **State Machine:** `pending` → `executing` → `executed` / `failed` / `cancelled`.
- **Firestore Collection:** `community_deletions`
  - Fields: `universityId`, `path`, `name`, `type`, `requesterUid`, `approvals[]`, `status`, `isDeleted`, timestamps.
- **Concurrency:** Firestore transaction ensures only one client executes GitHub delete.
- **Undo:** Approver can withdraw approval while pending.
- **Cancel:** Requester can cancel while pending.
- **UI Behavior:**
  - Pending items greyed out, show progress (n/3).
  - Folders remain navigable; files open read-only.
  - Edit Mode toggle required for any modification.
- **Misuse Warning:** Shown on every entry to Community Notes.

## Edit Mode Policy
- Pencil icon toggles Edit Mode in AppBar.
- First activation shows warning dialog.
- Edits (rename, add, delete request) only available when Edit Mode is ON.
- In `NoteViewerScreen`, edit button shown only if opened from Community Notes with Edit Mode enabled.