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
    if (r.status == 'dismissed') return AppColors.success;
    if (r.status == 'upheld') return AppColors.error;
    return AppColors.gold;
  }

  Future<void> _appeal(ComplianceReport report) async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Appeal this decision', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Explain why you believe this decision was wrong',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit appeal', style: TextStyle(color: AppColors.gold)),
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
        backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Compliance Reports', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ComplianceReport>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Could not load reports', style: TextStyle(color: AppColors.error)));
            }

            final reports = snapshot.data ?? [];
            if (reports.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                      child: Text('No compliance reports on file — clean record.',
                          style: TextStyle(color: AppColors.muted))),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
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
                                  color: AppColors.cream, fontWeight: FontWeight.w600),
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
                      Text(r.description, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      if (r.resultingAction != null && r.resultingAction != 'none') ...[
                        const SizedBox(height: 6),
                        Text('Action: ${r.resultingAction}',
                            style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                      if (r.appealStatus != 'none') ...[
                        const SizedBox(height: 6),
                        Text('Appeal: ${r.appealStatus}',
                            style: const TextStyle(color: AppColors.info, fontSize: 12)),
                      ],
                      if (r.canAppeal) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _appeal(r),
                            child: const Text('Appeal',
                                style: TextStyle(color: AppColors.gold, fontSize: 12)),
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
