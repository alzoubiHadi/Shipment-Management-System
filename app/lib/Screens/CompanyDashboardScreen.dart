import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../l10n/app_localizations.dart';
import '../models/Appuser.dart';
import '../models/Company.dart';
import '../models/Shipment.dart';
import '../widgets/FmsNotificationBell.dart';
import 'AddShipmentOfferPage.dart';
import 'CompanyOffersPage.dart';
import 'CompanyProfileScreen.dart';
import 'NotificationsPage.dart';
import 'ShipmentDetailsPageCompany.dart';
import 'ShipmentTrackingPage.dart';
import 'register_shared.dart';

/// Company "Home" landing screen — start of the company-side redesign
/// (2026-08-17 mockup: "Transport Partner" branding kept as FMS per the
/// user's explicit choice). Mirrors AdminDashboardScreen's structure/style
/// for visual consistency between the two redesigned areas of the app.
///
/// "Create Shipment" in the mockup maps to this app's real creation flow —
/// AddShipmentOfferPage (a company posts a shipment OFFER; it only becomes
/// a real Shipment once a driver accepts, per the existing UC-11 flow).
/// The mockup's direct "Create Shipment" wizard will be Phase 2's redesign
/// of that same screen, not a new separate flow.
///
/// The mockup's bottom nav doesn't have a separate "Offers" tab (Home/
/// Shipments/Create/Finance/Profile only), but CompanyOffersPage (the list
/// of posted offers and their driver responses) is real, live functionality
/// that shouldn't just disappear — kept reachable via a link on this
/// dashboard until Phase 3 decides whether it folds into My Shipments.
class CompanyDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onOpenShipments;

  const CompanyDashboardScreen({super.key, required this.user, this.onOpenShipments});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  late Future<List<Shipment>> _future;
  late Future<Company> _companyFuture;

  @override
  void initState() {
    super.initState();
    _future = ShipmentService().fetchShipmentscompany();
    _companyFuture = CompanyService().fetchMyCompany();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = ShipmentService().fetchShipmentscompany();
      _companyFuture = CompanyService().fetchMyCompany();
    });
    await Future.wait([_future, _companyFuture]);
  }

  String _greeting(AppLocalizations t) {
    final hour = DateTime.now().hour;
    if (hour < 12) return t.greetingMorning;
    if (hour < 18) return t.greetingAfternoon;
    return t.greetingEvening;
  }

  void _createShipment(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddShipmentOfferPage()));
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(user: widget.user)));
  }

  String _blockedCreateShipmentMessage(AppLocalizations t, String status) => switch (status) {
        'expiring_soon' => t.blockedCreateShipmentExpiring,
        'pending_review' => t.blockedCreateShipmentPending,
        _ => t.blockedCreateShipmentExpired,
      };

  void _openOffers(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CompanyOffersPage(user: widget.user)));
  }

  void _openDetails(BuildContext context, Shipment s) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentDetailsPageCompany(shipment: s)));
  }

  // 2026-08-17 feedback: tracking/the live map was buried 3 taps deep
  // (Shipments tab -> tap a shipment -> "View Tracking Timeline"). Home is
  // the main screen, so a live shipment now gets one-tap access straight
  // to ShipmentTrackingPage from here.
  void _trackLive(BuildContext context, List<Shipment> live) {
    if (live.length == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentTrackingPage(shipment: live.first, readOnly: true)));
      return;
    }
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(t.trackAShipmentTitle, style: const TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: live.map((s) {
                  return ListTile(
                    leading: const Icon(Icons.local_shipping_outlined, color: LightColors.goldMuted),
                    title: Text('SH-${s.id}', style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('${s.origin} → ${s.destination}', style: const TextStyle(color: LightColors.textSecondary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentTrackingPage(shipment: s, readOnly: true)));
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      color: LightColors.bg,
      child: SafeArea(
        child: RefreshIndicator(
          color: LightColors.gold,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.greetingComma(_greeting(t), widget.user.name.split(' ').first),
                                style: const TextStyle(
                                    color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(t.companyHomeSubtitle,
                                style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      FmsNotificationBell(onTap: () => _openNotifications(context)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<Company>(
                  future: _companyFuture,
                  builder: (context, companySnapshot) {
                    final complianceStatus = companySnapshot.data?.complianceStatus ?? 'active';
                    return FutureBuilder<List<Shipment>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: LightColors.gold)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: LightColors.error, size: 32),
                            const SizedBox(height: 8),
                            Text(t.couldNotLoadShipments(snapshot.error.toString()),
                                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _refresh, child: Text(t.commonRetry)),
                          ],
                        ),
                      );
                    }

                    final shipments = snapshot.data ?? [];
                    final liveShipments = shipments.where((s) => s.status == 1 || s.status == 2 || s.status == 5).toList();
                    final active = shipments.where((s) => s.status == 0 || s.status == 1 || s.status == 2 || s.status == 5).length;
                    final inTransit = shipments.where((s) => s.status == 1).length;
                    final pending = shipments.where((s) => s.status == 0).length;
                    final delivered = shipments.where((s) => s.status == 3).length;

                    final recent = [...shipments]
                      ..sort((a, b) => b.created_at.compareTo(a.created_at));
                    final recentTop = recent.take(3).toList();

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
                                MaterialPageRoute(builder: (_) => CompanyProfileScreen(user: widget.user)),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (liveShipments.isNotEmpty) ...[
                            _LiveTrackingBanner(
                              count: liveShipments.length,
                              onTap: () => _trackLive(context, liveShipments),
                            ),
                            const SizedBox(height: 16),
                          ],
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: [
                              _StatCard(icon: Icons.local_shipping_outlined, label: t.statActiveShipments, value: active, color: LightColors.navy, bg: LightColors.gold.withOpacity(0.12)),
                              _StatCard(icon: Icons.route_outlined, label: t.statInTransit, value: inTransit, color: LightColors.success, bg: LightColors.successBg),
                              _StatCard(icon: Icons.pending_actions_outlined, label: t.statPending, value: pending, color: LightColors.pending, bg: LightColors.pendingBg),
                              _StatCard(icon: Icons.task_alt_rounded, label: t.statDelivered, value: delivered, color: LightColors.success, bg: LightColors.successBg),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LightPrimaryButton(
                            label: complianceStatus != 'active' ? t.createShipmentBlocked : t.createShipment,
                            icon: Icons.add_rounded,
                            onPressed: complianceStatus != 'active'
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_blockedCreateShipmentMessage(t, complianceStatus))),
                                    )
                                : () => _createShipment(context),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _openOffers(context),
                              icon: const Icon(Icons.handshake_outlined, size: 16, color: LightColors.goldMuted),
                              label: Text(t.viewMyOffers, style: const TextStyle(color: LightColors.goldMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.recentShipments,
                                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                              TextButton(
                                onPressed: widget.onOpenShipments,
                                child: Text(t.viewAll, style: const TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          if (recentTop.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text(t.noShipmentsYet, style: const TextStyle(color: LightColors.textSecondary))),
                            )
                          else
                            ...recentTop.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RecentShipmentTile(shipment: s, onTap: () => _openDetails(context, s)),
                                )),
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

/// Shown whenever Company.compliance_status != 'active' — per the
/// 2026-08-23 spec Create Shipment strictly requires 'active', so
/// 'expiring_soon'/'pending_review' block it too, not only an outright-
/// expired license. The company keeps full access to existing shipments/
/// tracking/finance/documents/profile either way — only Create Shipment is
/// blocked (see the gated LightPrimaryButton above and
/// ShipmentOfferController::create()'s matching 403 on the backend). Copy
/// for 'action_required' is the exact spec wording: "Action Required —
/// Renew your Trade License to create new shipments."
class _ComplianceBanner extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _ComplianceBanner({required this.status, required this.onTap});

  Color get _color => switch (status) {
        'expiring_soon' => LightColors.gold,
        'pending_review' => LightColors.navy,
        _ => LightColors.error,
      };

  Color get _bg => switch (status) {
        'expiring_soon' => LightColors.gold.withOpacity(0.12),
        'pending_review' => LightColors.navy.withOpacity(0.08),
        _ => LightColors.errorBg,
      };

  IconData get _icon => switch (status) {
        'expiring_soon' => Icons.schedule_rounded,
        'pending_review' => Icons.hourglass_top_rounded,
        _ => Icons.warning_amber_rounded,
      };

  String _title(AppLocalizations t) => switch (status) {
        'expiring_soon' => t.companyComplianceExpiringTitle,
        'pending_review' => t.companyCompliancePendingTitle,
        _ => t.companyComplianceActionTitle,
      };

  String _body(AppLocalizations t) => switch (status) {
        'expiring_soon' => t.companyComplianceExpiringBody,
        'pending_review' => t.companyCompliancePendingBody,
        _ => t.companyComplianceActionBody,
      };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Material(
      color: _bg,
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
                    Text(_title(t), style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_body(t), style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTrackingBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _LiveTrackingBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Material(
      color: LightColors.navy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1 ? t.trackLiveShipmentOne : t.trackLiveShipmentsMany(count),
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(t.onTheRoadNow,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
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
  final int value;
  final Color color;
  final Color bg;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text('$value', style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _RecentShipmentTile extends StatelessWidget {
  final Shipment shipment;
  final VoidCallback onTap;
  const _RecentShipmentTile({required this.shipment, required this.onTap});

  Color get _color => switch (shipment.status) {
        0 => LightColors.pending,
        1 => LightColors.navy,
        2 => LightColors.goldMuted,
        3 => LightColors.success,
        4 => LightColors.error,
        5 => LightColors.error,
        _ => LightColors.textSecondary,
      };

  Color get _bg => switch (shipment.status) {
        0 => LightColors.pendingBg,
        3 => LightColors.successBg,
        4 => LightColors.errorBg,
        5 => LightColors.errorBg,
        _ => LightColors.gold.withOpacity(0.12),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                child: Icon(shipment.icon, color: _color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SH-${shipment.id}', style: const TextStyle(color: LightColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text('${shipment.origin} → ${shipment.destination}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel(shipment.status), style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
