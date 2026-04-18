# App Development Stage Manager

## ✅ Completed Stages

### Stage 1 — Data Models + University Selection
### Stage 2 — Library Home Screen + Create/Join Class
### Stage 3 — Notes File Browser
### Stage 4 — Community Notes

---

## Upcoming Stages

### **Stage 5 — Edit Mode**
In-app complex text editor enabling markdown writes entirely isolated in-app without pushing `NoteViewerScreen`.
- Replace pen icon with dedicated edit mode screen
- Include clear, clean, simple edit mode features
- [[new Edit mode]]

### **Stage 6 — Class Settings**
Features per class (Writer-only access):
- Add/Remove Writers (Max 6)
- Share Class Join link (`classes.inferalis.space/join/{classCode}`)
- Timetable configuration menu
- Delete Class (Heavy warning sequence)

**Special Case:**
- Community Notes / University Notes: Everyone has writer mode options

### **Stage 7 — Timetable v3**
- Select timetable from joined/created class
- Create custom timetable manually
- Storage: `{universityName}/{classId}/Workflows/timetable.json`
- Hidden from regular Notes browser

### **Stage 8 — Notifications**
- Toggle ON/OFF per class
- Notification content includes Quotes (managed by Super User)
- App fetches timetable locally for reminders

### **Stage 9 — Super User / Admin**
- Elevated privileges for university management
- App-wide configuration
- Manage notification quotes
- Creator access portal bypassing strict permissions