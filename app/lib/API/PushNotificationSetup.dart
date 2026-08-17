import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../main.dart';
import 'NotificationBadge.dart';
import 'NotificationService.dart';
import 'config.dart';

/// Wires the firebase_messaging plugin up to the backend's existing
/// notification system: requests permission, registers/refreshes this
/// device's token via NotificationService.updateFcmToken() (server side:
/// NotificationController::updateFcmToken -> users.fcm_token, read by
/// App\Notifications\Channels\FcmChannel), and shows a lightweight banner
/// for pushes that arrive while the app is open (the OS tray already
/// handles background/terminated pushes on its own).
///
/// Call [initialize] once, after login — HomeScreen.initState() is the
/// single choke point every authenticated session passes through.
class PushNotificationSetup {
  static bool _initialized = false;

  static Future<void> initialize() async {
    // Guard against re-registering listeners every time HomeScreen is
    // rebuilt (e.g. hot navigation back to it) within the same app run.
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS/web need this to actually surface a notification tray entry
    // while the app is in the foreground; harmless no-op on Android.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Web requires a VAPID key to mint a token at all; skip quietly if it
    // hasn't been filled in yet (see kFcmWebVapidKey in config.dart) rather
    // than throwing on every app start.
    if (kIsWeb && kFcmWebVapidKey.isEmpty) {
      return;
    }

    final token = kIsWeb
        ? await messaging.getToken(vapidKey: kFcmWebVapidKey)
        : await messaging.getToken();

    if (token != null) {
      await _registerToken(token);
    }

    messaging.onTokenRefresh.listen(_registerToken);

    FirebaseMessaging.onMessage.listen(_showForegroundBanner);
  }

  static Future<void> _registerToken(String token) async {
    try {
      await NotificationService().updateFcmToken(token);
    } catch (_) {
      // Not fatal — the in-app notification center (database channel)
      // keeps working regardless of whether push registration succeeded.
    }
  }

  static void _showForegroundBanner(RemoteMessage message) {
    // Refresh the shared unread-count badge (bell on every dashboard +
    // AdminDrawer's Notifications row) so a push that arrives while the
    // app is open shows up immediately, not just after the user manually
    // reopens Notifications. Independent of whether there's a title/body
    // to show a banner for below.
    NotificationBadge.refresh();

    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          [title, body].where((s) => s != null && s.isNotEmpty).join(' — '),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
