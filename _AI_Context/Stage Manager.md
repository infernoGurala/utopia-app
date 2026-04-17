# App Development Stage Manager

## ✅ Completed Stages

### **Stage 1 — Data Models + University Selection**
- [x] `UniversityModel`, `ClassModel`, `ClassMembershipModel` dart classes
- [x] Initial `UniversityService` and `ClassService` implementation
- [x] API extraction via `hipolabs` for University Search/Selection
- [x] App flow logic matching Firebase selected parameters

### **Stage 2 — Library Home Screen + Create/Join Class**
- [x] Built the dynamic 2-column Catppuccin Mocha themed UI for `LibraryHomeScreen`
- [x] Implemented `GitHubGlobalService` for background repository initializations
- [x] Created functionality in `ClassService` generating Class joining logic + UI handling

### **Stage 3 — Notes File Browser**
- [x] Dynamic fetching from `{universityFolderName}/{classId}/Notes/` via GitHub API
- [x] Recursive folder traversal natively inside the app
- [x] Full document rendering functionality via `NoteViewerScreen`

### **Stage 4 — Community Notes** (ACTIVE)
- [x] Implemented the massive `CommunityNotesScreen` tree view 
- [x] Auto-generation block constructing the entire `Semester -> Course -> Unit` tree structure
- [x] Built a real-time `rename` / `add files + folders` REST controller logic into the UI menus.
- [x] "3-Person Deletion Approval" architecture built across Github APIs and Firebase Firestore sync!
- [x] Implemented Pull-to-Refresh with cache bypassing logic across all notes.
- [x] Recreated the premium "Utopia" sync animation in the AppBar (Playfair Display font + LinearProgressIndicator).
- [x] Fixed file/folder creation logic with better path construction and user feedback.
- [x] the loading takes for ever, the app must fetch but it is just some KB file sizes, it should be that hard loadings. 
- [x] reload is to be added in library section as well.
- [x] When the user renames a file/ edits a text, the change should be displayed instantly to the user, but in backed it needs to be updated to github. the user need not wait for the information to be processed.
- [x] the premium loading animation is not displayed in library, it must be displayed.
- [x] instead of 3 dots beside a file/folder, use a pen icon and open  a edit mode feature for that file, that include clear,clean, simple edit mode features.
- [x] Remove the warning inside the university notes and make it only when entering the edit mode features.
- [x] donot show the file size for markdown
- [x] change the university community notes of just the programs which is university notes->folders displayed to be in a similar way of the boxes in library by more cooler and easy to find the program, at most there will be 15 program folders here.
- [x] the edit mode tooggle should work for all cases, currently iy works for folders, but if i went inside a file even without edit mode turned on, it just gives me free write access, it must be changed.
- [x] Delete option: 2 approvals required (`kDeletionApprovalsRequired = 2`, configurable). Requester auto-counts as first approval. Delete-requested file/folder appears at top, greyed out. Pending folders can still be navigated; pending files viewable read-only. Progress shown (n/2) with grey LinearProgressIndicator. Undo approval and cancel request supported. Concurrency-safe via Firestore transaction lock (status: pending→executing→executed/failed/cancelled).
- [x] as already mentioned, the changes must be displaed instantly in the app, there should be no loading screen shown when modifiying the files/folders. all the loading should be background work not foreground.
- [x] sort folders--> alphabetical order.
- [x] when the user changes his university the app must restart and his library must change accordingly, now, only the university notes are working per university. classes joined/created must also change according to the university.
- [x] add a loading name in university loading, as please wait while loading the list.
- [x] university root folder inside option the remove the view programm text that is showing up on the folder..
- [x] Remove the name "View Program" inside the University Notes folder view, and rename the "university notes" to "community notes".
- [x] Add a delete option in university root folder also. Edit icon shown on each program card in edit mode; long-press on pending card shows approve/undo/cancel. Same 2-approval workflow applies.
- [ ] edit mode, the add new files/folder icon appears inside the community notes. which it should not appear.
- [x] auto add one approval, for the file/folder deletion on the account of the user who first deleted the item.
- [ ] when the file is in active state of deletion give two options, approval/unapprove by icons coloured red and green. 
- [x] in active delete mode, in case of folder in active deletion pending mode. it is not opening. the folder should be opened.
- [ ] KEYBOARD TEXT EDITOR IS BROKEN FROM THE INITIAL V1.0 THE "|" IN THE TYPING IS NOT WOKRING, INSTEAD OF SLIDING THROUGH LETTERS IT SELECTS THE TEXTS. BUG FIX NEEDED.
- [ ] ADD A CLEAR PATH ON TOP OF THE SCREEN TO INDICATE WHERE THE USER IS. AND THE PATHS MUST BE CLICKABLE AND CLEAR AND NOT VERY DISTRACTING. -- ADD FOR UNIVERSITY FOLDER AFTER MAIN ROOT FOLDER ONLY. LEAVE THE MAIN, ADD FOR REMAINIG. UNIVERSITY(MAIN)(LEAVE)-->CSE(LEAVE)-->SEM-1,SEM2,SEM3(ADD FROM HERE). THIS WILL BE THE FOLDER STRUCTURE ADD THIS WAY.
- [x] ADD ALPHABETICAL SORTING IN ROOT UNIVERISTY FOLDER ALSO. AND ENSURE IT IS SAME EVERYWHERE.
- [x] “University Notes” is renamed to “Community Notes”
- [ ] not just turn the icon grey, but make the folder in university root folder show as pending deletion.
- [ ] add a option to make the folder which are in delete mode to bring them alive again. opposite votes will bring the files to normal zone.
- [ ] 
---

## Next Up

### **Stage 5 — Class Settings (Complete)**
- [ ] Add Settings Cog to `ClassDetailScreen`
- [ ] Role check (only accessible if user is a "Writer")
- [ ] Function: Add/Remove Writers (Max 6 total)
- [ ] Function: Share Class Join link (`classes.inferalis.space/join/{classCode}`)
- [ ] Function: Timetable class-specific configuration menu
- [ ] Process: Delete Class (Heavy warning sequence, clears Firebase/Github refs)
- [ ] 

---

## 📅 Upcoming Stages

### **Stage 6 — Timetable v3**
- [ ] Custom GUI for building local timetables OR importing default classes
- [ ] Storage logic updated to map to v3 Github space `{universityName}/{classId}/Workflows/timetable.json`
- [ ] App notification configuration toggles (e.g. reminder alerts per-class setting)

### **Stage 7 — Attendance v3**
- [ ] Hard-code block preventing usage outside AEC domains. Disable/grey out completely if `selectedUniversityId != aditya-university`.
- [ ] Reconfigure background scraper hooks

### **Stage 8 — Super User / Admin**
- [ ] Super user / creator access portal logic bypassing strict permissions
- [ ] App-level university list/management views

### **Stage 9 — Edit Mode (Notes Editor)**
- [ ] In-app complex text editor enabling markdown writes entirely isolated in-app without pushing `NoteViewerScreen`.
