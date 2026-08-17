import 'package:flutter/material.dart';

import '../API/NotificationBadge.dart';
import '../API/config.dart';

/// Bell icon + live numeric unread-count badge, shared by every role's
/// dashboard header (Admin/Company/Driver) — see NotificationBadge.dart's
/// docblock for why this reads from one shared ValueNotifier instead of
/// fetching its own count.
class FmsNotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  final Color iconColor;

  const FmsNotificationBell({
    super.key,
    required this.onTap,
    this.iconColor = LightColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationBadge.unreadCount,
      builder: (context, count, _) {
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.notifications_outlined, color: iconColor, size: 24),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(color: LightColors.error, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, height: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
