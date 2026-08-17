import 'package:flutter/foundation.dart';

import 'NotificationService.dart';

/// Single source of truth for the unread-notifications count shown next to
/// the bell icon on every role's dashboard header (Admin/Company/Driver)
/// and in AdminDrawer's Notifications row badge.
///
/// 2026-08-24 (notification system re-integration, diagnosed by user): the
/// redesign left every one of those badges either missing (Admin/Company
/// dashboards had no bell at all) or permanently stuck at 0 (AdminDrawer's
/// `unreadNotifications` constructor param was never actually passed a
/// value by HomeScreen). Rather than have each screen fetch its own count
/// and go stale independently, every bell/badge listens to this one
/// ValueNotifier — call [refresh] once after login (HomeScreen.initState),
/// after a foreground push arrives (PushNotificationSetup), and after
/// mark-read/mark-all-read (NotificationsPage) so every bell on screen
/// (they're all still mounted, e.g. sitting in HomeScreen's IndexedStack)
/// updates together, immediately — no need to wait for the user to
/// navigate back to see a fresh count.
class NotificationBadge {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      final result = await NotificationService().fetchNotifications();
      unreadCount.value = result.unreadCount;
    } catch (e) {
      // Transient network error — leave whatever count is already
      // displayed rather than flashing the badge to 0.
      debugPrint('[NotificationBadge] refresh failed: $e');
    }
  }

  /// Cheaper than a full [refresh] when a caller already fetched the
  /// notifications list itself (e.g. DriverDashboardScreen's own preview
  /// list) and just wants to sync the shared badge from that result
  /// instead of making a second network call.
  static void set(int count) => unreadCount.value = count;
}
