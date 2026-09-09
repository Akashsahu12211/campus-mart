import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../firebase_options.dart';
import '../utils/app_logger.dart';
import 'app_navigation_service.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  AppLogger.debug('[PUSH] Background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const bool _enableInDebug = bool.fromEnvironment(
    'ENABLE_PUSH_IN_DEBUG',
    defaultValue: false,
  );

  bool _initialized = false;
  bool _listenersAttached = false;
  int? _currentUserId;
  String? _lastSyncedToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kDebugMode && !_enableInDebug) {
      AppLogger.debug(
        '[PUSH] Skipping Firebase messaging initialization in debug mode.',
      );
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      AppLogger.debug(
        '[PUSH] Notification permission: ${settings.authorizationStatus.name}',
      );

      try {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {
        // Android may not require foreground presentation options.
      }

      _attachListeners();
      final token = await messaging.getToken();
      AppLogger.debug('[PUSH] Initial FCM token ready: ${_maskToken(token)}');

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          AppNavigationService.handleClickAction(
            clickAction:
                initialMessage.data['click_action']?.toString() ??
                initialMessage.data['clickAction']?.toString(),
            data: Map<String, dynamic>.from(initialMessage.data),
          );
        });
      }

      _initialized = true;
      AppLogger.info('[PUSH] Firebase messaging initialized.');
    } on MissingPluginException catch (error) {
      AppLogger.warn('[PUSH] Firebase messaging plugin not ready: $error');
    } catch (error) {
      AppLogger.error('[PUSH] Firebase initialization failed.', error);
    }
  }

  Future<void> syncTokenForUser(int userId) async {
    _currentUserId = userId;
    await initialize();
    if (!_initialized) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        AppLogger.warn('[PUSH] No FCM token available.');
        return;
      }

      AppLogger.debug(
        '[PUSH] FCM token available for user $userId: ${_maskToken(token)}',
      );

      await ApiService().saveNotificationToken(
        userId: userId,
        fcmToken: token,
        platform: defaultTargetPlatform.name.toUpperCase(),
      );
      _lastSyncedToken = token;
      AppLogger.info('[PUSH] FCM token synced for user $userId');
    } catch (error) {
      AppLogger.error('[PUSH] Token sync failed.', error);
    }
  }

  Future<void> clearTokenForUser(int userId) async {
    _currentUserId = null;
    if (!_initialized) {
      _lastSyncedToken = null;
      return;
    }

    try {
      await ApiService().clearNotificationToken(
        userId: userId,
        fcmToken: _lastSyncedToken,
        platform: defaultTargetPlatform.name.toUpperCase(),
      );
    } catch (error) {
      AppLogger.error('[PUSH] Server token cleanup failed.', error);
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      AppLogger.error('[PUSH] Local token cleanup failed.', error);
    }

    _lastSyncedToken = null;
  }

  void _attachListeners() {
    if (_listenersAttached) {
      return;
    }
    _listenersAttached = true;

    FirebaseMessaging.onMessage.listen((message) {
      AppLogger.debug('[PUSH] Foreground message: ${message.messageId}');
      AppNavigationService.showNotificationToast(
        title: message.notification?.title ??
            message.data['title']?.toString() ??
            'Campus Mart',
        body: message.notification?.body ??
            message.data['body']?.toString() ??
            'You have a new update.',
        clickAction: message.data['click_action']?.toString() ??
            message.data['clickAction']?.toString(),
        data: Map<String, dynamic>.from(message.data),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      AppLogger.debug('[PUSH] Notification opened app: ${message.messageId}');
      AppNavigationService.handleClickAction(
        clickAction: message.data['click_action']?.toString() ??
            message.data['clickAction']?.toString(),
        data: Map<String, dynamic>.from(message.data),
      );
    });

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final userId = _currentUserId;
      if (userId == null || token.isEmpty) {
        return;
      }

      try {
        await ApiService().saveNotificationToken(
          userId: userId,
          fcmToken: token,
          platform: defaultTargetPlatform.name.toUpperCase(),
        );
        _lastSyncedToken = token;
        AppLogger.info('[PUSH] Refreshed FCM token synced for user $userId');
      } catch (error) {
        AppLogger.error('[PUSH] Token refresh sync failed.', error);
      }
    });
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) {
      return 'n/a';
    }
    if (token.length <= 8) {
      return '***';
    }
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }
}
