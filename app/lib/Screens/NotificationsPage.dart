import 'package:flutter/material.dart';

import '../API/NotificationService.dart';
import '../API/config.dart';
import '../models/AppNotification.dart';

/// In-app notification center — shared by every role (driver, company,
/// admin). Always populated regardless of whether real FCM push is set up
/// (see server's NotificationController docblock).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  late Future<({List<AppNotification> notifications, int unreadCount})>
      _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchNotifications();
    });
  }

  Future<void> _markAllRead() async {
    final ok = await _service.markAllRead();
    if (!mounted) return;
    if (ok) _refresh();
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (notification.isUnread) {
      await _service.markRead(notification.id);
      if (mounted) _refresh();
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'manual_pricing_required':
        return Icons.price_change_outlined;
      case 'offer_matched':
      case 'matched_driver':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('Notifications', style: TextStyle(color: AppColors.cream)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<({List<AppNotification> notifications, int unreadCount})>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load notifications: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            final notifications = snapshot.data?.notifications ?? [];

            if (notifications.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return InkWell(
                  onTap: () => _handleTap(n),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isUnread
                          ? AppColors.gold.withOpacity(0.06)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isUnread
                            ? AppColors.gold.withOpacity(0.3)
                            : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_iconFor(n.notificationType),
                              color: AppColors.gold, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: TextStyle(
                                  color: AppColors.cream,
                                  fontWeight:
                                      n.isUnread ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              if (n.body.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                _timeAgo(n.createdAt),
                                style: const TextStyle(
                                    color: AppColors.mutedLight, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        if (n.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
