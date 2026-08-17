import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/ProfileEditRequest.dart';

/// Admin review queue for driver work-destination change requests.
///
/// Unified Approvals redesign (2026-08-22): this page used to handle every
/// ProfileEditRequest category (documents, truck documents, company license,
/// destinations). Document/truck_document/company_license renewals now live
/// in the dedicated "Document Renewals" tab of ApprovalsPage — this page is
/// narrowed to the one category that still doesn't have a home there:
/// 'destinations' (a driver changing which countries they cover isn't a
/// document renewal, so it stays here under Documents & Permissions).
///
/// Admin Phase 5 (2026-08-20) redesign to LightColors.
class AdminProfileEditRequestsPage extends StatefulWidget {
  const AdminProfileEditRequestsPage({super.key});

  @override
  State<AdminProfileEditRequestsPage> createState() => _AdminProfileEditRequestsPageState();
}

class _AdminProfileEditRequestsPageState extends State<AdminProfileEditRequestsPage> {
  final _service = ProfileService();
  late Future<List<ProfileEditRequest>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.fetchEditRequests(category: 'destinations'));

  Future<void> _approve(ProfileEditRequest r) async {
    setState(() => _busy = true);
    final result = await _service.approveEditRequest(r.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] == true) _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  Future<void> _reject(ProfileEditRequest r) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject request', style: TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final result = await _service.rejectEditRequest(r.id, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] == true) _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  String _payloadSummary(ProfileEditRequest r) {
    switch (r.category) {
      case 'document':
        final expiry = r.payload['expiry_date'];
        return 'Type: ${r.payload['type'] ?? '—'}${expiry != null ? ' · exp. $expiry' : ''}';
      case 'destinations':
        final list = (r.payload['destinations'] as List?)?.join(', ') ?? '';
        return list;
      case 'company_license':
        return 'New trade license file submitted';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Work Destination Changes', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ProfileEditRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Could not load requests', style: TextStyle(color: LightColors.error)),
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No pending requests', style: TextStyle(color: LightColors.textSecondary))),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = items[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LightColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.userName ?? 'User #${r.userId}',
                        style: const TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(r.categoryLabel, style: const TextStyle(color: LightColors.goldMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_payloadSummary(r), style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _reject(r),
                            child: const Text('Reject', style: TextStyle(color: LightColors.error, fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _approve(r),
                            child: const Text('Approve', style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
                          ),
                        ],
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
