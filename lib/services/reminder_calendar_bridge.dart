import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/focus_models.dart';
import '../models/google_calendar_models.dart';
import 'focus_database_service.dart';
import 'focus_supabase_service.dart';
import 'google_calendar_service.dart';
import 'calendar_cache_service.dart';
import 'notification_service.dart';

class ReminderCalendarBridge {
  static final instance = ReminderCalendarBridge._();
  ReminderCalendarBridge._();

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Called by FocusSupabaseService or RemindersScreen after a reminder is saved
  Future<void> onReminderSaved(FocusReminder reminder, {bool? syncToCalendar}) async {
    final userId = _userId;
    if (userId.isEmpty) return;

    final isConnected = await GoogleCalendarService.instance.isConnected();
    if (!isConnected) {
      debugPrint("REMINDER_GCAL_BRIDGE: Google Calendar not connected, skipping reminder save sync.");
      return;
    }

    // Read current state from local database to verify previous connection
    final oldReminder = reminder.id != null
        ? await FocusDatabaseService().getReminder(reminder.id!)
        : null;
    final hasGcalId = oldReminder?.gcalEventId != null || reminder.gcalEventId != null;
    final gcalEventId = reminder.gcalEventId ?? oldReminder?.gcalEventId;

    final bool shouldDelete = syncToCalendar == false && hasGcalId;
    final bool shouldCreate = syncToCalendar == true && !hasGcalId;
    final bool shouldUpdate = (syncToCalendar == true && hasGcalId) || (syncToCalendar == null && hasGcalId);

    if (shouldDelete && gcalEventId != null) {
      debugPrint("REMINDER_GCAL_BRIDGE: Deleting synced event $gcalEventId...");
      final event = await CalendarCacheService.instance.getEvent(gcalEventId);
      if (event != null) {
        await GoogleCalendarService.instance.deleteEvent(event);
      }
      await FocusDatabaseService().updateReminderGcalId(reminder.id!, null);
      
      final updatedReminder = reminder.copyWith(gcalEventId: null);
      await _updateReminderInSupabase(updatedReminder);
    } else if (shouldCreate) {
      debugPrint("REMINDER_GCAL_BRIDGE: Creating synced event...");
      final event = buildEventFromReminder(reminder, userId);
      final success = await GoogleCalendarService.instance.createEvent(event);
      if (success) {
        final savedEvent = await CalendarCacheService.instance.getEvent(event.id);
        if (savedEvent != null) {
          await FocusDatabaseService().updateReminderGcalId(reminder.id!, savedEvent.id);
          
          final updatedReminder = reminder.copyWith(gcalEventId: savedEvent.id);
          await _updateReminderInSupabase(updatedReminder);
        }
      }
    } else if (shouldUpdate && gcalEventId != null) {
      debugPrint("REMINDER_GCAL_BRIDGE: Updating synced event $gcalEventId...");
      final event = buildEventFromReminder(reminder.copyWith(gcalEventId: gcalEventId), userId);
      await GoogleCalendarService.instance.updateEvent(event);
    }
  }

  /// Called by FocusSupabaseService or RemindersScreen after a reminder is deleted
  Future<void> onReminderDeleted(FocusReminder reminder) async {
    final isConnected = await GoogleCalendarService.instance.isConnected();
    if (!isConnected) return;

    final gcalId = reminder.gcalEventId;
    if (gcalId != null) {
      debugPrint("REMINDER_GCAL_BRIDGE: Reminder deleted, deleting linked event $gcalId...");
      final event = await CalendarCacheService.instance.getEvent(gcalId);
      if (event != null) {
        await GoogleCalendarService.instance.deleteEvent(event);
      }
    }
  }

