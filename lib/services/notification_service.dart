import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia_app/firebase_options.dart';
import 'package:utopia_app/main.dart';
import 'package:utopia_app/services/chat_emoji_catalog.dart';
import 'package:utopia_app/services/platform_support.dart';
import 'package:utopia_app/screens/chat_screen.dart';
import 'package:utopia_app/widgets/app_motion.dart';
import 'package:utopia_app/widgets/notification_dialog.dart';
import 'package:utopia_app/widgets/utopia_snackbar.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!PlatformSupport.supportsNotifications) {
    return;
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.persistPendingRemoteMessage(message);
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
  static bool _checkingPendingDialog = false;
  static bool _checkingNotificationPermission = false;
  static const String _pendingNotificationQueueKey =
      'pending_notification_queue_v1';

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

          if (isForegroundChat) {
            unawaited(_saveNotificationToFirestore(message));
            await _showLocalNotification(
              title: title,
              body: body,
              data: Map<String, dynamic>.from(message.data),
            );
            _showInAppMessageHint(title: title, body: body);
            return;
          }

          unawaited(_saveNotificationToFirestore(message));
          await _showLocalNotification(
            title: title,
            body: body,
            data: Map<String, dynamic>.from(message.data),
          );
          showNotificationDialog(title: title, body: body);
        } catch (e) {}
      });

      FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) async {
        try {
          await _handleRemoteMessageInteraction(message);
          unawaited(_saveNotificationToFirestore(message));
        } catch (e) {}
      });

      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        try {
          await _handleRemoteMessageInteraction(initialMessage);
          unawaited(_saveNotificationToFirestore(initialMessage));
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

      final settings = await FirebaseMessaging.instance.getNotificationSettings();
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

  static Future<void> persistPendingRemoteMessage(RemoteMessage message) async {
    try {
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      final type = (message.data['type'] ?? '').toString();
      if (!_shouldQueuePendingNotification(
        type: type,
        title: title,
        body: body,
      )) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingNotificationQueueKey) ?? [];
      final payload = jsonEncode({
        'title': title,
        'body': body,
        'type': type,
        'messageId': message.messageId ?? '',
        'queuedAt': DateTime.now().millisecondsSinceEpoch,
      });
      existing.add(payload);
      await prefs.setStringList(_pendingNotificationQueueKey, existing);
    } catch (e) {
      return;
    }
  }

  static Future<void> maybeShowPendingDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _checkingPendingDialog) {
      return;
    }

    _checkingPendingDialog = true;
    try {
      final localPending = await _consumePendingNotification();
      if (localPending != null) {
        final title = (localPending['title'] ?? '').toString();
        final body = (localPending['body'] ?? '').toString();
        final type = (localPending['type'] ?? 'general').toString();
        final messageId = (localPending['messageId'] ?? '').toString();
        await _syncPendingNotificationToFirestore(
          title: title,
          body: body,
          type: type,
          messageId: messageId,
        );
        if (title.isNotEmpty || body.isNotEmpty) {
          showNotificationDialog(title: title, body: body);
        }
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: user.uid)
          .limit(20)
          .get();

      final pendingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return data['dialogPending'] == true;
      }).toList();

      if (pendingDocs.isEmpty) {
        return;
      }

      pendingDocs.sort((a, b) {
        final aTs = a.data()['receivedAt'];
        final bTs = b.data()['receivedAt'];
        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });

      final doc = pendingDocs.first;
      final data = doc.data();
      final title = (data['title'] ?? '').toString();
      final body = (data['body'] ?? '').toString();
      if (title.isEmpty && body.isEmpty) {
        await doc.reference.update({
          'dialogPending': false,
          'dialogShownAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      showNotificationDialog(title: title, body: body);
      await doc.reference.update({
        'dialogPending': false,
        'dialogShownAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      return;
    } finally {
      _checkingPendingDialog = false;
    }
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

  static Future<void> sendPersonalTestNotification({
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await initialize();
    await _showLocalNotification(
      title: 'Personal test notification',
      body: trimmed,
      data: const <String, dynamic>{'type': 'personal_test'},
    );
    showNotificationDialog(title: 'Personal test notification', body: trimmed);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Personal test notification',
        'body': trimmed,
        'type': 'personal_test',
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'uid': user.uid,
        'messageId': 'personal-test-${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      return;
    }
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
    showNotificationDialog(title: resolvedTitle, body: resolvedBody);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': resolvedTitle,
        'body': resolvedBody,
        'type': 'morning_notification',
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'uid': user.uid,
        'messageId':
            'personal-morning-${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
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

  static Future<void> _handleRemoteMessageInteraction(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    return _removePendingNotification(
      messageId: message.messageId ?? '',
      title: title,
      body: body,
      type: (message.data['type'] ?? '').toString(),
    ).then(
      (_) => _handleNotificationInteraction(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(message.data),
      ),
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

    showNotificationDialog(title: title, body: body);
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

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

  static Future<void> _saveNotificationToFirestore(
    RemoteMessage message,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final messageId = message.messageId ?? '';
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'general';

      if (uid.isEmpty) {
        return;
      }

      if (!await _isOnline()) {
        return;
      }

      if (messageId.isNotEmpty) {
        final existing = await FirebaseFirestore.instance
            .collection('notifications')
            .where('uid', isEqualTo: uid)
            .where('messageId', isEqualTo: messageId)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          return;
        }
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'uid': uid,
        'messageId': messageId,
      });
    } catch (e) {}
  }

  static bool _shouldQueuePendingNotification({
    required String type,
    required String title,
    required String body,
  }) {
    if (type == 'chat') {
      return false;
    }
    return title.trim().isNotEmpty || body.trim().isNotEmpty;
  }

  static Future<Map<String, dynamic>?> _consumePendingNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingNotificationQueueKey) ?? [];
      if (existing.isEmpty) {
        return null;
      }

      final decoded = existing
          .map((item) => jsonDecode(item))
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (decoded.isEmpty) {
        await prefs.remove(_pendingNotificationQueueKey);
        return null;
      }

      decoded.sort((a, b) {
        final aQueued = (a['queuedAt'] as num?)?.toInt() ?? 0;
        final bQueued = (b['queuedAt'] as num?)?.toInt() ?? 0;
        return bQueued.compareTo(aQueued);
      });

      final selected = decoded.first;
      final selectedMessageId = (selected['messageId'] ?? '').toString();
      final selectedTitle = (selected['title'] ?? '').toString();
      final selectedBody = (selected['body'] ?? '').toString();
      final selectedType = (selected['type'] ?? '').toString();

      final remaining = decoded
          .where((item) {
            return !_matchesPendingNotification(
              item,
              messageId: selectedMessageId,
              title: selectedTitle,
              body: selectedBody,
              type: selectedType,
            );
          })
          .map(jsonEncode)
          .toList();

      await prefs.setStringList(_pendingNotificationQueueKey, remaining);
      return selected;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _removePendingNotification({
    required String messageId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingNotificationQueueKey) ?? [];
      if (existing.isEmpty) {
        return;
      }

      final remaining = existing.where((item) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is! Map) {
            return true;
          }
          return !_matchesPendingNotification(
            Map<String, dynamic>.from(decoded),
            messageId: messageId,
            title: title,
            body: body,
            type: type,
          );
        } catch (_) {
          return true;
        }
      }).toList();

      await prefs.setStringList(_pendingNotificationQueueKey, remaining);
    } catch (e) {
      return;
    }
  }

  static bool _matchesPendingNotification(
    Map<String, dynamic> item, {
    required String messageId,
    required String title,
    required String body,
    required String type,
  }) {
    final itemMessageId = (item['messageId'] ?? '').toString();
    if (messageId.isNotEmpty && itemMessageId == messageId) {
      return true;
    }

    return (item['title'] ?? '').toString() == title &&
        (item['body'] ?? '').toString() == body &&
        (item['type'] ?? '').toString() == type;
  }

  static Future<void> _syncPendingNotificationToFirestore({
    required String title,
    required String body,
    required String type,
    required String messageId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: user.uid)
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sameMessageId =
            messageId.isNotEmpty && (data['messageId'] ?? '') == messageId;
        final sameContent =
            (data['title'] ?? '') == title &&
            (data['body'] ?? '') == body &&
            (data['type'] ?? '') == type;
        if (!sameMessageId && !sameContent) {
          continue;
        }

        if (data['dialogPending'] == true) {
          await doc.reference.update({
            'dialogPending': false,
            'dialogShownAt': FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'receivedAt': FieldValue.serverTimestamp(),
        'read': false,
        'dialogPending': false,
        'dialogShownAt': FieldValue.serverTimestamp(),
        'uid': user.uid,
        'messageId': messageId,
      });
    } catch (e) {
      return;
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
}
