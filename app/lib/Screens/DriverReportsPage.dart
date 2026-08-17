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
              itemBuilder: (context, index) {
                final d = drivers[index];
                final completed = d['completed_count'] ?? 0;
                final cancelled = d['cancelled_count'] ?? 0;
                final employmentType = d['employment_type']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LightColors.border, width: 0.5),
                  ),
                  child: Row(
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
                              d['name']?.toString() ?? '—',
                              style: const TextStyle(
                                color: LightColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (employmentType.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                employmentType,
                                style: const TextStyle(color: LightColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _CountBadge(
                        label: 'Completed',
                        value: completed,
                        color: LightColors.success,
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(
                        label: 'Cancelled',
                        value: cancelled,
                        color: LightColors.error,
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
          style: const TextStyle(color: LightColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}
