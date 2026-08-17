import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/ShipmentServices.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Company.dart';
import '../models/Shipment.dart';
import 'AddShipmentOfferPage.dart';
import 'CompanyOffersPage.dart';
import 'CompanyProfileScreen.dart';
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

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _createShipment(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddShipmentOfferPage()));
  }

  String _blockedCreateShipmentMessage(String status) => switch (status) {
        'expiring_soon' => 'Your trade license is expiring soon — renew it to avoid losing the ability to create shipments.',
        'pending_review' => 'Your trade license renewal is still pending admin review.',
        _ => 'Your trade license has expired — renew it to create new shipments.',
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LightColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Track a Shipment', style: TextStyle(color: LightColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_greeting, ${widget.user.name.split(' ').first}',
                          style: const TextStyle(color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      const Text('Here\'s what\'s moving today',
                          style: TextStyle(color: LightColors.textSecondary, fontSize: 12)),
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
                            Text('Could not load shipments.\n${snapshot.error}',
                                textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _refresh, child: const Text('Retry')),
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
                              _StatCard(icon: Icons.local_shipping_outlined, label: 'Active Shipments', value: active, color: LightColors.navy, bg: LightColors.gold.withOpacity(0.12)),
                              _StatCard(icon: Icons.route_outlined, label: 'In Transit', value: inTransit, color: LightColors.success, bg: LightColors.successBg),
                              _StatCard(icon: Icons.pending_actions_outlined, label: 'Pending', value: pending, color: LightColors.pending, bg: LightColors.pendingBg),
                              _StatCard(icon: Icons.task_alt_rounded, label: 'Delivered', value: delivered, color: LightColors.success, bg: LightColors.successBg),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LightPrimaryButton(
                            label: complianceStatus != 'active' ? 'Create Shipment (Blocked)' : 'Create Shipment',
                            icon: Icons.add_rounded,
                            onPressed: complianceStatus != 'active'
                                ? () => ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_blockedCreateShipmentMessage(complianceStatus))),
                                    )
                                : () => _createShipment(context),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _openOffers(context),
                              icon: const Icon(Icons.handshake_outlined, size: 16, color: LightColors.goldMuted),
                              label: const Text('View My Offers', style: TextStyle(color: LightColors.goldMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent Shipments',
                                  style: TextStyle(color: LightColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                              TextButton(
                                onPressed: widget.onOpenShipments,
                                child: const Text('View All', style: TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          if (recentTop.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: Text('No shipments yet', style: TextStyle(color: LightColors.textSecondary))),
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

  String get _title => switch (status) {
        'expiring_soon' => 'Trade license expiring soon',
        'pending_review' => 'Renewal under review',
        _ => 'Action Required',
      };

  String get _body => switch (status) {
        'expiring_soon' => 'Renew it before it expires to avoid losing the ability to create new shipments.',
        'pending_review' => 'Your renewed trade license was submitted and is awaiting admin approval.',
        _ => 'Renew your Trade License to create new shipments.',
      };

  @override
  Widget build(BuildContext context) {
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
                    Text(_title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_body, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
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
                      count == 1 ? 'Track Live Shipment' : 'Track $count Live Shipments',
                      style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    const Text('On the road now — tap to view the live map',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5)),
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
