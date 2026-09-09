import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppNavigationService {
  AppNavigationService._();

  static void showNotificationToast({
    required String title,
    required String body,
    String? clickAction,
    Map<String, dynamic>? data,
  }) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: const Color(0xFF0F1320),
          surfaceTintColor: Colors.transparent,
          dividerColor: const Color(0xFF5B4BFF),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Campus Mart Notification',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFFC7D2FE),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                messenger.hideCurrentMaterialBanner();
                handleClickAction(clickAction: clickAction, data: data);
              },
              child: const Text('Open'),
            ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );

    Future<void>.delayed(const Duration(seconds: 5), () {
      appScaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    });
  }

  static void handleRemoteMessage(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title'] ?? 'Campus Mart';
    final body = message.notification?.body ??
        message.data['body'] ??
        'You have a new update.';

    showNotificationToast(
      title: title,
      body: body,
      clickAction: _extractClickAction(message.data),
      data: Map<String, dynamic>.from(message.data),
    );
  }

  static void handleClickAction({
    String? clickAction,
    Map<String, dynamic>? data,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    final action = (clickAction ?? '').trim();
    final payload = data ?? const <String, dynamic>{};

    if (action.startsWith('/item/')) {
      final itemId = int.tryParse(action.split('/').last) ??
          int.tryParse('${payload['itemId'] ?? ''}');
      if (itemId != null) {
        navigator.pushNamed('/item', arguments: itemId);
        return;
      }
    }

    switch (action) {
      case '/chat':
        navigator.pushNamed('/chat');
        return;
      case '/my-items':
        navigator.pushNamed('/my-items');
        return;
      case '/orders':
      case '/my-orders':
        navigator.pushNamed('/my-orders');
        return;
      case '/wishlist':
        navigator.pushNamed('/wishlist');
        return;
      case '/reservations':
        navigator.pushNamed('/reservations');
        return;
      case '/profile':
        navigator.pushNamed('/profile');
        return;
      case '/admin':
        navigator.pushNamed('/admin');
        return;
      default:
        navigator.pushNamed('/');
    }
  }

  static String? _extractClickAction(Map<String, dynamic> data) {
    final value = data['click_action'] ?? data['clickAction'];
    if (value == null) {
      return null;
    }
    return value.toString();
  }
}
