Every university will have a community notes. 
- Community notes is just a class, but in super mode, every one has access to it.
- all the people viewing are writers.
- 
- A warning screen, while editing.
- community notes doesn't have class timetable options.

├─University A
	 ├─Class A
	 ├─Class B
	 ├─University Notes
├─University B
	 ├─Class C
	 ├─Class D
	 ├─University Notes


Default files for a university...

├─Community notes
	 ├─Civil Engineering
	 ├─Mechanical 
	 ├─etc..

But every university does't have a all the courses and same courses. but every university have same Semesters..

For example.
├─University B
	 ├─Class C
		 ├─Mechanical
			 ├─Semester-1
				 ├─Courses(list)
					 ├─(Select any course) 5 unit folders.

so, here in the root library/folder of any university will have 0 university braches/programms, so users will have to add university braches, 
once any user adds a branch of the university, the eight semester files will be automatically created, and also the example course folders(create 5 deafult) and inside the courses, must be 5 unit folders also. and inside the unit folder there will be example text. 
so, some files are auto created, some are manual.
NOTE, all the files can be renamed, and edited, including folders. this does't requires community permission, only the deletion seeks permission. 


DELETE
------------------
Deleting a notes/folder is bad. this means, a user cannot delete a folder/file eaily. (APPLIES ONLY IN COMMUNITY NOTES)
- if the user in communtiy notes deletes a file, it turns grey, any other 3 people must approve the file to be deleted. only then the file will be deleted.
- this approval is based in the same place where the file is placed. but at the very top of the folder system.

### Deletion threshold constant
The required number of approvals before execution is controlled by a single constant in code:

```dart
const int kDeletionApprovalsRequired = 3;
```

All approval checks and UI strings reference this constant. To change the threshold, update only this one value.

---

### Deletion Status State Machine

Every deletion request stored in Firestore (`community_deletions` collection) has a `status` field with the following lifecycle:

```
pending  →  executing  →  executed
                      ↘  failed
pending  →  cancelled
```

| Status       | Meaning                                                      |
|--------------|--------------------------------------------------------------|
| `pending`    | Deletion requested; awaiting approvals.                      |
| `executing`  | Threshold reached; one client is performing the GitHub delete. |
| `executed`   | GitHub delete succeeded. `isDeleted: true` is also set.      |
| `failed`     | GitHub delete threw an error. `failureReason` field is set.  |
| `cancelled`  | Requester withdrew the deletion request.                     |

**Backward compatibility:** Legacy docs without a `status` field are treated as `pending` (if `isDeleted == false`) or `executed` (if `isDeleted == true`).

**Firestore doc fields:**
- `universityId` — university folder name
- `path` — GitHub path of the target file/folder
- `name` — display name
- `type` — `"file"` or `"dir"`
- `requesterUid` — UID of the user who requested deletion
- `approvals` — list of UIDs who have approved
- `isDeleted` — legacy boolean (kept for backward compat; set to `true` on executed)
- `status` — state machine value (new docs always have this)
- `createdAt` — server timestamp
- `executedAt` — server timestamp set on successful execution
- `cancelledAt` — server timestamp set on cancellation
- `failureReason` — error string set on failure

---

### Concurrency Safety (Client-Side Transaction Lock)

To prevent two clients from both executing the GitHub delete when approvals reach the threshold simultaneously, the approval update uses a Firestore **transaction**:

1. Read the fresh doc inside the transaction.
2. If `status != "pending"`, abort — another client already claimed execution.
3. Add the approving UID to `approvals`.
4. If `approvals.length >= kDeletionApprovalsRequired`:
   - Atomically set `status = "executing"`.
   - Only the client that wins this transaction proceeds to call `_github.deleteItem(...)`.
5. On success: set `status = "executed"`, `isDeleted = true`, `executedAt`.
6. On failure: set `status = "failed"`, `failureReason`.

---

### Undo Approval

Any user who has already approved a pending deletion can **withdraw their approval**:
- Their UID is removed from the `approvals` array via a Firestore transaction.
- Can only be done while `status == "pending"`.
- This reduces the approval count (e.g. from 2/3 back to 1/3).
- UI: the trailing "Approve" button becomes an "Undo" text button once a user has approved.

---

### Cancel Deletion Request

The **requester** (the user who created the deletion request) can cancel it at any time while it is still `pending`:
- Sets `status = "cancelled"` and `cancelledAt` in a transaction.
- The item immediately disappears from the pending list (the Firestore listener ignores `cancelled` docs).
- The file/folder is restored to its normal non-grey appearance.
- UI: requester sees a ⋮ popup menu with "Cancel request" alongside their approve/undo option.
- Non-requesters cannot cancel — they can only approve or undo their own approval.

---

### Viewing Pending-Deletion Items (Read-Only)

Pending-deletion items remain **openable as read-only**:
- **Files:** tapping a greyed-out file opens `NoteViewerScreen` with `isEditable: false`. The user can read the content but cannot edit it.
- **Folders:** tapping a greyed-out folder currently does not navigate inside (folder-level pending deletion is treated as a block). Approval or cancel is available via the trailing action.
- **Executing/Failed:** tapping a file in `executing` state does nothing extra. Tapping a file in `failed` state shows the failure reason dialog.

---

### Edit Mode & Editing Policy

- **Edit Mode** is a toggle in `CommunityNotesScreen` (pencil icon in app bar). A one-time warning dialog ("This is a shared space…") is shown on first activation.
- Edits (rename, add files/folders, open file editor) are only available when Edit Mode is enabled.
- Deletion requests can be submitted only in Edit Mode (via the edit ⋮ menu).
- In `NoteViewerScreen`:
  - **Community notes** (`filePath` contains `/Community/`): edit button is shown only when `isEditable == true` (i.e., Edit Mode was on when the file was opened).
  - **Non-community notes**: edit button is shown only when the user has the global writer role (`_isWriter`).

---

### UI Summary for Pending Items

| Condition                   | Trailing widget                             | Subtitle                                      |
|-----------------------------|---------------------------------------------|-----------------------------------------------|
| `status == executing`       | Circular spinner                            | "Deletion in progress..."                     |
| `status == failed`          | Red error icon (tap → failure reason dialog)| "Deletion failed — tap for details"           |
| `status == pending`, requester | ⋮ popup: [Approve/Undo] + Cancel request | "Pending Deletion (n/3 approvals)"            |
| `status == pending`, other, not approved | "Approve" text button (red)  | "Pending Deletion (n/3 approvals)"            |
| `status == pending`, other, approved    | "Undo" text button (grey)     | "Pending Deletion (n/3 approvals)"            |

---

MIS-USE WARNING
-----------------------------------------
- any time user entering the community notes, must be warned to not misuse the community notes. or do silly activities like deleting the useful files worked by others.