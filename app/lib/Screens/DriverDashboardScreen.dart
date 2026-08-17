import 'package:flutter/material.dart';

import '../API/NotificationService.dart';
import '../API/ReportService.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/AppNotification.dart';
import '../models/Appuser.dart';
import '../models/Shipment.dart';
import 'DriverDocumentsPage.dart';
import 'NotificationsPage.dart';
import 'ShipmentTrackingPage.dart';
import 'UserHomePage.dart';

/// Blank-Home-screen bug fix (2026-08-24): Laravel's `decimal:N` Eloquent
/// cast serializes to JSON as a STRING ("1500.00"), not a number, even
/// though PHP-side arithmetic on it works fine — a well-known Laravel
/// gotcha. `ReportController::driverSelf()` returns `'balance' =>
/// $driver->balance` straight off that decimal-cast attribute, unlike
/// `pending_amount`/`total_earnings_this_month` which are explicitly
/// `(float)`-cast. The old `(report['balance'] as num?)?.toDouble()` used
/// Dart's `as` cast, which THROWS (does not just return null) when the
/// value is a non-null String — so the instant `_reportFuture` resolved,
/// this FutureBuilder's builder() threw mid-build. Flutter's default
/// ErrorWidget renders as a plain grey box (not the red debug screen) in
/// release/profile mode, which is exactly what was reported: header +
/// bottom nav fine, everything in between a blank grey rectangle. Fixed by
/// tolerating either a String or a num here, rather than only patching the
/// backend — any other decimal-cast field returned as a string in the
/// future hits the same safe path instead of crashing the same way again.
double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// Driver "Home" — driver redesign Phase 1 (2026-08-17 mockup). Dark-themed
/// (AppColors), matching the mockup itself and the user's request to
/// improve the existing workflow rather than re-theme it.
///
/// Replaces UserHomePage.dart as the Home tab. UserHomePage.dart isn't
/// deleted — it's still a working "my shipments" list, just temporarily
/// reached via "View All" here until Phase 3 rebuilds it with the
/// mockup's All/Active/Completed/Cancelled tabs.
class DriverDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onOpenWallet;

  const DriverDashboardScreen({super.key, required this.user, this.onOpenWallet});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  late Future<List<Shipment>> _shipmentsFuture;
  late Future<Map<String, dynamic>> _reportFuture;
  late Future<({List<AppNotification> notifications, int unreadCount})> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _shipmentsFuture = ShipmentService().fetchShipments();
    _reportFuture = ReportService().fetchMyDriverReport();
    _notificationsFuture = NotificationService().fetchNotifications();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_shipmentsFuture, _reportFuture, _notificationsFuture]);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _openNotifications() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(user: widget.user)));
  }

  void _openMyShipments() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserHomePage(user: widget.user)));
  }

  void _openTracking(Shipment s) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentTrackingPage(shipment: s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.gold,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.15)),
                        child: const Icon(Icons.person_rounded, color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, ${widget.user.name.split(' ').first}',
                                style: const TextStyle(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.w700)),
                            const Text('Drive safe!', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      FutureBuilder<({List<AppNotification> notifications, int unreadCount})>(
                        future: _notificationsFuture,
                        builder: (context, snapshot) {
                          final unread = snapshot.data?.unreadCount ?? 0;
                          return _NotificationBell(unreadCount: unread, onTap: _openNotifications);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _reportFuture,
                  builder: (context, reportSnapshot) {
                    final report = reportSnapshot.data ?? const {};
                    final balance = _toDouble(report['balance']);

                    return FutureBuilder<List<Shipment>>(
                      future: _shipmentsFuture,
                      builder: (context, shipSnapshot) {
                        if (shipSnapshot.connectionState == ConnectionState.waiting && reportSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                          );
                        }
                        if (shipSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 32),
                                const SizedBox(height: 8),
                                Text('Could not load your shipments.\n${shipSnapshot.error}',
                                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _refresh, child: const Text('Retry')),
                              ],
                            ),
                          );
                        }

                        final shipments = shipSnapshot.data ?? [];
                        final upcoming = shipments.where((s) => s.status == 0).length;
                        final active = shipments.where((s) => s.status == 1 || s.status == 2 || s.status == 5).length;
                        final completed = shipments.where((s) => s.status == 3).length;
                        final pendingAmount = _toDouble(report['pending_amount']);

                        // "Current Trip" — prefer an in-progress one; fall
                        // back to the next upcoming pickup if nothing's
                        // moving yet.
                        Shipment? current;
                        for (final s in shipments) {
                          if (s.status == 1 || s.status == 2 || s.status == 5) {
                            current = s;
                            break;
                          }
                        }
                        current ??= shipments.cast<Shipment?>().firstWhere((s) => s!.status == 0, orElse: () => null);

                        final complianceStatus = report['compliance_status']?.toString() ?? 'active';

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (complianceStatus != 'active') ...[
                                _ComplianceBanner(
                                  status: complianceStatus,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const DriverDocumentsPage()),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              if (reportSnapshot.hasError) ...[
                                _InlineErrorNotice(
                                  message: 'Could not load wallet balance — showing AED 0 for now.',
                                  onRetry: _refresh,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _WalletCard(balance: balance, onTap: widget.onOpenWallet),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Quick Overview', style: TextStyle(color: AppColors.cream, fontSize: 15, fontWeight: FontWeight.w700)),
                                  TextButton(
                                    onPressed: _openMyShipments,
                                    child: const Text('View All', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.7,
                                children: [
                                  _StatCard(icon: Icons.route_outlined, label: 'Active Trips', value: '$active', color: AppColors.info),
                                  _StatCard(icon: Icons.schedule_outlined, label: 'Upcoming', value: '$upcoming', color: AppColors.gold),
                                  _StatCard(icon: Icons.task_alt_rounded, label: 'Completed', value: '$completed', color: AppColors.success),
                                  _StatCard(icon: Icons.hourglass_bottom_rounded, label: 'Pending Payments', value: 'AED ${pendingAmount.toStringAsFixed(0)}', color: AppColors.error),
                                ],
                              ),
                              if (current != null) ...[
                                const SizedBox(height: 20),
                                const Text('Current Trip', style: TextStyle(color: AppColors.cream, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                _CurrentTripCard(shipment: current, onViewTracking: () => _openTracking(current!)),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Recent Notifications', style: TextStyle(color: AppColors.cream, fontSize: 15, fontWeight: FontWeight.w700)),
                                  TextButton(
                                    onPressed: _openNotifications,
                                    child: const Text('View All', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FutureBuilder<({List<AppNotification> notifications, int unreadCount})>(
                                future: _notificationsFuture,
                                builder: (context, notifSnapshot) {
                                  final items = (notifSnapshot.data?.notifications ?? []).take(2).toList();
                                  if (items.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Text('No notifications yet', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                                    );
                                  }
                                  return Column(
                                    children: [
                                      for (int i = 0; i < items.length; i++) ...[
                                        if (i > 0) const SizedBox(height: 8),
                                        _NotificationPreviewTile(notification: items[i], onTap: _openNotifications),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _NotificationBell({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined, color: AppColors.cream, size: 24),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown whenever Driver.compliance_status != 'active' — per the 2026-08-23
/// Compliance/Approval separation spec, matching/accepting a new shipment
/// strictly requires compliance_status === 'active', so any of the other
/// three values (action_required/expiring_soon/pending_review) already
/// blocks new jobs and deserves a heads-up here, with copy/urgency tuned
/// per state. The driver can still log in and use everything else — this
/// is a nudge, not a blocking screen — tapping goes straight to My
/// Documents to renew.
class _ComplianceBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _ComplianceBanner({required this.status, required this.onTap});

  Color get _color => switch (status) {
        'expiring_soon' => AppColors.gold,
        'pending_review' => AppColors.info,
        _ => AppColors.error,
      };

  IconData get _icon => switch (status) {
        'expiring_soon' => Icons.schedule_rounded,
        'pending_review' => Icons.hourglass_top_rounded,
        _ => Icons.warning_amber_rounded,
      };

  String get _title => switch (status) {
        'expiring_soon' => 'Document expiring soon',
        'pending_review' => 'Renewal under review',
        _ => 'Action needed',
      };

  String get _body => switch (status) {
        'expiring_soon' => 'A document is expiring soon — renew it now to avoid losing new shipment offers.',
        'pending_review' => 'Your renewal was submitted and is awaiting admin approval — you won\'t receive new shipment offers until it\'s approved.',
        _ => 'A document has expired — renew it now to keep receiving new shipment offers.',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _color.withOpacity(0.4))),
          child: Row(
            children: [
              Icon(_icon, color: _color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title, style: const TextStyle(color: AppColors.cream, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_body, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small, non-blocking notice for when [_reportFuture] fails — the rest of
/// the dashboard (Shipments, Current Trip, Notifications, which all come
/// from separate futures) keeps rendering normally either way; only the
/// wallet-derived numbers (balance/pending amount) fall back to 0.
class _InlineErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineErrorNotice({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 11.5))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: const Text('Retry', style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final double balance;
  final VoidCallback? onTap;
  const _WalletCard({required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wallet Balance', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('AED ${balance.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.gold, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CurrentTripCard extends StatelessWidget {
  final Shipment shipment;
  final VoidCallback onViewTracking;
  const _CurrentTripCard({required this.shipment, required this.onViewTracking});

  Color get _color => switch (shipment.status) {
        0 => AppColors.gold,
        1 => AppColors.info,
        2 => AppColors.success,
        3 => AppColors.success,
        4 => AppColors.error,
        5 => AppColors.error,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_shipping_rounded, color: _color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SH-${shipment.id}', style: const TextStyle(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text('${shipment.origin} → ${shipment.destination}',
                        overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel(shipment.status), style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onViewTracking,
              icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.bg),
              label: const Text('View Tracking', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPreviewTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationPreviewTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notification.isUnread ? AppColors.gold.withOpacity(0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: notification.isUnread ? AppColors.gold.withOpacity(0.3) : AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.notifications_outlined, color: AppColors.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.cream, fontSize: 12.5, fontWeight: notification.isUnread ? FontWeight.w700 : FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}