  /// Called by GoogleCalendarService.syncAll() after cache updates from the server
  Future<void> onCalendarSyncCompleted(List<GoogleCalendarEvent> syncedEvents) async {
    final userId = _userId;
    if (userId.isEmpty) return;

    final syncedEventIds = syncedEvents.map((e) => e.id).toSet();
    final allLocalReminders = await FocusDatabaseService().getReminders(userId);
    
    // 1. Check for unlinking: calendar event deleted on Google Calendar server
    for (final reminder in allLocalReminders) {
      if (reminder.gcalEventId != null) {
        if (!syncedEventIds.contains(reminder.gcalEventId)) {
          debugPrint("REMINDER_GCAL_BRIDGE: Synced event ${reminder.gcalEventId} is gone. Unlinking reminder ${reminder.id}...");
          final unlinkedReminder = reminder.copyWith(gcalEventId: null);
          await FocusDatabaseService().saveReminder(unlinkedReminder);
          await _updateReminderInSupabase(unlinkedReminder);
        }
      }
    }

    // 2. Scan synced events for UTOPIA reminder tags and apply updates (Last-Write-Wins)
    for (final event in syncedEvents) {
      final reminderId = extractReminderIdFromEvent(event);
      if (reminderId == null) continue;

      final reminder = await FocusDatabaseService().getReminder(reminderId);
      if (reminder != null) {
        final eventUpdatedTime = DateTime.fromMillisecondsSinceEpoch(event.updatedAt);
        final reminderUpdatedTime = reminder.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        if (eventUpdatedTime.difference(reminderUpdatedTime).inSeconds > 5) {
          debugPrint("REMINDER_GCAL_BRIDGE: Event is newer than Reminder. Updating reminder $reminderId...");
          
          final baseReminder = buildReminderFromEvent(event, userId);
          final updatedReminder = FocusReminder(
            id: reminderId,
            userId: userId,
            label: baseReminder.label,
            type: baseReminder.type,
            reminderTime: baseReminder.reminderTime,
            remindDate: baseReminder.remindDate,
            weekdays: baseReminder.weekdays,
            monthDay: baseReminder.monthDay,
            activeMonths: baseReminder.activeMonths,
            isActive: baseReminder.isActive,
            syncStatus: reminder.syncStatus,
            createdAt: reminder.createdAt,
            updatedAt: eventUpdatedTime,
            gcalEventId: event.id,
          );

          await FocusDatabaseService().saveReminder(updatedReminder);
          await NotificationService.scheduleFocusReminder(updatedReminder);
          await _updateReminderInSupabase(updatedReminder);
        }
      }
    }
  }

  /// Called by EventEditorScreen when "Add to Reminders" is toggled ON while saving
  Future<FocusReminder?> createReminderFromEvent(GoogleCalendarEvent event) async {
    final userId = _userId;
    if (userId.isEmpty) return null;

    final reminderId = extractReminderIdFromEvent(event) ?? const Uuid().v4();
    
    final reminder = buildReminderFromEvent(event, userId).copyWith(
      id: reminderId,
      gcalEventId: event.id,
    );

    await FocusDatabaseService().saveReminder(reminder);
    await NotificationService.scheduleFocusReminder(reminder);
    await _updateReminderInSupabase(reminder);

    debugPrint("REMINDER_GCAL_BRIDGE: Created reminder $reminderId from event ${event.id}");
    return reminder;
  }

