import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'secure_storage_service.dart';
import 'calendar_cache_service.dart';
import 'calendar_notification_service.dart';
import 'reminder_calendar_bridge.dart';
import '../models/google_calendar_models.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleCalendarService {
  static final GoogleCalendarService instance = GoogleCalendarService._();
  GoogleCalendarService._();

  // ─── Authentication Operations ───────────────────────────────

  Future<bool> isConnected() async {
    final token = await SecureStorageService.getGoogleAccessToken();
    return token != null;
  }

  Future<bool> connect() async {
    try {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      await GoogleSignIn.instance.initialize(
        serverClientId:
            '402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com',
      );

      final GoogleSignInAccount account;
      try {
        account = await GoogleSignIn.instance.authenticate();
      } catch (e) {
        debugPrint("GOOGLE_CAL: Sign-in cancelled or failed: $e");
        return false;
      }

      final GoogleSignInClientAuthorization authz;
      try {
        authz = await account.authorizationClient.authorizeScopes([
          calendar.CalendarApi.calendarScope,
        ]);
      } catch (e) {
        debugPrint("GOOGLE_CAL: Scopes authorization cancelled or failed: $e");
        return false;
      }

      final accessToken = authz.accessToken;
      final expiry = DateTime.now().add(const Duration(minutes: 55)); // Standard google token lasts 1 hour
      await SecureStorageService.saveGoogleTokens(
        accessToken: accessToken,
        expiry: expiry,
      );

      debugPrint("GOOGLE_CAL: Successfully connected with Calendar scope!");
      
      // Perform initial full sync
      unawaited(syncAll());
      
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Connection error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await GoogleSignIn.instance.signOut().catchError((_) {});
    } catch (_) {}
    await SecureStorageService.clearGoogleTokens();
    await CalendarCacheService.instance.clearAll();
    debugPrint("GOOGLE_CAL: Disconnected successfully");
  }

  Future<String?> getFreshAccessToken() async {
    final token = await SecureStorageService.getGoogleAccessToken();
    final expiry = await SecureStorageService.getGoogleTokenExpiry();

    if (token == null) return null;

    // Check if token is expired or expiring in next 5 minutes
    if (expiry == null || expiry.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      debugPrint("GOOGLE_CAL: Token expired or near expiry, refreshing...");
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '402670858978-94eqn0qvvrtv59ijne3hn1g5flr4ahve.apps.googleusercontent.com',
        );

        final accountFuture = GoogleSignIn.instance.attemptLightweightAuthentication(reportAllExceptions: false);
        final account = accountFuture != null ? await accountFuture : null;
        if (account != null) {
          final authz = await account.authorizationClient.authorizationForScopes([
            calendar.CalendarApi.calendarScope,
          ]);
          
          final newAccessToken = authz?.accessToken;
          if (newAccessToken != null) {
            final newExpiry = DateTime.now().add(const Duration(minutes: 55));
            await SecureStorageService.saveGoogleTokens(
              accessToken: newAccessToken,
              expiry: newExpiry,
            );
            debugPrint("GOOGLE_CAL: Silent token refresh success");
            return newAccessToken;
          }
        }
      } catch (e) {
        debugPrint("GOOGLE_CAL: Silent refresh failed: $e");
      }
      
      // If silent refresh failed, we return null to let sync fail gracefully.
      // We do not disconnect/wipe tokens here to avoid logging the user out during network dropouts.
      return null;
    }

    return token;
  }

  Future<calendar.CalendarApi?> _getCalendarApi() async {
    final accessToken = await getFreshAccessToken();
    if (accessToken == null) return null;

    final client = GoogleAuthClient({'Authorization': 'Bearer $accessToken'});
    return calendar.CalendarApi(client);
  }

  Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.any((result) => result != ConnectivityResult.none);
  }

  // ─── Dynamic Bidirectional Sync ─────────────────────────────

  Future<void> syncAll() async {
    if (!await isConnected() || !await _isOnline()) return;
    debugPrint("GOOGLE_CAL: Starting background sync...");

    try {
      // 1. Push offline local edits first
      await pushLocalEdits();

      // 2. Fetch and Cache calendars
      final api = await _getCalendarApi();
      if (api == null) return;

      final calendarList = await api.calendarList.list();
      if (calendarList.items == null) return;

      final calendars = calendarList.items!.map((c) {
        return GoogleCalendar(
          id: c.id!,
          summary: c.summary ?? 'Untitled Calendar',
          description: c.description,
          backgroundColor: c.backgroundColor,
          foregroundColor: c.foregroundColor,
          selected: c.selected ?? true,
          accessRole: c.accessRole,
        );
      }).toList();

      await CalendarCacheService.instance.saveCalendars(calendars);

      // 3. Sync events for each visible calendar
      final savedCalendars = await CalendarCacheService.instance.getCalendars();
      for (final cal in savedCalendars) {
        if (!cal.selected) continue; // Skip hidden calendars
        
        try {
          final now = DateTime.now();
          // Sync events within window: 1 month ago to 6 months in future
          final timeMin = now.subtract(const Duration(days: 30)).toUtc();
          final timeMax = now.add(const Duration(days: 180)).toUtc();

          final googleEvents = await api.events.list(
            cal.id,
            timeMin: timeMin,
            timeMax: timeMax,
            singleEvents: true, // Expand recurring event instances
          );

          if (googleEvents.items != null) {
            final eventsToCache = googleEvents.items!.map((e) {
              return _mapGoogleEventToCache(e, cal.id);
            }).toList();

            await CalendarCacheService.instance.saveEvents(eventsToCache);
          }
        } catch (e) {
          debugPrint("GOOGLE_CAL: Failed syncing events for calendar ${cal.id}: $e");
        }
      }

      // 4. Schedule/update all notification reminders based on synced cache
      await CalendarNotificationService.instance.scheduleAllVisibleEventsReminders();
      
      // 5. Trigger sync of UTOPIA-tagged reminders
      try {
        final allEvents = await CalendarCacheService.instance.getEvents(includeHidden: true);
        await ReminderCalendarBridge.instance.onCalendarSyncCompleted(allEvents);
      } catch (bridgeErr) {
        debugPrint("GOOGLE_CAL: Sync bridge error: $bridgeErr");
      }
      
      debugPrint("GOOGLE_CAL: Sync completed successfully!");
    } catch (e) {
      debugPrint("GOOGLE_CAL: Error in sync: $e");
    }
  }

  // ─── Sync Offline Dirty / Deleted Queues ──────────────────────

  Future<void> pushLocalEdits() async {
    if (!await _isOnline()) return;
    final api = await _getCalendarApi();
    if (api == null) return;

    try {
      // 1. Process deletions
      final deleted = await CalendarCacheService.instance.getDeletedEvents();
      for (final e in deleted) {
        try {
          if (!e.id.startsWith('local_')) {
            await api.events.delete(e.calendarId, e.id);
          }
          await CalendarCacheService.instance.hardDeleteEvent(e.id);
        } catch (err) {
          debugPrint("GOOGLE_CAL: Failed to delete remote event ${e.id}: $err");
          // If event doesn't exist on server (e.g. 404), clean local DB anyway
          if (err.toString().contains('404')) {
            await CalendarCacheService.instance.hardDeleteEvent(e.id);
          }
        }
      }

      // 2. Process updates and creations
      final dirty = await CalendarCacheService.instance.getDirtyEvents();
      for (final e in dirty) {
        try {
          final apiEvent = _mapCacheEventToGoogle(e);
          calendar.Event result;

          if (e.id.startsWith('local_')) {
            // Creation
            result = await api.events.insert(
              apiEvent,
              e.calendarId,
              conferenceDataVersion: 1, // Required to generate Google Meet link
            );
            // Replace local ID in database with real ID from Google
            await CalendarCacheService.instance.hardDeleteEvent(e.id);
            final newEvent = _mapGoogleEventToCache(result, e.calendarId);
            await CalendarCacheService.instance.saveEvent(newEvent);
          } else {
            // Update
            result = await api.events.patch(
              apiEvent,
              e.calendarId,
              e.id,
              conferenceDataVersion: 1,
            );
            final updatedEvent = _mapGoogleEventToCache(result, e.calendarId);
            await CalendarCacheService.instance.saveEvent(updatedEvent);
          }
        } catch (err) {
          debugPrint("GOOGLE_CAL: Failed to push dirty event ${e.id}: $err");
        }
      }
    } catch (e) {
      debugPrint("GOOGLE_CAL: Error pushing local edits: $e");
    }
  }

  // ─── Google Calendar API CRUD ────────────────────────────────

  Future<bool> createCalendar(String summary, {String? description}) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final newCal = calendar.Calendar()..summary = summary;
      if (description != null) newCal.description = description;

      final result = await api.calendars.insert(newCal);
      final cacheCal = GoogleCalendar(
        id: result.id!,
        summary: result.summary ?? summary,
        description: result.description,
        selected: true,
        accessRole: 'owner',
      );
      await CalendarCacheService.instance.saveCalendars([cacheCal]);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to create calendar: $e");
      return false;
    }
  }

  Future<bool> updateCalendar(String calendarId, String summary) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final updated = calendar.Calendar()..summary = summary;
      await api.calendars.patch(updated, calendarId);
      
      final cals = await CalendarCacheService.instance.getCalendars();
      final target = cals.firstWhere((c) => c.id == calendarId);
      await CalendarCacheService.instance.saveCalendars([
        target.copyWith(summary: summary)
      ]);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to update calendar: $e");
      return false;
    }
  }

  Future<bool> deleteCalendar(String calendarId) async {
    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      await api.calendars.delete(calendarId);
      await CalendarCacheService.instance.deleteCalendar(calendarId);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to delete calendar: $e");
      return false;
    }
  }

  Future<bool> createEvent(GoogleCalendarEvent event, {bool generateMeet = false}) async {
    final offline = !await _isOnline();
    if (offline) {
      // Offline fallback: Save in SQLite marked dirty/created
      await CalendarCacheService.instance.saveEvent(event.copyWith(isDirty: true));
      await CalendarNotificationService.instance.scheduleEventReminders(event);
      return true;
    }

    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final apiEvent = _mapCacheEventToGoogle(event);
      if (generateMeet) {
        apiEvent.conferenceData = calendar.ConferenceData()
          ..createRequest = (calendar.CreateConferenceRequest()
            ..requestId = DateTime.now().millisecondsSinceEpoch.toString()
            ..conferenceSolutionKey = (calendar.ConferenceSolutionKey()
              ..type = 'hangoutsMeet'));
      }

      final result = await api.events.insert(
        apiEvent,
        event.calendarId,
        conferenceDataVersion: 1,
      );

      final cacheEvent = _mapGoogleEventToCache(result, event.calendarId);
      await CalendarCacheService.instance.saveEvent(cacheEvent);
      await CalendarNotificationService.instance.scheduleEventReminders(cacheEvent);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to create event: $e");
      // If error occurs, fallback to caching locally
      await CalendarCacheService.instance.saveEvent(event.copyWith(isDirty: true));
      await CalendarNotificationService.instance.scheduleEventReminders(event);
      return true;
    }
  }

  Future<bool> updateEvent(GoogleCalendarEvent event, {bool generateMeet = false}) async {
    final offline = !await _isOnline();
    if (offline) {
      await CalendarCacheService.instance.saveEvent(event.copyWith(isDirty: true));
      await CalendarNotificationService.instance.scheduleEventReminders(event);
      return true;
    }

    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      final apiEvent = _mapCacheEventToGoogle(event);
      if (generateMeet) {
        apiEvent.conferenceData = calendar.ConferenceData()
          ..createRequest = (calendar.CreateConferenceRequest()
            ..requestId = DateTime.now().millisecondsSinceEpoch.toString()
            ..conferenceSolutionKey = (calendar.ConferenceSolutionKey()
              ..type = 'hangoutsMeet'));
      }

      final result = await api.events.patch(
        apiEvent,
        event.calendarId,
        event.id,
        conferenceDataVersion: 1,
      );

      final cacheEvent = _mapGoogleEventToCache(result, event.calendarId);
      await CalendarCacheService.instance.saveEvent(cacheEvent);
      await CalendarNotificationService.instance.scheduleEventReminders(cacheEvent);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to update event: $e");
      await CalendarCacheService.instance.saveEvent(event.copyWith(isDirty: true));
      await CalendarNotificationService.instance.scheduleEventReminders(event);
      return true;
    }
  }

  Future<bool> deleteEvent(GoogleCalendarEvent event) async {
    // 1. Cancel notifications locally immediately
    await CalendarNotificationService.instance.cancelEventReminders(event.id);

    final offline = !await _isOnline();
    if (offline) {
      await CalendarCacheService.instance.deleteEventLocally(event.id);
      return true;
    }

    final api = await _getCalendarApi();
    if (api == null) return false;

    try {
      if (!event.id.startsWith('local_')) {
        await api.events.delete(event.calendarId, event.id);
      }
      await CalendarCacheService.instance.hardDeleteEvent(event.id);
      return true;
    } catch (e) {
      debugPrint("GOOGLE_CAL: Failed to delete event: $e");
      await CalendarCacheService.instance.deleteEventLocally(event.id);
      return true;
    }
  }

  // ─── Data Mapping Utilities ─────────────────────────────────

  GoogleCalendarEvent _mapGoogleEventToCache(calendar.Event e, String calendarId) {
    DateTime? start;
    bool isAllDay = false;
    if (e.start != null) {
      if (e.start!.dateTime != null) {
        start = e.start!.dateTime;
      } else if (e.start!.date != null) {
        start = e.start!.date;
        isAllDay = true;
      }
    }

    DateTime? end;
    if (e.end != null) {
      if (e.end!.dateTime != null) {
        end = e.end!.dateTime;
      } else if (e.end!.date != null) {
        end = e.end!.date;
      }
    }

    final attendeesList = e.attendees?.map((a) {
          return EventAttendee(
            email: a.email,
            displayName: a.displayName,
            responseStatus: a.responseStatus,
          );
        }).toList() ??
        const <EventAttendee>[];

    final remindersList = e.reminders?.overrides?.map((r) {
          return EventReminderOption(
            method: r.method ?? 'popup',
            minutes: r.minutes ?? 10,
          );
        }).toList() ??
        const <EventReminderOption>[];

    final attachmentsList = e.attachments?.map((a) {
          return EventAttachment(
            fileUrl: a.fileUrl ?? '',
            title: a.title ?? 'Attachment',
            mimeType: a.mimeType,
            iconLink: a.iconLink,
          );
        }).toList() ??
        const <EventAttachment>[];

    String? rrule;
    if (e.recurrence != null && e.recurrence!.isNotEmpty) {
      rrule = e.recurrence!.first;
    }

    // Google Meet Link Extraction
    String? hangoutLink = e.hangoutLink;
    if (hangoutLink == null && e.conferenceData != null && e.conferenceData!.entryPoints != null) {
      final videoEntryPoint = e.conferenceData!.entryPoints!.firstWhere(
        (ep) => ep.entryPointType == 'video',
        orElse: () => calendar.EntryPoint(),
      );
      hangoutLink = videoEntryPoint.uri;
    }

    return GoogleCalendarEvent(
      id: e.id!,
      calendarId: calendarId,
      summary: e.summary,
      description: e.description,
      location: e.location,
      startTime: start,
      endTime: end,
      isAllDay: isAllDay,
      timezone: e.start?.timeZone,
      rrule: rrule,
      colorId: e.colorId,
      hangoutLink: hangoutLink,
      creatorEmail: e.creator?.email,
      organizerEmail: e.organizer?.email,
      visibility: e.visibility,
      attendees: attendeesList,
      reminders: remindersList,
      attachments: attachmentsList,
      updatedAt: e.updated?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      isDeleted: false,
      isDirty: false,
    );
  }

  calendar.Event _mapCacheEventToGoogle(GoogleCalendarEvent e) {
    final event = calendar.Event()
      ..summary = e.summary
      ..description = e.description
      ..location = e.location;

    // Start time mapping
    if (e.startTime != null) {
      if (e.isAllDay) {
        event.start = calendar.EventDateTime()..date = e.startTime;
      } else {
        event.start = calendar.EventDateTime()
          ..dateTime = e.startTime!.toUtc()
          ..timeZone = e.timezone ?? 'UTC';
      }
    }

    // End time mapping
    if (e.endTime != null) {
      if (e.isAllDay) {
        event.end = calendar.EventDateTime()..date = e.endTime;
      } else {
        event.end = calendar.EventDateTime()
          ..dateTime = e.endTime!.toUtc()
          ..timeZone = e.timezone ?? 'UTC';
      }
    }

    // Recurrence rules mapping
    if (e.rrule != null && e.rrule!.isNotEmpty) {
      event.recurrence = [e.rrule!];
    }

    // Visibility
    if (e.visibility != null) {
      event.visibility = e.visibility;
    }

    // Color ID
    if (e.colorId != null) {
      event.colorId = e.colorId;
    }

    // Attendees
    if (e.attendees.isNotEmpty) {
      event.attendees = e.attendees.map((a) {
        return calendar.EventAttendee()
          ..email = a.email
          ..displayName = a.displayName
          ..responseStatus = a.responseStatus;
      }).toList();
    }

    // Reminders
    event.reminders = calendar.EventReminders()
      ..useDefault = false
      ..overrides = [];

    // Attachments
    if (e.attachments.isNotEmpty) {
      event.attachments = e.attachments.map((a) {
        return calendar.EventAttachment()
          ..fileUrl = a.fileUrl
          ..title = a.title
          ..mimeType = a.mimeType
          ..iconLink = a.iconLink;
      }).toList();
    }

    return event;
  }
}
