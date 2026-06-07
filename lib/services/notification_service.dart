import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:utopia_app/firebase_options.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/services/platform_support.dart';
import 'package:utopia_app/screens/chat_screen.dart';
import 'package:utopia_app/screens/event_certificates_screen.dart';
import 'package:utopia_app/screens/timetable_screen.dart';
import 'package:utopia_app/widgets/app_motion.dart';
import 'package:utopia_app/widgets/utopia_snackbar.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:utopia_app/models/focus_models.dart';
import 'package:utopia_app/services/user_timetable_service.dart';
import 'package:utopia_app/models/user_timetable.dart';
import 'package:utopia_app/screens/calendar_screen.dart';
import 'package:utopia_app/services/focus_database_service.dart';
import 'package:utopia_app/services/focus_supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!PlatformSupport.supportsNotifications) {
    return;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) {
      return;
    }

    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await localNotifications.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'utopia_high_importance',
      'UTOPIA Notifications',
      description: 'Morning alerts and writer broadcasts from UTOPIA',
      importance: Importance.high,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'utopia_high_importance',
        'UTOPIA Notifications',
        channelDescription: 'Morning alerts and writer broadcasts from UTOPIA',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
      ),
    );

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode({
        'title': title,
        'body': body,
        'data': message.data,
      }),
    );
  } catch (e) {
    debugPrint('Error in background message handler: $e');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool isDialogShowing = false;
  static StreamSubscription<User?>? _authSubscription;
  static String? _lastSavedToken;
  static String? _lastSavedUid;
  static bool _isAppForeground = true;
  static String? _activeChatId;
  static bool _checkingNotificationPermission = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'utopia_high_importance',
    'UTOPIA Notifications',
    description: 'Morning alerts and writer broadcasts from UTOPIA',
    importance: Importance.high,
  );

  static const Set<AuthorizationStatus> _grantedAuthorizationStatuses = {
    AuthorizationStatus.authorized,
    AuthorizationStatus.provisional,
  };

  static Future<void> initialize() async {
    if (!PlatformSupport.supportsNotifications) {
      return;
    }
    try {
      if (_initialized) {
        return;
      }
      tz.initializeTimeZones();
      try {
        final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            defaultPresentAlert: true,
            defaultPresentSound: true,
            defaultPresentBadge: true,
            defaultPresentBanner: true,
            defaultPresentList: true,
          );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            if (response.payload != null) {
              unawaited(_handleNotificationPayload(response.payload!));
            }
            if (response.actionId != null && response.payload != null) {
              final decoded = jsonDecode(response.payload!);
              if (decoded is Map<String, dynamic> && decoded['type'] == 'focus_reminder') {
                final habitId = decoded['habitId']?.toString();
                final userId = decoded['userId']?.toString();
                if (habitId != null && userId != null) {
                  unawaited(_handleBackgroundHabitAction(
                    actionId: response.actionId,
                    habitId: habitId,
                    userId: userId,
                    notificationId: response.id,
                  ));
                }
              }
            }
          } catch (e) {}
        },
        onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
      );

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          unawaited(_handleNotificationPayload(payload));
        }
      }

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      await ensureNotificationPermissions();

      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
      _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) async {
        if (user == null) {
          return;
        }
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _saveTokenToFirestore(token);
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        try {
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          final type = (message.data['type'] ?? '').toString();
          final chatId =
              (message.data['chatId'] ?? message.data['chat_id'] ?? '')
                  .toString();
          final isForegroundChat = type == 'chat' && _isAppForeground;
          final isActiveChat =
              isForegroundChat && chatId.isNotEmpty && _activeChatId == chatId;

          if (isActiveChat) {
            return;
          }

          if (type == 'morning_notification' && !U.morningNotifEnabled) {
            return;
          }

          if (isForegroundChat) {
            await _showLocalNotification(
              title: title,
              body: body,
              data: Map<String, dynamic>.from(message.data),
            );
            _showInAppMessageHint(title: title, body: body);
            return;
          }

          await _showLocalNotification(
            title: title,
            body: body,
            data: Map<String, dynamic>.from(message.data),
          );
        } catch (e) {}
      });

      FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) async {
        try {
          await _handleRemoteMessageInteraction(message);
        } catch (e) {}
      });

      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        try {
          await _handleRemoteMessageInteraction(initialMessage);
        } catch (e) {}
      }
      _initialized = true;
    } catch (e) {
      return;
    }
  }

  static Future<void> _requestNotificationPermissions() async {
    if (!PlatformSupport.supportsNotifications) {
      return;
    }
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      return;
    }
  }

  static Future<bool> areNotificationPermissionsEnabled() async {
    if (!PlatformSupport.supportsNotifications) {
      return false;
    }
    try {
      final androidEnabled = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      if (androidEnabled != null) {
        return androidEnabled;
      }

      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return _grantedAuthorizationStatuses.contains(
        settings.authorizationStatus,
      );
    } catch (e) {
      return true;
    }
  }

  static Future<void> requestNotificationPermissionOnly() async {
    if (!PlatformSupport.supportsNotifications) return;
    try {
      if (PlatformSupport.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (PlatformSupport.isIOS) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {}
  }


  static Future<void> ensureNotificationPermissions() async {
    if (!PlatformSupport.supportsNotifications) {
      return;
    }
    if (_checkingNotificationPermission) {
      return;
    }

    _checkingNotificationPermission = true;
    try {
      final enabled = await areNotificationPermissionsEnabled();
      if (enabled) {
        return;
      }

      await _requestNotificationPermissions();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      return;
    } finally {
      _checkingNotificationPermission = false;
    }
  }

  static void setAppForeground(bool isForeground) {
    _isAppForeground = isForeground;
  }

  static Future<void> refreshTokenRegistration() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      return;
    }
  }

  static void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }

  static Future<void> sendPersonalMorningNotification({
    required String title,
    required String body,
  }) async {
    final resolvedTitle = title.trim().isEmpty
        ? 'Morning notification'
        : title.trim();
    final resolvedBody = body.trim();
    if (resolvedBody.isEmpty) {
      return;
    }

    await initialize();
    await _showLocalNotification(
      title: resolvedTitle,
      body: resolvedBody,
      data: const <String, dynamic>{'type': 'morning_notification'},
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
  }

  static void _showInAppMessageHint({
    required String title,
    required String body,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    final previewBody = body;
    final message = switch ((title.trim().isNotEmpty, body.trim().isNotEmpty)) {
      (true, true) => '$title: $previewBody',
      (true, false) => title,
      (false, true) => previewBody,
      _ => 'New message',
    };

    showUtopiaSnackBar(
      context,
      message: message,
      tone: UtopiaSnackBarTone.info,
    );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'utopia_high_importance',
        'UTOPIA Notifications',
        channelDescription: 'Morning alerts and writer broadcasts from UTOPIA',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification',
        largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: jsonEncode({
        'title': title,
        'body': body,
        'data': data ?? const <String, dynamic>{},
      }),
    );
  }

  static Future<void> _handleNotificationPayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final title = (decoded['title'] ?? '').toString();
        final body = (decoded['body'] ?? '').toString();
        final data = decoded['data'] is Map
            ? Map<String, dynamic>.from(decoded['data'] as Map)
            : const <String, dynamic>{};
        await _handleNotificationInteraction(
          title: title,
          body: body,
          data: data,
        );
        return;
      }
    } catch (_) {}

    final parts = payload.split('||');
    final title = parts.isNotEmpty ? parts[0] : '';
    final body = parts.length > 1 ? parts[1] : '';
    await _handleNotificationInteraction(
      title: title,
      body: body,
      data: const <String, dynamic>{},
    );
  }

  static Future<void> _handleRemoteMessageInteraction(
    RemoteMessage message,
  ) async {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    return _handleNotificationInteraction(
      title: title,
      body: body,
      data: Map<String, dynamic>.from(message.data),
    );
  }

  static Future<void> _handleNotificationInteraction({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final type = (data['type'] ?? '').toString();
    if (type == 'chat') {
      final senderId = (data['senderId'] ?? data['sender_id'] ?? '').toString();
      final senderName = (data['senderName'] ?? data['sender_name'] ?? title)
          .toString();
      if (senderId.isNotEmpty) {
        final opened = await _openChatFromNotification(
          otherUserId: senderId,
          fallbackName: senderName,
        );
        if (opened) {
          return;
        }
      }
      return;
    }
    if (type == 'certificate') {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const EventCertificatesScreen()),
        );
      }
      return;
    }
    if (type == 'timetable') {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const TimetableScreen()),
        );
      }
      return;
    }
    if (type == 'calendar') {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        await navigator.push(
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        );
      }
      return;
    }
  }

  static Future<bool> _openChatFromNotification({
    required String otherUserId,
    required String fallbackName,
  }) async {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext ?? navigator?.overlay?.context;
    if (navigator == null || context == null) {
      return false;
    }

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();
      final data = userSnap.data() ?? const <String, dynamic>{};
      final displayName = ((data['displayName'] ?? fallbackName).toString())
          .trim();
      final email = (data['email'] ?? '').toString();
      final photoUrl = (data['photoUrl'] ?? '').toString();

      await navigator.push(
        buildForwardRoute(
          ChatScreen(
            otherUserId: otherUserId,
            displayName: displayName.isEmpty ? 'Friend' : displayName,
            email: email,
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
          ),
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> sendPersonalTestNotification({
    required String message,
  }) async {
    const platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'utopia_high_importance',
        'UTOPIA Notifications',
        channelDescription: 'Morning alerts and writer broadcasts from UTOPIA',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Test Notification',
      message,
      platformChannelSpecifics,
    );
    debugPrint("NOTIF: Test notification sent");
  }

  static Future<void> sendCertificateNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    await _showLocalNotification(
      title: title,
      body: body,
      data: const <String, dynamic>{'type': 'certificate'},
    );
  }

  static Future<bool> scheduleDailyTimetableNotification({
    required int hour,
    required int minute,
  }) async {
    if (!PlatformSupport.supportsNotifications) {
      debugPrint("NOTIF: Notifications not supported on this platform");
      return false;
    }
    try {
      // Ensure service is initialized
      await initialize();

      // Ensure timezone is initialized
      tz.initializeTimeZones();
      try {
        final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {}
      final localLocation = tz.local;

      // Cancel all existing timetable notifications
      await _localNotifications.cancel(100);
      for (int i = 101; i <= 106; i++) {
        await _localNotifications.cancel(i);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('timetable_notif_hour', hour);
      await prefs.setInt('timetable_notif_minute', minute);
      await prefs.setBool('timetable_notif_enabled', true);

      UserTimetable? timetable;
      try {
        timetable = await UserTimetableService.getTimetable();
      } catch (e) {
        debugPrint("NOTIF: Could not fetch timetable for dynamic scheduling: $e");
      }

      if (timetable == null || timetable.week.isEmpty) {
        // Fallback to scheduling a single daily notification with generic text
        debugPrint("NOTIF: Timetable is empty, scheduling generic notification.");
        final now = tz.TZDateTime.now(localLocation);
        var scheduledDate = tz.TZDateTime(
          localLocation,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _scheduleSingleZoned(
          id: 100,
          title: 'Daily Timetable',
          body: 'Time to check your classes for today!',
          scheduledDate: scheduledDate,
          components: DateTimeComponents.time,
        );
      } else {
        // Schedule 6 weekly notifications, one for each weekday (1 = Monday, 6 = Saturday)
        debugPrint("NOTIF: Timetable found, scheduling weekly weekday notifications.");
        final now = tz.TZDateTime.now(localLocation);
        final dayPrefixes = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

        for (int i = 1; i <= 6; i++) {
          final targetWeekday = i; // 1 = Monday, 6 = Saturday
          var scheduledDate = tz.TZDateTime(
            localLocation,
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );
          while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          final prefix = dayPrefixes[i - 1];
          final dayData = timetable.week.firstWhere(
            (d) => d.day.toLowerCase().startsWith(prefix),
            orElse: () => const TimetableDay(day: '', slots: []),
          );

          final activeSlots = dayData.slots
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          String bodyText = 'No classes today! Enjoy your free time.';
          if (activeSlots.isNotEmpty) {
            bodyText = 'Today\'s Classes: ${activeSlots.join(", ")}';
          }

          final dayId = 100 + i;
          await _scheduleSingleZoned(
            id: dayId,
            title: 'Your Timetable for ${dayData.day.isNotEmpty ? dayData.day : prefix.toUpperCase()}',
            body: bodyText,
            scheduledDate: scheduledDate,
            components: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
      return true;
    } catch (e) {
      debugPrint("NOTIF: Failed to schedule timetable notification: $e");
      return false;
    }
  }

  // Robust zoned scheduling wrapper that always succeeds even if a resource (like largeIcon) is missing,
  // or if exact alarm permissions are denied.
  static Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    List<AndroidNotificationAction>? actions;
    if (payload != null) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic> && decoded['habitId'] != null) {
          actions = const [
            AndroidNotificationAction(
              'action_completed',
              'Completed',
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'action_not_done',
              'Not Done',
              showsUserInterface: false,
            ),
          ];
        }
      } catch (_) {}
    }

    // 1. Try EXACT scheduling WITH Large Icon
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
            actions: actions,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      debugPrint("NOTIF: Scheduled successfully (exact, with large icon) for ID $id at $scheduledDate");
      return;
    } catch (e) {
      debugPrint("NOTIF: Exact schedule with large icon failed for ID $id ($e). Trying exact WITHOUT large icon...");
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
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
            actions: actions,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      debugPrint("NOTIF: Scheduled successfully (exact, no large icon) for ID $id at $scheduledDate");
      return;
    } catch (e) {
      debugPrint("NOTIF: Exact schedule without large icon failed for ID $id ($e). Trying inexact WITH large icon...");
    }

    // 3. Try INEXACT scheduling WITH Large Icon
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: 'ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
            actions: actions,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
      debugPrint("NOTIF: Scheduled successfully (inexact, with large icon) for ID $id at $scheduledDate");
      return;
    } catch (e) {
      debugPrint("NOTIF: Inexact schedule with large icon failed for ID $id ($e). Trying inexact WITHOUT large icon...");
    }

    // 4. Try INEXACT scheduling WITHOUT Large Icon (absolute baseline fallback)
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: 'ic_notification',
          actions: actions,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
    debugPrint("NOTIF: Scheduled successfully (inexact, no large icon - absolute fallback) for ID $id at $scheduledDate");
  }

  // Private helper to avoid code duplication and support robust exact/inexact fallback
  static Future<void> _scheduleSingleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required DateTimeComponents components,
  }) async {
    final payloadString = jsonEncode({
      'title': title,
      'body': body,
      'data': {
        'type': 'timetable'
      }
    });

    await _safeZonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: 'utopia_high_importance',
      channelName: 'UTOPIA Notifications',
      channelDescription: 'Daily timetable reminders',
      payload: payloadString,
      matchDateTimeComponents: components,
    );
  }

  static Future<void> cancelTimetableNotification() async {
    if (!PlatformSupport.supportsNotifications) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('timetable_notif_enabled', false);
      await _localNotifications.cancel(100);
      for (int i = 101; i <= 106; i++) {
        await _localNotifications.cancel(i);
      }
      debugPrint("NOTIF: Timetable notifications cancelled successfully.");
    } catch (e) {
      // Ignored
    }
  }

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  /// Check if exact alarms are permitted (Android 12+)
  static Future<bool> canScheduleExactNotifications() async {
    if (!PlatformSupport.isAndroid) return true;
    try {
      final result = await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.canScheduleExactNotifications();
      return result ?? true;
    } catch (e) {
      debugPrint("NOTIF: Error checking exact alarm permission: $e");
      return false;
    }
  }

  /// Open system settings for exact alarm permission (Android 12+)
  static Future<void> openExactAlarmSettings() async {
    if (!PlatformSupport.isAndroid) return;
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint("NOTIF: Error opening exact alarm settings: $e");
    }
  }

  /// Check if battery optimization is ignored/disabled for the app.
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!PlatformSupport.isAndroid) return true;
    try {
      const platform = MethodChannel('utopia_app/app_update');
      final bool? ignored = await platform.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? true;
    } catch (e) {
      debugPrint("NOTIF: Error checking battery optimization: $e");
      return true;
    }
  }

  /// Direct user to system settings to disable battery optimization.
  static Future<void> requestIgnoreBatteryOptimization() async {
    if (!PlatformSupport.isAndroid) return;
    try {
      const platform = MethodChannel('utopia_app/app_update');
      await platform.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (e) {
      debugPrint("NOTIF: Error requesting ignore battery optimization: $e");
    }
  }

  static int _notificationIdFromUuid(String uuid) {
    return uuid.hashCode & 0x7FFFFFF0;
  }

  static Future<void> scheduleFocusReminder(FocusReminder reminder) async {
    if (!PlatformSupport.supportsNotifications || reminder.id == null) {
      debugPrint("NOTIF: Cannot schedule reminder. Supported: ${PlatformSupport.supportsNotifications}, ID: ${reminder.id}");
      return;
    }
    try {
      debugPrint("NOTIF: Starting scheduling for reminder: ID=${reminder.id}, Label=${reminder.label}, Type=${reminder.type}, Time=${reminder.reminderTime}, Active=${reminder.isActive}");
      await initialize();
      final ist = tz.local;
      
      // Cancel any pre-existing notifications for this reminder
      await cancelFocusReminder(reminder.id!);

      if (!reminder.isActive) {
        debugPrint("NOTIF: Reminder is inactive, skipping schedule.");
        return;
      }

      final timeParts = reminder.reminderTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final baseId = _notificationIdFromUuid(reminder.id!);
      final now = tz.TZDateTime.now(ist);
      debugPrint("NOTIF: Hashed baseId=$baseId. Current timezone time: $now");

      final payloadString = jsonEncode({
        'type': 'focus_reminder',
        'reminderId': reminder.id,
        'habitId': reminder.habitId,
        'userId': reminder.userId,
        'label': reminder.label,
      });

      final notifTitle = reminder.label.trim().isEmpty ? 'Reminder' : reminder.label;
      final notifBody = (reminder.description != null && reminder.description!.isNotEmpty)
          ? reminder.description!
          : reminder.scheduleSummary;

      if (reminder.type == 'daily') {
        debugPrint("NOTIF: Scheduling daily repeating reminder: ${reminder.label} at $hour:$minute");
        var scheduledDate = tz.TZDateTime(ist, now.year, now.month, now.day, hour, minute);
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _safeZonedSchedule(
          id: baseId,
          title: notifTitle,
          body: notifBody,
          scheduledDate: scheduledDate,
          channelId: 'utopia_high_importance',
          channelName: 'UTOPIA Notifications',
          channelDescription: 'Focus reminders and task alerts',
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payloadString,
        );
      } else if (reminder.type == 'one_time' && reminder.remindDate != null) {
        final dateParts = reminder.remindDate!.split('-');
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);

        var scheduledDate = tz.TZDateTime(ist, year, month, day, hour, minute);
        debugPrint("NOTIF: Calculated scheduled date for one_time reminder: $scheduledDate");
        if (scheduledDate.isBefore(now)) {
          debugPrint("NOTIF: Scheduled date is in the past ($scheduledDate < $now), skipping scheduling.");
          return;
        }

        await _safeZonedSchedule(
          id: baseId,
          title: notifTitle,
          body: notifBody,
          scheduledDate: scheduledDate,
          channelId: 'utopia_high_importance',
          channelName: 'UTOPIA Notifications',
          channelDescription: 'Focus reminders and task alerts',
          payload: payloadString,
        );
      } else if (reminder.type == 'weekly' && reminder.weekdays != null) {
        debugPrint("NOTIF: Scheduling weekly reminder for weekdays: ${reminder.weekdays}");
        for (final weekday in reminder.weekdays!) {
          // Dart weekday: 1 = Mon, 7 = Sun. Our index: 0 = Mon, 6 = Sun.
          final targetWeekday = weekday + 1;
          
          // Find the next occurrence of this weekday
          var scheduledDate = tz.TZDateTime(ist, now.year, now.month, now.day, hour, minute);
          while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          final dayId = baseId + weekday;
          await _safeZonedSchedule(
            id: dayId,
            title: notifTitle,
            body: notifBody,
            scheduledDate: scheduledDate,
            channelId: 'utopia_high_importance',
            channelName: 'UTOPIA Notifications',
            channelDescription: 'Focus reminders and task alerts',
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: payloadString,
          );
        }
      } else if (reminder.type == 'monthly_date' && reminder.monthDay != null) {
        var scheduledDate = tz.TZDateTime(ist, now.year, now.month, reminder.monthDay!, hour, minute);
        if (scheduledDate.isBefore(now)) {
          // Move to next month
          scheduledDate = tz.TZDateTime(ist, now.year, now.month + 1, reminder.monthDay!, hour, minute);
        }

        await _safeZonedSchedule(
          id: baseId,
          title: notifTitle,
          body: notifBody,
          scheduledDate: scheduledDate,
          channelId: 'utopia_high_importance',
          channelName: 'UTOPIA Notifications',
          channelDescription: 'Focus reminders and task alerts',
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          payload: payloadString,
        );
      }
    } catch (e, stack) {
      debugPrint("NOTIF: Error scheduling focus reminder: $e");
      debugPrint("NOTIF_STACKTRACE: $stack");
    }
  }

  static Future<void> cancelFocusReminder(String reminderId) async {
    if (!PlatformSupport.supportsNotifications) return;
    try {
      final baseId = _notificationIdFromUuid(reminderId);
      debugPrint("NOTIF: Cancelling scheduled notifications for baseId=$baseId");
      // Cancel base ID (for one-time and monthly)
      await _localNotifications.cancel(baseId);
      // Cancel weekly weekday IDs
      for (int i = 0; i < 7; i++) {
        await _localNotifications.cancel(baseId + i);
      }
      debugPrint("NOTIF: Focus reminder cancelled successfully: $reminderId (baseId=$baseId)");
    } catch (e) {
      debugPrint("NOTIF: Error cancelling focus reminder: $e");
    }
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
    try {
      if (response.payload != null && response.payload!.isNotEmpty) {
        final payload = response.payload!;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          final type = decoded['type']?.toString();
          if (type == 'focus_reminder') {
            final actionId = response.actionId;
            final habitId = decoded['habitId']?.toString();
            final userId = decoded['userId']?.toString();
            if (habitId != null && userId != null) {
              unawaited(_handleBackgroundHabitAction(
                actionId: actionId,
                habitId: habitId,
                userId: userId,
                notificationId: response.id,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error in onDidReceiveBackgroundNotificationResponse: $e');
    }
  }

  static Future<void> _handleBackgroundHabitAction({
    String? actionId,
    required String habitId,
    required String userId,
    int? notificationId,
  }) async {
    try {
      debugPrint("NOTIF: Handling background/foreground habit action: $actionId for habit: $habitId");
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {}

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final db = FocusDatabaseService();
      final habit = await db.getHabit(habitId);
      final targetValue = habit?.targetValue ?? 1.0;
      final existingRecord = await db.getRecord(habitId, dateStr);

      final record = HabitRecord(
        id: existingRecord?.id ?? const Uuid().v4(),
        habitId: habitId,
        userId: userId,
        date: dateStr,
        value: actionId == 'action_completed' ? targetValue : 0.0,
        targetValue: targetValue,
        completed: actionId == 'action_completed',
        syncStatus: 'pending',
        updatedAt: DateTime.now(),
      );

      final supabaseService = FocusSupabaseService();
      await supabaseService.saveRecord(record);
      debugPrint("NOTIF: Background habit action success - saved HabitRecord: completed=${record.completed}");

      if (notificationId != null) {
        await _localNotifications.cancel(notificationId);
      }
    } catch (e) {
      debugPrint("NOTIF: Error in background habit action handler: $e");
    }
  }

  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (!await _isOnline()) {
          return;
        }
        if (_lastSavedUid == user.uid && _lastSavedToken == token) {
          return;
        }
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'email': user.email,
          'displayName': user.displayName ?? '',
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _lastSavedUid = user.uid;
        _lastSavedToken = token;
      }
    } catch (e) {}
  }

  // ---------------------------------------------------------------------------
  // Delve Vocabulary Reminders (IDs 200, 201, 202)
  // ---------------------------------------------------------------------------

  static const int _delveNotifMorningId = 200;
  static const int _delveNotifAfternoonId = 201;
  static const int _delveNotifEveningId = 202;

  /// Schedule 3 daily notifications for Delve vocabulary session reminders.
  /// Morning (9 AM), Afternoon (2 PM), Evening (8 PM).
  static Future<void> scheduleDelveReminders() async {
    if (!PlatformSupport.supportsNotifications) return;
    try {
      await initialize();

      tz.initializeTimeZones();
      try {
        final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {}
      final localLocation = tz.local;
      final now = tz.TZDateTime.now(localLocation);

      final reminders = <Map<String, dynamic>>[
        {
          'id': _delveNotifMorningId,
          'hour': 9,
          'minute': 0,
          'title': 'Delve – Morning Review',
          'body': 'Start your day strong! Your vocabulary session is waiting.',
        },
        {
          'id': _delveNotifAfternoonId,
          'hour': 14,
          'minute': 0,
          'title': 'Delve – Afternoon Boost',
          'body': 'Quick break? Spend 2 minutes reviewing today\'s words.',
        },
        {
          'id': _delveNotifEveningId,
          'hour': 20,
          'minute': 0,
          'title': 'Delve – Evening Wrap-up',
          'body': 'Don\'t miss today\'s session! Complete it before bed.',
        },
      ];

      for (final r in reminders) {
        var scheduledDate = tz.TZDateTime(
          localLocation,
          now.year,
          now.month,
          now.day,
          r['hour'] as int,
          r['minute'] as int,
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        final payloadString = jsonEncode({
          'title': r['title'],
          'body': r['body'],
          'data': {'type': 'delve_reminder'},
        });

        await _safeZonedSchedule(
          id: r['id'] as int,
          title: r['title'] as String,
          body: r['body'] as String,
          scheduledDate: scheduledDate,
          channelId: 'utopia_high_importance',
          channelName: 'UTOPIA Notifications',
          channelDescription: 'Delve vocabulary session reminders',
          payload: payloadString,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      debugPrint('NOTIF: Delve reminders scheduled (9 AM, 2 PM, 8 PM)');
    } catch (e) {
      debugPrint('NOTIF: Failed to schedule Delve reminders: $e');
    }
  }

  /// Cancel all Delve vocabulary session reminders.
  static Future<void> cancelDelveReminders() async {
    if (!PlatformSupport.supportsNotifications) return;
    try {
      await _localNotifications.cancel(_delveNotifMorningId);
      await _localNotifications.cancel(_delveNotifAfternoonId);
      await _localNotifications.cancel(_delveNotifEveningId);
      debugPrint('NOTIF: Delve reminders cancelled.');
    } catch (e) {
      debugPrint('NOTIF: Failed to cancel Delve reminders: $e');
    }
  }
}

