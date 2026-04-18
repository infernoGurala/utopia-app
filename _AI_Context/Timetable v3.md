# Timetable v3 Specification

## Assignment Methods
1. Select timetable from a joined/created class.
2. Create a custom timetable manually.

## Storage
- Class timetable stored in GitHub: `{universityName}/{classId}/Workflows/timetable.json`
- Workflows/config files are **not** visible to regular readers/writers in the Notes browser.

## Empty State
- If selected class has no timetable, show warning.

## Class Notifications
- Toggle ON/OFF per class.
- Notification trigger runs once via GitHub workflow; app fetches timetable locally to display reminders.
- Notification content includes **Quotes** managed only by Super User (Admin).