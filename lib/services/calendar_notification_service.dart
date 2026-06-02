import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'platform_support.dart';
import 'calendar_cache_service.dart';
import '../models/google_calendar_models.dart';

class CalendarNotificationService {
  static final CalendarNotificationService instance =
      CalendarNotificationService._();
  CalendarNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'calendar_reminders';
  static const String _channelName = 'utopia_calendar';
  static const String _channelDesc = 'Utopia calendar reminders and event alerts';

  Future<void> initialize() async {
    if (!PlatformSupport.supportsNotifications) return;
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      try {
        final String timeZoneName =
            (await FlutterTimezone.getLocalTimezone()).identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }

      // Android Channel creation
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      _initialized = true;
      debugPrint("CAL_NOTIF: Service initialized successfully");
    } catch (e) {
      debugPrint("CAL_NOTIF: Error initializing notification service: $e");
    }
  }

  // ─── ID Generation Range 5000–9999 ───────────────────────────

  int _getNotificationId(String eventId, int reminderIndex) {
    final int hash = eventId.hashCode.abs();
    final int baseId = 5000 + (hash % 4500); // Base between 5000 and 9500
    return baseId + (reminderIndex % 10); // Offset up to 9, max ID = 9509
  }

  // ─── Schedule Event Reminders ────────────────────────────────

  Future<void> scheduleEventReminders(GoogleCalendarEvent event) async {
    if (!PlatformSupport.supportsNotifications) return;
    await initialize();

    // 1. Cancel existing reminders for this event
    await cancelEventReminders(event.id);

    if (event.isDeleted || event.startTime == null) {
      debugPrint("CAL_NOTIF: Event is deleted or has no start time, skipping schedule.");
      return;
    }

    final now = DateTime.now();
    if (event.startTime!.isBefore(now)) {
      debugPrint("CAL_NOTIF: Event start time has already passed, skipping schedule.");
      return;
    }

    final localLocation = tz.local;

    // Filter and process popup reminders
    final popupReminders = event.reminders
        .where((r) => r.method == 'popup')
        .toList();

    for (int i = 0; i < popupReminders.length; i++) {
      final reminder = popupReminders[i];
      final reminderTime = event.startTime!.subtract(Duration(minutes: reminder.minutes));

      if (reminderTime.isBefore(now)) {
        continue; // Skip past triggers
      }

      final tzTriggerTime = tz.TZDateTime.from(reminderTime, localLocation);
      final notifId = _getNotificationId(event.id, i);

      final payloadString = jsonEncode({
        'title': event.summary ?? 'Calendar Event',
        'body': 'Starting in ${reminder.minutes} minutes',
        'data': {
          'type': 'calendar',
          'event_id': event.id,
          'calendar_id': event.calendarId,
        }
      });

      String bodyText = 'Starts at ${event.startTime!.hour.toString().padLeft(2, '0')}:${event.startTime!.minute.toString().padLeft(2, '0')}';
      if (event.location != null && event.location!.isNotEmpty) {
        bodyText += ' • ${event.location}';
      }

      await _safeZonedSchedule(
        id: notifId,
        title: event.summary ?? 'Calendar Event',
        body: bodyText,
        scheduledDate: tzTriggerTime,
        payload: payloadString,
      );
    }
  }

  // ─── Cancel Event Reminders ──────────────────────────────────

  Future<void> cancelEventReminders(String eventId) async {
    if (!PlatformSupport.supportsNotifications) return;
    await initialize();

    try {
      // Cancel possible IDs for this event (up to 10 indices)
      for (int i = 0; i < 10; i++) {
        final notifId = _getNotificationId(eventId, i);
        await _localNotifications.cancel(notifId);
      }
      debugPrint("CAL_NOTIF: Cancelled notifications for event $eventId");
    } catch (e) {
      debugPrint("CAL_NOTIF: Error cancelling reminders: $e");
    }
  }

  // ─── Schedule All Visible Events ──────────────────────────────

  Future<void> scheduleAllVisibleEventsReminders() async {
    if (!PlatformSupport.supportsNotifications) return;
    await initialize();

    try {
      final now = DateTime.now();
      // Fetch upcoming visible events (next 7 days is a good default to prevent overloading)
      final endFilter = now.add(const Duration(days: 7));
      final events = await CalendarCacheService.instance.getEvents(
        start: now,
        end: endFilter,
        includeHidden: false,
      );

      debugPrint("CAL_NOTIF: Bulk scheduling reminders for ${events.length} upcoming events.");
      for (final e in events) {
        await scheduleEventReminders(e);
      }
    } catch (e) {
      debugPrint("CAL_NOTIF: Failed bulk scheduling: $e");
    }
  }

  // ─── Safe Zoned Scheduling (Exact/Inexact Fallback) ──────────

  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
  }) async {
    // 1. Try EXACT scheduling WITH Large Icon
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint("CAL_NOTIF: Exact schedule success for ID $id at $scheduledDate");
      return;
    } catch (e) {
      debugPrint("CAL_NOTIF: Exact schedule with large icon failed ($e). Retrying exact WITHOUT large icon...");
    }

    // 2. Try EXACT scheduling WITHOUT Large Icon
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint("CAL_NOTIF: Exact schedule success (no large icon) for ID $id at $scheduledDate");
      return;
    } catch (e) {
      debugPrint("CAL_NOTIF: Exact schedule without large icon failed ($e). Trying inexact...");
    }

    // 3. Try INEXACT scheduling as a baseline fallback (Android 12 exact alarm permission denied case)
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint("CAL_NOTIF: Scheduled inexact fallback successfully for ID $id at $scheduledDate");
    } catch (e) {
      debugPrint("CAL_NOTIF: All scheduling methods failed for ID $id: $e");
    }
  }
}