  /// Called by EventEditorScreen/CalendarScreen before deleting a linked event
  /// Returns true if deletion should proceed, false if cancelled by user
  Future<bool> onCalendarEventDeleted(BuildContext context, GoogleCalendarEvent event) async {
    final reminderId = extractReminderIdFromEvent(event);
    if (reminderId == null) return true; // No linked reminder, proceed with delete.

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Linked Reminder Found'),
        content: const Text(
          'This calendar event is linked to a Utopia Reminder. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'unlink'),
            child: const Text('Keep Reminder (Unlink)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Both'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == 'delete') {
      await FocusDatabaseService().deleteReminder(reminderId);
      await NotificationService.cancelFocusReminder(reminderId);
      final supabaseService = FocusSupabaseService();
      if (supabaseService.isInitialized) {
        try {
          await supabaseService.deleteReminder(reminderId);
        } catch (e) {
          debugPrint("REMINDER_GCAL_BRIDGE: Failed to delete reminder in Supabase: $e");
        }
      }
      return true;
    } else if (choice == 'unlink') {
      final reminder = await FocusDatabaseService().getReminder(reminderId);
      if (reminder != null) {
        final unlinkedReminder = reminder.copyWith(gcalEventId: null);
        await FocusDatabaseService().saveReminder(unlinkedReminder);
        await _updateReminderInSupabase(unlinkedReminder);
      }
      return true;
    } else {
      return false;
    }
  }

  /// Helper: extract the UTOPIA reminder ID from a calendar event description
  String? extractReminderIdFromEvent(GoogleCalendarEvent event) {
    final desc = event.description;
    if (desc == null || desc.isEmpty) return null;
    final match = RegExp(r'\[utopia_reminder:([a-zA-Z0-9\-]+)\]').firstMatch(desc);
    return match?.group(1);
  }

  /// Helper: build a GoogleCalendarEvent from a FocusReminder
  GoogleCalendarEvent buildEventFromReminder(FocusReminder reminder, String userId) {
    final timeParts = reminder.reminderTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    DateTime start;
    if (reminder.type == 'one_time' && reminder.remindDate != null) {
      final dateParts = reminder.remindDate!.split('-');
      start = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        hour,
        minute,
      );
    } else {
      // Pick a valid starting occurrence date
      final now = DateTime.now();
      start = DateTime(now.year, now.month, now.day, hour, minute);
    }

    final end = start.add(const Duration(minutes: 30));
    final description = "[utopia_reminder:${reminder.id}]\nSynced from Utopia Reminders.";

    String? rrule;
    if (reminder.type == 'daily') {
      rrule = 'RRULE:FREQ=DAILY';
    } else if (reminder.type == 'weekly' && reminder.weekdays != null && reminder.weekdays!.isNotEmpty) {
      const dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      final days = reminder.weekdays!.map((w) => dayCodes[w]).join(',');
      rrule = 'RRULE:FREQ=WEEKLY;BYDAY=$days';
    } else if (reminder.type == 'monthly_date' && reminder.monthDay != null) {
      rrule = 'RRULE:FREQ=MONTHLY;BYMONTHDAY=${reminder.monthDay}';
    }

    return GoogleCalendarEvent(
      id: reminder.gcalEventId ?? 'local_${const Uuid().v4()}',
      calendarId: 'primary',
      summary: reminder.label,
      description: description,
      startTime: start,
      endTime: end,
      rrule: rrule,
      colorId: '9', // Blueberry
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Helper: build a FocusReminder from a GoogleCalendarEvent
  FocusReminder buildReminderFromEvent(GoogleCalendarEvent event, String userId) {
    final start = event.startTime ?? DateTime.now();
    final reminderTime = "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";

    String type = 'one_time';
    String? remindDate;
    List<int>? weekdays;
    int? monthDay;

    final rrule = event.rrule;
    if (rrule != null) {
      if (rrule.contains('FREQ=DAILY')) {
        type = 'daily';
      } else if (rrule.contains('FREQ=WEEKLY')) {
        type = 'weekly';
        final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
        if (byDayMatch != null) {
          const dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
          final days = byDayMatch.group(1)!.split(',');
          weekdays = days.map((d) => dayCodes.indexOf(d)).where((idx) => idx != -1).toList();
        }
      } else if (rrule.contains('FREQ=MONTHLY')) {
        type = 'monthly_date';
        final byMonthDayMatch = RegExp(r'BYMONTHDAY=([0-9]+)').firstMatch(rrule);
        if (byMonthDayMatch != null) {
          monthDay = int.tryParse(byMonthDayMatch.group(1)!);
        }
        monthDay ??= start.day;
      }
    }

    if (type == 'one_time') {
      remindDate = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    }

    return FocusReminder(
      userId: userId,
      label: event.summary ?? 'Untitled Reminder',
      type: type,
      reminderTime: reminderTime,
      remindDate: remindDate,
      weekdays: weekdays,
      monthDay: monthDay,
      isActive: true,
      gcalEventId: event.id,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(event.updatedAt),
    );
  }

  Future<void> _updateReminderInSupabase(FocusReminder reminder) async {
    final supabaseService = FocusSupabaseService();
    if (supabaseService.isInitialized) {
      try {
        await supabaseService.saveReminder(reminder);
      } catch (e) {
        debugPrint("REMINDER_GCAL_BRIDGE: Failed to update reminder in Supabase: $e");
      }
    }
  }
}
