import 'package:flutter/material.dart';

import '../API/ComplianceReportService.dart';
import '../API/config.dart';
import '../models/ComplianceReport.dart';

/// Driver app (UC-25/26): view compliance reports filed against you and
/// appeal any that were upheld.
class DriverComplianceReportsPage extends StatefulWidget {
  const DriverComplianceReportsPage({super.key});

  @override
  State<DriverComplianceReportsPage> createState() => _DriverComplianceReportsPageState();
}

class _DriverComplianceReportsPageState extends State<DriverComplianceReportsPage> {
  final _service = ComplianceReportService();
  late Future<List<ComplianceReport>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.myReports());

  Color _statusColor(ComplianceReport r) {
    if (r.status == 'dismissed') return LightColors.success;
    if (r.status == 'upheld') return LightColors.error;
    return LightColors.gold;
  }

  Future<void> _appeal(ComplianceReport report) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Appeal this decision', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Explain why you believe this decision was wrong',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit appeal', style: TextStyle(color: LightColors.gold)),
          ),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;

    final result = await ComplianceReportService.appeal(reportId: report.id, appealText: text);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Compliance Reports', style: TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
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

            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                      child: Text('No compliance reports on file — clean record.',
                          style: TextStyle(color: LightColors.muted))),
                ),
              ]);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final r = reports[index];
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
                              r.category.replaceAll('_', ' '),
                              style: const TextStyle(
                                  color: LightColors.cream, fontWeight: FontWeight.w600),
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
                              style: TextStyle(
                                  color: _statusColor(r), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.description, style: const TextStyle(color: LightColors.muted, fontSize: 13)),
                      if (r.resultingAction != null && r.resultingAction != 'none') ...[
                        const SizedBox(height: 6),
                        Text('Action: ${r.resultingAction}',
                            style: const TextStyle(color: LightColors.error, fontSize: 12)),
                      ],
                      if (r.appealStatus != 'none') ...[
                        const SizedBox(height: 6),
                        Text('Appeal: ${r.appealStatus}',
                            style: const TextStyle(color: LightColors.info, fontSize: 12)),
                      ],
                      if (r.canAppeal) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _appeal(r),
                            child: const Text('Appeal',
                                style: TextStyle(color: LightColors.gold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
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
