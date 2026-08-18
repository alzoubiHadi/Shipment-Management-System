import 'package:flutter/material.dart';

import '../API/ReportService.dart';
import '../API/config.dart';

/// Admin: shows every driver with how many shipments they've completed
/// versus cancelled, to spot reliable drivers vs problem ones at a glance.
///
/// Admin Phase 6 (2026-08-20) redesign to LightColors.
class DriverReportsPage extends StatefulWidget {
  const DriverReportsPage({super.key});

  @override
  State<DriverReportsPage> createState() => _DriverReportsPageState();
}

class _DriverReportsPageState extends State<DriverReportsPage> {
  final _service = ReportService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchDriverReports();
  }

  void _refresh() => setState(() => _future = _service.fetchDriverReports());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Driver Reports', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load report',
                    style: const TextStyle(color: LightColors.error)),
              );
            }

            final drivers = snapshot.data ?? [];
            if (drivers.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No drivers yet',
                          style: TextStyle(color: LightColors.textSecondary)),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) => _DriverReportCard(driver: drivers[index]),
            );
          },
        ),
      ),
    );
  }
}

/// Enriched card (2026-08-26): the backend's /reports/drivers response
/// already includes `rating` and `compliance_status` for every driver —
/// they were just never rendered here, only Completed/Cancelled counts
/// were. Adds a rating + compliance badge row, and a "Success Rate"
/// figure computed client-side from the two counts already in the
/// response (completed / (completed + cancelled)) — no new backend field
/// needed for it.
class _DriverReportCard extends StatelessWidget {
  final Map<String, dynamic> driver;
  const _DriverReportCard({required this.driver});

  Color _complianceColor(String status) {
    switch (status) {
      case 'active':
        return LightColors.success;
      case 'expiring_soon':
      case 'pending_review':
        return LightColors.pending;
      default:
        return LightColors.error;
    }
  }

  String _complianceLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'expiring_soon':
        return 'Expiring Soon';
      case 'pending_review':
        return 'Pending Review';
      case 'action_required':
        return 'Action Required';
      case 'suspended':
        return 'Suspended';
      case 'warning':
        return 'Warning';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = (driver['completed_count'] as num?)?.toInt() ?? 0;
    final cancelled = (driver['cancelled_count'] as num?)?.toInt() ?? 0;
    final employmentType = driver['employment_type']?.toString() ?? '';
    final rating = double.tryParse(driver['rating']?.toString() ?? '');
    final compliance = driver['compliance_status']?.toString() ?? '';
    final total = completed + cancelled;
    final successRate = total > 0 ? (completed / total * 100) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: LightColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline, color: LightColors.goldMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name']?.toString() ?? '—',
                      style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (rating != null) ...[
                          const Icon(Icons.star_rounded, color: LightColors.gold, size: 13),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                        ],
                        if (compliance.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _complianceColor(compliance).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _complianceLabel(compliance),
                              style: TextStyle(color: _complianceColor(compliance), fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (employmentType.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(employmentType, style: const TextStyle(color: LightColors.textSecondary, fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _CountBadge(label: 'Completed', value: completed, color: LightColors.success),
              const SizedBox(width: 8),
              _CountBadge(label: 'Cancelled', value: cancelled, color: LightColors.error),
            ],
          ),
          if (successRate != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: LightColors.border),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Success Rate', style: TextStyle(color: LightColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                Text('${successRate.toStringAsFixed(0)}%',
                    style: const TextStyle(color: LightColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: successRate / 100,
                minHeight: 5,
                backgroundColor: LightColors.border,
                valueColor: AlwaysStoppedAnimation(
                  successRate >= 70 ? LightColors.success : (successRate >= 40 ? LightColors.pending : LightColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Text(
          label,
          style: const TextStyle(color: LightColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}
