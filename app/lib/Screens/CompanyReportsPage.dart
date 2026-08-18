import 'package:flutter/material.dart';

import '../API/ReportService.dart';
import '../API/config.dart';

/// Admin: for every company, shipment counts by status plus their most
/// frequently requested destinations.
///
/// Admin Phase 6 (2026-08-20) redesign to LightColors.
class CompanyReportsPage extends StatefulWidget {
  const CompanyReportsPage({super.key});

  @override
  State<CompanyReportsPage> createState() => _CompanyReportsPageState();
}

class _CompanyReportsPageState extends State<CompanyReportsPage> {
  final _service = ReportService();
  late Future<List<Map<String, dynamic>>> _future;

  /// Defensive parsing (2026-08-25): normally by_status/top_destinations
  /// are JSON objects, but an empty PHP array on the backend used to
  /// serialize as `[]` instead of `{}` (fixed server-side in
  /// ReportController::companies()) and crashed this exact cast with no
  /// visible error in a release build. Kept here too so a similarly-shaped
  /// bug in any future report field degrades to "no data" instead of a
  /// blank screen.
  static Map<String, dynamic> _asStringMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  @override
  void initState() {
    super.initState();
    _future = _service.fetchCompanyReports();
  }

  void _refresh() => setState(() => _future = _service.fetchCompanyReports());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Company Reports', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
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
              return const Center(
                child: Text('Could not load report', style: TextStyle(color: LightColors.error)),
              );
            }

            final companies = snapshot.data ?? [];
            if (companies.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No companies yet', style: TextStyle(color: LightColors.textSecondary)),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: companies.length,
              itemBuilder: (context, index) {
                final c = companies[index];
                final byStatus = _asStringMap(c['by_status']);
                final topDestinations = _asStringMap(c['top_destinations']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              c['name']?.toString() ?? '—',
                              style: const TextStyle(
                                color: LightColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            '${c['total_shipments'] ?? 0} shipments',
                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      if (byStatus.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: byStatus.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: LightColors.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: LightColors.border, width: 0.5),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: const TextStyle(color: LightColors.textPrimary, fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (topDestinations.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Top destinations',
                          style: TextStyle(
                            color: LightColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...topDestinations.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                        color: LightColors.textPrimary, fontSize: 13),
                                  ),
                                  Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                        color: LightColors.goldMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            )),
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
