import 'package:flutter/material.dart';

import '../API/ProfileService.dart';
import '../API/config.dart';
import '../models/ProfileEditRequest.dart';

/// Admin review queue for self-service profile edits that are material to
/// eligibility (driver document/destination changes, company license
/// renewals) — see ProfileController on the backend for the approval flow.
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

  void _refresh() => setState(() => _future = _service.fetchPendingEditRequests());

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
        backgroundColor: AppColors.surface,
        title: const Text('Reject request', style: TextStyle(color: AppColors.cream)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
            hintStyle: TextStyle(color: AppColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: AppColors.error)),
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('Profile Edit Requests', style: TextStyle(color: AppColors.cream)),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<ProfileEditRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Could not load requests', style: TextStyle(color: AppColors.error)),
              );
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No pending requests', style: TextStyle(color: AppColors.muted))),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.userName ?? 'User #${r.userId}',
                        style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(r.categoryLabel, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_payloadSummary(r), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _reject(r),
                            child: const Text('Reject', style: TextStyle(color: AppColors.error, fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _approve(r),
                            child: const Text('Approve', style: TextStyle(color: AppColors.gold, fontSize: 12)),
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
