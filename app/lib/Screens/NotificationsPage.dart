import 'package:flutter/material.dart';

import '../API/NotificationBadge.dart';
import '../API/NotificationService.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/AppNotification.dart';
import '../models/Appuser.dart';
import 'AdminFinancePage.dart';
import 'ApprovalsPage.dart';
import 'Companiespage.dart';
import 'CompnayShipments.dart';
import 'DriverBalancePage.dart';
import 'DriverComplianceReportsPage.dart';
import 'DriverOffersPage.dart';
import 'Driverspage.dart';
import 'CompanyBalancePage.dart';
import 'HomeScreen.dart';
import 'ShipmentOffersAdminPage.dart';
import 'AdminShipmentsScreen.dart';

/// In-app notification center — shared by every role (driver, company,
/// admin). Always populated regardless of whether real FCM push is set up
/// (see server's NotificationController docblock).
class NotificationsPage extends StatefulWidget {
  final AppUser user;
  const NotificationsPage({super.key, required this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

enum _NotifFilter { all, unread }

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = NotificationService();
  late Future<({List<AppNotification> notifications, int unreadCount})>
      _future;
  // Driver Phase 5 (2026-08-20) added this All/Unread filter — client-side
  // only, since fetchNotifications() already returns the full list with
  // per-item isUnread flags, no new endpoint needed. Shared by every role.
  _NotifFilter _filter = _NotifFilter.all;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _service.fetchNotifications();
    });
    // Every bell/badge on screen (dashboards, AdminDrawer) listens to this
    // one shared value — see NotificationBadge.dart — so it updates live
    // the moment something here is marked read, no need to wait for the
    // user to navigate back to this page's caller.
    _future.then((result) => NotificationBadge.set(result.unreadCount)).catchError((_) {});
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
    if (mounted) _navigateFor(notification);
  }

  /// Best-effort routing to the screen the notification is about. Every
  /// notification_type below is only ever sent to one role (see the
  /// AppPushNotification call sites on the backend), so the type alone is
  /// enough to pick a destination — no extra lookup call needed.
  void _navigateFor(AppNotification notification) {
    final data = notification.data;
    Widget? target;

    switch (notification.notificationType) {
      case 'offer_matched':
        target = const DriverOffersPage();
        break;
      case 'manual_pricing_required':
        target = const ShipmentOffersAdminPage();
        break;
      case 'compliance_report_upheld':
      case 'compliance_appeal_resolved':
        target = const DriverComplianceReportsPage();
        break;
      case 'adjustment_proposed':
        target = const AdminFinancePage(initialTabIndex: 3);
        break;
      case 'payment_order_submitted':
        target = const AdminFinancePage(initialTabIndex: 0);
        break;
      case 'payment_order_approved':
      case 'payment_order_rejected':
        target = const CompanyBalancePage();
        break;
      case 'balance_credited':
      case 'dispute_resolved_against_driver':
      case 'payout_paid':
      case 'payout_rejected':
      case 'payout_dispute_resolved':
        target = const DriverBalancePage();
        break;
      case 'adjustment_resolved':
        target = widget.user.role.toLowerCase() == 'company'
            ? const CompanyBalancePage()
            : const DriverBalancePage();
        break;
      case 'profile_edit_pending':
        // Work Destinations has no standalone push-able page anymore (see
        // AdminSettingsPage's 2026-08-28 docblock note) — jump straight to
        // a fresh HomeScreen already on Approvals > Work Destinations.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              user: widget.user,
              initialTabIndex: 1,
              initialApprovalSection: ApprovalSection.destinations,
            ),
          ),
          (route) => false,
        );
        return;
      case 'profile_edit_resolved':
        target = widget.user.role.toLowerCase() == 'company'
            ? const CompanyBalancePage()
            : const DriverBalancePage();
        break;
      case 'delivery_awaiting_confirmation':
      case 'delivery_disputed':
        target = widget.user.role.toLowerCase() == 'company'
            ? Compnayshipments(user: widget.user)
            : AdminShipmentsScreen(user: widget.user);
        break;
      case 'new_registration_pending':
        target = data['type']?.toString() == 'company'
            ? Companiespage(user: widget.user)
            : Driverspage(user: widget.user);
        break;
    }

    if (target != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => target!));
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

  String _timeAgo(BuildContext context, DateTime? dt) {
    if (dt == null) return '';
    final t = AppLocalizations.of(context)!;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t.timeJustNow;
    if (diff.inMinutes < 60) return t.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return t.timeHoursAgo(diff.inHours);
    return t.timeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.cream),
        title: Text(t.notificationsTitle, style: const TextStyle(color: LightColors.cream)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(t.markAllRead, style: const TextStyle(color: LightColors.gold)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<({List<AppNotification> notifications, int unreadCount})>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: LightColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t.couldNotLoadNotifications(snapshot.error.toString()),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: LightColors.error),
                  ),
                ),
              );
            }

            final allNotifications = snapshot.data?.notifications ?? [];
            final notifications = _filter == _NotifFilter.unread
                ? allNotifications.where((n) => n.isUnread).toList()
                : allNotifications;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: t.filterAll,
                        selected: _filter == _NotifFilter.all,
                        onTap: () => setState(() => _filter = _NotifFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: t.filterUnread,
                        selected: _filter == _NotifFilter.unread,
                        onTap: () => setState(() => _filter = _NotifFilter.unread),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Text(
                            _filter == _NotifFilter.unread ? t.noUnreadNotifications : t.noNotificationsYet,
                            style: const TextStyle(color: LightColors.muted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                      ? LightColors.gold.withOpacity(0.06)
                                      : LightColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: n.isUnread
                                        ? LightColors.gold.withOpacity(0.3)
                                        : LightColors.border,
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
                                        color: LightColors.gold.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(_iconFor(n.notificationType),
                                          color: LightColors.gold, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n.title,
                                            style: TextStyle(
                                              color: LightColors.cream,
                                              fontWeight: n.isUnread ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (n.body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              n.body,
                                              style: const TextStyle(color: LightColors.muted, fontSize: 12),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            _timeAgo(context, n.createdAt),
                                            style: const TextStyle(color: LightColors.mutedLight, fontSize: 10),
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
                                          color: LightColors.gold,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? LightColors.gold.withOpacity(0.15) : LightColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? LightColors.gold : LightColors.border, width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? LightColors.gold : LightColors.muted,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
