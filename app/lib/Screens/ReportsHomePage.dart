import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../API/ReportService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import 'ActivityLogPage.dart';
import 'AdminCompliancePage.dart';
import 'CompanyReportsPage.dart';
import 'DriverReportsPage.dart';

/// Admin landing page for the Reports tab: overall commission summary at
/// the top, with links into the per-driver and per-company breakdowns.
/// Finance/Price List/Settings used to live here too — they've moved into
/// the account-menu Settings page (tap the avatar) so this tab is reports
/// only.
///
/// Admin Phase 6 (2026-08-20) redesign to LightColors — also dropped the
/// shared dark AppBarWidget for a plain light AppBar matching every other
/// admin screen (AppBarWidget is now unreferenced anywhere in the app).
///
/// 2026-08-26 improvements: a period filter (30 Days / This Month / All
/// Time — the single most-requested missing feature per the reports
/// review), AED-formatted commission instead of a bare number, and a
/// "Shipments Overview" bar chart backed by the summary endpoint's new
/// status_overview field.
class ReportsHomePage extends StatefulWidget {
  final AppUser user;
  const ReportsHomePage({super.key, required this.user});

  @override
  State<ReportsHomePage> createState() => _ReportsHomePageState();
}

class _ReportsHomePageState extends State<ReportsHomePage> {
  final _service = ReportService();
  late Future<Map<String, dynamic>> _summaryFuture;
  String _period = 'all';

  @override
  void initState() {
    super.initState();
    _summaryFuture = _service.fetchSummaryReport(period: _period);
  }

  void _refresh() => setState(() => _summaryFuture = _service.fetchSummaryReport(period: _period));

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _summaryFuture = _service.fetchSummaryReport(period: _period);
    });
  }

  /// No `intl` dependency in this project — a plain thousands-separator
  /// formatter is enough for "AED 5,000.00" and avoids adding one just for
  /// this.
  static String _formatAed(num amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final negative = parts[0].startsWith('-');
    final digits = negative ? parts[0].substring(1) : parts[0];
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return 'AED ${negative ? '-' : ''}${buffer.toString()}.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Reports', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: LightColors.textSecondary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _PeriodChip(label: '30 Days', selected: _period == '30d', onTap: () => _setPeriod('30d')),
                const SizedBox(width: 8),
                _PeriodChip(label: 'This Month', selected: _period == 'month', onTap: () => _setPeriod('month')),
                const SizedBox(width: 8),
                _PeriodChip(label: 'All Time', selected: _period == 'all', onTap: () => _setPeriod('all')),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: LightColors.gold),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Could not load summary',
                    style: TextStyle(color: LightColors.error),
                  );
                }

                final data = snapshot.data ?? {};
                final totalCommission = num.tryParse(data['total_commission']?.toString() ?? '') ?? 0;
                final deliveredCount = data['delivered_shipments_count'] ?? 0;
                final overview = data['status_overview'];
                final delivered = overview is Map ? (int.tryParse(overview['delivered']?.toString() ?? '') ?? 0) : 0;
                final active = overview is Map ? (int.tryParse(overview['active']?.toString() ?? '') ?? 0) : 0;
                final cancelled = overview is Map ? (int.tryParse(overview['cancelled']?.toString() ?? '') ?? 0) : 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: LightColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: LightColors.border, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total commission earned',
                            style: TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatAed(totalCommission),
                            style: const TextStyle(
                              color: LightColors.goldMuted,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'from $deliveredCount delivered shipment(s)',
                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (delivered + active + cancelled > 0)
                      _ShipmentsOverviewChart(delivered: delivered, active: active, cancelled: cancelled),
                  ],
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
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? LightColors.gold : LightColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? LightColors.gold : LightColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? LightColors.textPrimary : LightColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Shipments Overview" bar chart — Delivered / Active / Cancelled counts
/// from ReportController::summary()'s status_overview field. Kept to one
/// simple chart deliberately (per the reports review's own recommendation)
/// rather than a full charting suite.
class _ShipmentsOverviewChart extends StatelessWidget {
  final int delivered;
  final int active;
  final int cancelled;
  const _ShipmentsOverviewChart({required this.delivered, required this.active, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final maxVal = [delivered, active, cancelled].reduce((a, b) => a > b ? a : b);
    final chartMax = (maxVal == 0 ? 1 : maxVal) * 1.25;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shipments Overview', style: TextStyle(color: LightColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Delivered', 'Active', 'Cancelled'];
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[i], style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(enabled: false),
                barGroups: [
                  _bar(0, delivered.toDouble(), LightColors.success),
                  _bar(1, active.toDouble(), LightColors.info),
                  _bar(2, cancelled.toDouble(), LightColors.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 34,
          borderRadius: BorderRadius.circular(6),
        ),
      ],
      showingTooltipIndicators: const [],
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
          color: LightColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LightColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LightColors.gold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: LightColors.goldMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: LightColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: LightColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: LightColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
