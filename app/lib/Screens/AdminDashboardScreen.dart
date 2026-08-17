import 'package:flutter/material.dart';

import '../API/AdminDashboardService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'ApprovalsPage.dart';
import 'Companiespage.dart';
import 'DocumentAlertsPage.dart';
import 'Driverspage.dart';
import 'ReportsHomePage.dart';
import 'ShipmentPageAdmin.dart';

/// Admin "Home" landing screen — Phase 1 of the admin dashboard redesign
/// (2026-08-21 mockup). Lives as index 0 of HomeScreen's admin IndexedStack;
/// its hamburger button opens the outer Scaffold's AdminDrawer (no Scaffold
/// of its own, so Scaffold.of(context) resolves to HomeScreen's).
///
/// Unified Approvals Phase 6 (2026-08-22): added Pending Approvals/Document
/// Renewals/Changes Required stat cards (via [onOpenApprovals], which
/// switches HomeScreen's IndexedStack the same way [onOpenWallet] does for
/// the driver/company dashboards) and routed the Expiring/Expired document
/// alerts to the new DocumentAlertsPage instead of a generic driver list.
class AdminDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onOpenDrawer;
  final void Function(ApprovalSection section) onOpenApprovals;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
    required this.onOpenApprovals,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<AdminDashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = AdminDashboardService().fetchStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = AdminDashboardService().fetchStats();
    });
    await _statsFuture;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String get _todayLabel {
    final now = DateTime.now();
    return '${_weekdayNames[now.weekday - 1]}, ${_monthNames[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _openTab(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onOpenDrawer,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.menu_rounded, color: LightColors.textPrimary, size: 26),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, ${widget.user.name.split(' ').first}',
                                style: const TextStyle(
                                    color: LightColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(_todayLabel,
                                style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<AdminDashboardStats>(
                  future: _statsFuture,
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
                            const Icon(Icons.error_outline, color: LightColors.error, size: 32),
                            const SizedBox(height: 8),
                            Text('Could not load dashboard stats.\n${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _refresh, child: const Text('Retry')),
                          ],
                        ),
                      );
                    }

                    final stats = snapshot.data ?? AdminDashboardStats.empty();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.5,
                            children: [
                              _StatCard(
                                icon: Icons.fact_check_outlined,
                                label: 'Pending Approvals',
                                value: stats.pendingApprovals,
                                color: LightColors.pending,
                                bg: LightColors.pendingBg,
                                onTap: () => widget.onOpenApprovals(ApprovalSection.registrations),
                              ),
                              _StatCard(
                                icon: Icons.description_outlined,
                                label: 'Document Renewals',
                                value: stats.documentRenewalsPending,
                                color: LightColors.gold,
                                bg: LightColors.gold.withOpacity(0.12),
                                onTap: () => widget.onOpenApprovals(ApprovalSection.renewals),
                              ),
                              _StatCard(
                                icon: Icons.edit_note_outlined,
                                label: 'Changes Required',
                                value: stats.changesRequiredTotal,
                                color: LightColors.gold,
                                bg: LightColors.gold.withOpacity(0.12),
                                onTap: () => widget.onOpenApprovals(ApprovalSection.changes),
                              ),
                              _StatCard(
                                icon: Icons.people_alt_outlined,
                                label: 'Active Drivers',
                                value: stats.driversActive,
                                color: LightColors.success,
                                bg: LightColors.successBg,
                                onTap: () => _openTab(context, Driverspage(user: widget.user, initialFilter: 'approved')),
                              ),
                              _StatCard(
                                icon: Icons.local_shipping_outlined,
                                label: 'Available Trucks',
                                value: stats.trucksAvailable,
                                color: LightColors.navy,
                                bg: LightColors.gold.withOpacity(0.12),
                                onTap: () => _openTab(context, Driverspage(user: widget.user)),
                              ),
                              _StatCard(
                                icon: Icons.apartment_outlined,
                                label: 'Active Companies',
                                value: stats.companiesActive,
                                color: LightColors.success,
                                bg: LightColors.successBg,
                                onTap: () =>
                                    _openTab(context, Companiespage(user: widget.user, initialApprovalFilter: 'approved')),
                              ),
                              _StatCard(
                                icon: Icons.route_outlined,
                                label: 'Active Shipments',
                                value: stats.shipmentsActive,
                                color: LightColors.navy,
                                bg: LightColors.gold.withOpacity(0.12),
                                onTap: () => _openTab(context, Shipmentpageadmin(user: widget.user)),
                              ),
                              _StatCard(
                                icon: Icons.task_alt_rounded,
                                label: 'Completed This Month',
                                value: stats.shipmentsCompletedThisMonth,
                                color: LightColors.success,
                                bg: LightColors.successBg,
                                onTap: () => _openTab(context, ReportsHomePage(user: widget.user)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('Important Alerts',
                              style: TextStyle(color: LightColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          if (stats.alerts.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: LightColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: LightColors.border),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: LightColors.success, size: 20),
                                  SizedBox(width: 10),
                                  Text('All caught up — no alerts right now.',
                                      style: TextStyle(color: LightColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            )
                          else
                            ...stats.alerts.map((a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AlertTile(
                                    alert: a,
                                    onTap: () {
                                      if (a.type == 'registration_pending') {
                                        widget.onOpenApprovals(ApprovalSection.registrations);
                                      } else if (a.type == 'documents_expiring') {
                                        _openTab(context, DocumentAlertsPage(user: widget.user, status: 'expiring_soon'));
                                      } else if (a.type == 'documents_expired') {
                                        _openTab(context, DocumentAlertsPage(user: widget.user, status: 'expired'));
                                      }
                                    },
                                  ),
                                )),
                          const SizedBox(height: 12),
                        ],
                      ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
              Text('$value',
                  style: const TextStyle(color: LightColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AdminDashboardAlert alert;
  final VoidCallback onTap;

  const _AlertTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isExpiring = alert.type == 'documents_expiring' || alert.type == 'documents_expired';
    return Material(
      color: LightColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LightColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isExpiring ? LightColors.errorBg : LightColors.pendingBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isExpiring ? Icons.warning_amber_rounded : Icons.assignment_late_outlined,
                  color: isExpiring ? LightColors.error : LightColors.pending,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(alert.message,
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
