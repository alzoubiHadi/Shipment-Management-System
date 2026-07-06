import 'package:flutter/material.dart';

import '../API/ReportService.dart';
import '../API/config.dart';

/// Admin: shows every driver with how many shipments they've completed
/// versus cancelled, to spot reliable drivers vs problem ones at a glance.
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Driver Reports', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load report',
                    style: const TextStyle(color: AppColors.error)),
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
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drivers.length,
              itemBuilder: (context, index) {
                final d = drivers[index];
                final completed = d['completed_count'] ?? 0;
                final cancelled = d['cancelled_count'] ?? 0;
                final employmentType = d['employment_type']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_outline, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['name']?.toString() ?? '—',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (employmentType.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                employmentType,
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _CountBadge(
                        label: 'Completed',
                        value: completed,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(
                        label: 'Cancelled',
                        value: cancelled,
                        color: AppColors.error,
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
          style: const TextStyle(color: AppColors.muted, fontSize: 9),
        ),
      ],
    );
  }
}
