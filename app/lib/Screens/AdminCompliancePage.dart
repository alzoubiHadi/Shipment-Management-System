import 'package:flutter/material.dart';

import '../API/ComplianceReportService.dart';
import '../API/config.dart';
import '../models/ComplianceReport.dart';

/// Super Admin (UC-25/26): review compliance reports filed against
/// drivers and decide pending appeals.
///
/// Admin Phase 5 (2026-08-20) redesign to LightColors.
class AdminCompliancePage extends StatefulWidget {
  const AdminCompliancePage({super.key});

  @override
  State<AdminCompliancePage> createState() => _AdminCompliancePageState();
}

class _AdminCompliancePageState extends State<AdminCompliancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = ComplianceReportService();
  late Future<List<ComplianceReport>> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _future = _service.fetchAll());

  Color _statusColor(ComplianceReport r) {
    if (r.status == 'dismissed') return LightColors.success;
    if (r.status == 'upheld') return LightColors.error;
    return LightColors.goldMuted;
  }

  Future<void> _resolve(ComplianceReport report) async {
    String decision = 'dismiss';
    String resultingAction = 'warning';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: const Text('Resolve report', style: TextStyle(color: LightColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioListTile<String>(
                value: 'dismiss',
                groupValue: decision,
                activeColor: LightColors.gold,
                title: const Text('Dismiss', style: TextStyle(color: LightColors.textPrimary)),
                onChanged: (v) => setDialogState(() => decision = v ?? decision),
              ),
              RadioListTile<String>(
                value: 'uphold',
                groupValue: decision,
                activeColor: LightColors.gold,
                title: const Text('Uphold', style: TextStyle(color: LightColors.textPrimary)),
                onChanged: (v) => setDialogState(() => decision = v ?? decision),
              ),
              if (decision == 'uphold')
                DropdownButton<String>(
                  value: resultingAction,
                  dropdownColor: LightColors.surface,
                  isExpanded: true,
                  style: const TextStyle(color: LightColors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'suspension', child: Text('Suspension')),
                    DropdownMenuItem(value: 'ban', child: Text('Ban')),
                  ],
                  onChanged: (v) => setDialogState(() => resultingAction = v ?? resultingAction),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: LightColors.gold)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final result = await ComplianceReportService.resolve(
      reportId: report.id,
      decision: decision,
      resultingAction: decision == 'uphold' ? resultingAction : null,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _resolveAppeal(ComplianceReport report, String decision) async {
    final result = await ComplianceReportService.resolveAppeal(
      reportId: report.id,
      decision: decision,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Widget _reportCard(ComplianceReport r, {bool showResolve = false, bool showAppeal = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.driverName.isEmpty ? 'Driver #${r.driverId}' : r.driverName,
                  style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(r).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r.status,
                  style: TextStyle(color: _statusColor(r), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.category.replaceAll('_', ' '),
              style: const TextStyle(color: LightColors.goldMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(r.description, style: const TextStyle(color: LightColors.textSecondary, fontSize: 13)),
          if (showAppeal && r.appealText != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: LightColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.appealText!, style: const TextStyle(color: LightColors.navy, fontSize: 12)),
            ),
          ],
          if (showResolve) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _resolve(r),
                child: const Text('Resolve', style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
              ),
            ),
          ],
          if (showAppeal) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _resolveAppeal(r, 'reject'),
                  child: const Text('Reject appeal',
                      style: TextStyle(color: LightColors.error, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _resolveAppeal(r, 'accept'),
                  child: const Text('Accept appeal',
                      style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Compliance', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LightColors.gold,
          labelColor: LightColors.goldMuted,
          unselectedLabelColor: LightColors.textSecondary,
          tabs: const [
            Tab(text: 'Reports'),
            Tab(text: 'Appeals'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ComplianceReport>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Could not load reports', style: TextStyle(color: LightColors.error)));
            }

            final all = snapshot.data ?? [];
            final pending = all.where((r) => r.isPendingReview).toList();
            final appeals = all.where((r) => r.hasPendingAppeal).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                pending.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                              child: Text('No reports pending review',
                                  style: TextStyle(color: LightColors.textSecondary))),
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: pending.map((r) => _reportCard(r, showResolve: true)).toList(),
                      ),
                appeals.isEmpty
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                              child: Text('No pending appeals',
                                  style: TextStyle(color: LightColors.textSecondary))),
                        ),
                      ])
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: appeals.map((r) => _reportCard(r, showAppeal: true)).toList(),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}
