import 'package:flutter/material.dart';

import '../API/ReportService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'ActivityLogPage.dart';
import 'AdminCompliancePage.dart';
import 'AppBarWidget.dart';
import 'CompanyReportsPage.dart';
import 'DriverReportsPage.dart';

/// Admin landing page for the Reports tab: overall commission summary at
/// the top, with links into the per-driver and per-company breakdowns.
/// Finance/Price List/Settings used to live here too — they've moved into
/// the account-menu Settings page (tap the avatar) so this tab is reports
/// only, and the app bar is now the same avatar+bell one every other admin
/// tab uses instead of a bare Settings/Logout pair.
class ReportsHomePage extends StatefulWidget {
  final AppUser user;
  const ReportsHomePage({super.key, required this.user});

  @override
  State<ReportsHomePage> createState() => _ReportsHomePageState();
}

class _ReportsHomePageState extends State<ReportsHomePage> {
  final _service = ReportService();
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _service.fetchSummaryReport();
  }

  void _refresh() => setState(() => _summaryFuture = _service.fetchSummaryReport());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            AppBarWidget(user: widget.user, subtitle: 'Reports'),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Could not load summary',
                    style: TextStyle(color: AppColors.error),
                  );
                }

                final data = snapshot.data ?? {};
                final totalCommission = data['total_commission'] ?? 0;
                final deliveredCount = data['delivered_shipments_count'] ?? 0;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total commission earned',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalCommission.toString(),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'from $deliveredCount delivered shipment(s)',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            _ReportLinkCard(
              icon: Icons.person_outline,
              title: 'Driver Reports',
              subtitle: 'Completed vs cancelled shipments per driver',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverReportsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _ReportLinkCard(
              icon: Icons.apartment_outlined,
              title: 'Company Reports',
              subtitle: 'Shipment counts by status and top destinations',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyReportsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _ReportLinkCard(
              icon: Icons.gpp_maybe_outlined,
              title: 'Compliance',
              subtitle: 'Review driver reports and decide appeals (UC-25/26)',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminCompliancePage()),
              ),
            ),
            const SizedBox(height: 12),
            _ReportLinkCard(
              icon: Icons.history,
              title: 'Activity Log',
              subtitle: 'Audit trail of every sensitive action (Super Admin only)',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivityLogPage()),
              ),
            ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
