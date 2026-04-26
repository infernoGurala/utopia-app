import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:utopia_app/firebase_options.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/services/chat_emoji_catalog.dart';
import 'package:utopia_app/services/platform_support.dart';
import 'package:utopia_app/screens/chat_screen.dart';
import 'package:utopia_app/screens/sciwordle_screen.dart';
import 'package:utopia_app/widgets/app_motion.dart';
import 'package:utopia_app/widgets/utopia_snackbar.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!PlatformSupport.supportsNotifications) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
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
          } catch (e) {}
        },
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

          if (type == 'sci_wordle' && !U.sciWordleNotifEnabled) {
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

  static Future<bool> _areNotificationPermissionsEnabled() async {
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

  static Future<void> ensureNotificationPermissions() async {
    if (!PlatformSupport.supportsNotifications) {
      return;
    }
    if (_checkingNotificationPermission) {
      return;
    }

    _checkingNotificationPermission = true;
    try {
      final enabled = await _areNotificationPermissionsEnabled();
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

    final previewBody = ChatEmojiCatalog.notificationPreviewText(body);
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

    if (type == 'sci_wordle') {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        unawaited(navigator.push(buildForwardRoute(const SciwordleScreen())));
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

  static Future<void> sendPersonalTestNotification({required String message}) async {
    const platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'utopia_high_importance',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'Test Notification',
      message,
      platformChannelSpecifics,
    );
  }

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
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
}
