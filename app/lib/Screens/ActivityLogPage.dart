import 'package:flutter/material.dart';

import '../API/ActivityLogService.dart';
import '../API/config.dart';
import '../models/ActivityLogEntry.dart';

/// NFR (Security): "سجل تدقيق لكل إجراء حساس" — read-only audit trail of
/// every sensitive admin/finance action (approvals, rejections,
/// suspensions, financial approvals, permission changes, ...).
/// Super Admin only; the backend also enforces this (403 for anyone else).
class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final _service = ActivityLogService();
  late Future<List<ActivityLogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLogs();
  }

  void _refresh() => setState(() => _future = _service.fetchLogs());

  IconData _iconFor(String action) {
    if (action.contains('suspend')) return Icons.block;
    if (action.contains('activat') || action.contains('reactivat')) return Icons.refresh;
    if (action.contains('approv')) return Icons.check_circle_outline;
    if (action.contains('reject')) return Icons.cancel_outlined;
    if (action.contains('delet')) return Icons.delete_outline;
    if (action.contains('permission')) return Icons.admin_panel_settings_outlined;
    if (action.contains('payout') || action.contains('payment') || action.contains('credit')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Activity Log', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ActivityLogEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString().contains('403')
                        ? 'Only the Super Admin can view the audit log.'
                        : 'Could not load the activity log.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No activity recorded yet', style: TextStyle(color: AppColors.muted)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconFor(log.action), color: AppColors.gold, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.description,
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.userName ?? 'System'} · ${log.action} · ${log.createdAt}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
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
