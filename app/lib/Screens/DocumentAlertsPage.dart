import 'package:flutter/material.dart';

import '../API/AdminDashboardService.dart';
import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/Company.dart';
import '../models/Driver.dart';
import 'RequestReviewScreen.dart';

/// Dashboard alert tap-through (Unified Approvals Phase 6, 2026-08-22) — the
/// list of people affected by "Documents Expiring Soon" / "Expired
/// Documents", backed by AdminDashboardController::documentAlerts().
///
/// Deliberately NOT an approval queue: per spec, someone can show up here
/// without having submitted a renewal yet (that only happens once they
/// actually re-upload, at which point they move to Approvals > Document
/// Renewals instead). Tapping a row opens the same RequestReviewScreen
/// used everywhere else in admin — it already renders full driver/company
/// info + documents, doubling as a read-only detail viewer here since
/// there's no separate profile-by-id endpoint.
class DocumentAlertsPage extends StatefulWidget {
  final AppUser user;
  final String status; // 'expiring_soon' | 'expired'

  const DocumentAlertsPage({super.key, required this.user, required this.status});

  @override
  State<DocumentAlertsPage> createState() => _DocumentAlertsPageState();
}

class _DocumentAlertsPageState extends State<DocumentAlertsPage> {
  late Future<_AlertsData> _future;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  Future<_AlertsData> _load() async {
    final results = await Future.wait([
      AdminDashboardService().fetchDocumentAlerts(widget.status),
      DriverService().fetchDriver(),
      CompanyService().fetchCompaines(),
    ]);
    return _AlertsData(
      items: results[0] as List<AdminDocumentAlertItem>,
      drivers: {for (final d in results[1] as List<Driver>) d.id: d},
      companies: {for (final c in results[2] as List<Company>) c.id: c},
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _openSubject(AdminDocumentAlertItem item, _AlertsData data) {
    final screen = item.subjectType == 'company'
        ? (data.companies[item.subjectId] != null ? RequestReviewScreen.company(data.companies[item.subjectId]!) : null)
        : (data.drivers[item.subjectId] != null ? RequestReviewScreen.driver(data.drivers[item.subjectId]!) : null);
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find this record')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String get _title => widget.status == 'expired' ? 'Expired Documents' : 'Documents Expiring Soon';

  String _documentTypeLabel(String raw) {
    final base = raw.startsWith('truck_') ? raw.substring(6) : raw;
    final prefix = raw.startsWith('truck_') ? 'Truck ' : '';
    final label = switch (base) {
      'license' => 'License',
      'passport' => 'Passport',
      'residency' => 'Residency',
      'insurance' => 'Insurance',
      'technical_inspection' => 'Technical Inspection',
      'trade_license' => 'Trade License',
      _ => base,
    };
    return '$prefix$label';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: Text(_title, style: const TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: LightColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  hintStyle: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: LightColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: LightColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LightColors.gold)),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<_AlertsData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: LightColors.gold));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Could not load list.\n${snapshot.error}',
                          textAlign: TextAlign.center, style: const TextStyle(color: LightColors.textSecondary)),
                    );
                  }

                  final data = snapshot.data!;
                  var items = data.items;
                  if (_searchQuery.isNotEmpty) {
                    items = items.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
                  }

                  if (items.isEmpty) {
                    return RefreshIndicator(
                      color: LightColors.gold,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: Text('Nothing here right now.', style: TextStyle(color: LightColors.textSecondary))),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: LightColors.gold,
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final isCompany = item.subjectType == 'company';
                        return Material(
                          color: LightColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openSubject(item, data),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: LightColors.border)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.status == 'expired' ? LightColors.errorBg : LightColors.pendingBg,
                                    ),
                                    child: Icon(
                                      isCompany ? Icons.apartment_outlined : Icons.person_outline,
                                      color: widget.status == 'expired' ? LightColors.error : LightColors.pending,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: LightColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text('${_documentTypeLabel(item.documentType)} · exp. ${item.expiryDate ?? '—'}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 11.5)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: LightColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsData {
  final List<AdminDocumentAlertItem> items;
  final Map<String, Driver> drivers;
  final Map<String, Company> companies;

  _AlertsData({required this.items, required this.drivers, required this.companies});
}
