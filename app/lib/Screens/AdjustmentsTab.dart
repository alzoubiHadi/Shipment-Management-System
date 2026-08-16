import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/DriverService.dart';
import '../API/FinancialAdjustmentService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import '../models/Driver.dart';

/// Finance Admin proposes a manual balance correction here; a Super Admin
/// approves or rejects it (enforced on the backend — this tab shows the
/// same actions to everyone with access to Finance, and lets the server's
/// 403 explain itself if someone without Super Admin tries to approve).
class AdjustmentsTab extends StatefulWidget {
  const AdjustmentsTab({super.key});

  @override
  State<AdjustmentsTab> createState() => _AdjustmentsTabState();
}

class _AdjustmentsTabState extends State<AdjustmentsTab> {
  final _service = FinancialAdjustmentService();
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.fetchAll());

  Future<dynamic> _pickAccount(String accountType) async {
    if (accountType == 'company') {
      final companies = await CompanyService().fetchCompaines();
      if (!mounted) return null;
      return showModalBottomSheet<Company>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: companies
                .map((c) => ListTile(
                      title: Text(c.name, style: const TextStyle(color: AppColors.cream)),
                      subtitle: Text('Balance: ${c.balance.toStringAsFixed(2)} AED',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      onTap: () => Navigator.pop(ctx, c),
                    ))
                .toList(),
          ),
        ),
      );
    } else {
      final drivers = await DriverService().fetchDriver();
      if (!mounted) return null;
      return showModalBottomSheet<Driver>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: drivers
                .map((d) => ListTile(
                      title: Text(d.name, style: const TextStyle(color: AppColors.cream)),
                      onTap: () => Navigator.pop(ctx, d),
                    ))
                .toList(),
          ),
        ),
      );
    }
  }

  Future<void> _openProposeSheet() async {
    String accountType = 'company';
    dynamic selectedAccount;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              // viewInsets covers the keyboard; padding.bottom covers the
              // phone's own gesture/button nav bar (missing this is why the
              // Submit button rendered underneath the system nav on some
              // devices, e.g. Galaxy S24 Ultra).
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Propose Adjustment',
                    style: TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Company'),
                        selected: accountType == 'company',
                        onSelected: (_) => setSheetState(() {
                          accountType = 'company';
                          selectedAccount = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Driver'),
                        selected: accountType == 'driver',
                        onSelected: (_) => setSheetState(() {
                          accountType = 'driver';
                          selectedAccount = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await _pickAccount(accountType);
                    if (picked != null) setSheetState(() => selectedAccount = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      selectedAccount == null ? 'Choose $accountType' : selectedAccount.name,
                      style: TextStyle(
                        color: selectedAccount == null ? AppColors.muted : AppColors.cream,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  style: const TextStyle(color: AppColors.cream),
                  decoration: const InputDecoration(
                    labelText: 'Amount (AED) — negative to deduct',
                    labelStyle: TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.cream),
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    labelStyle: TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim());
                      if (selectedAccount == null || amount == null || amount == 0 || reasonCtrl.text.trim().isEmpty) {
                        return;
                      }
                      final result = await _service.propose(
                        accountType: accountType,
                        accountId: selectedAccount.id,
                        amount: amount,
                        reason: reasonCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      if (result['success'] == true) _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message']?.toString() ?? '')),
                      );
                    },
                    child: const Text('Submit for approval',
                        style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _decide(String id, bool approve) async {
    setState(() => _busy = true);
    final result = approve ? await _service.approve(id) : await _service.reject(id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result['success'] == true) _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'posted':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProposeSheet,
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add, color: AppColors.bg),
        label: const Text('Propose', style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
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
              return const Center(child: Text('Could not load adjustments', style: TextStyle(color: AppColors.error)));
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: Text('No adjustments proposed yet', style: TextStyle(color: AppColors.muted))),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = items[index];
                final status = a['status']?.toString() ?? 'pending';
                final amount = double.tryParse(a['amount']?.toString() ?? '') ?? 0;
                final color = _statusColor(status);

                return Container(
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
                              '${a['account_name'] ?? '#${a['account_id']}'} (${a['account_type']})',
                              style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(status,
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(2)} AED',
                        style: TextStyle(
                          color: amount >= 0 ? AppColors.success : AppColors.error,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((a['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(a['description'].toString(), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 4),
                      Text('Proposed by ${a['created_by'] ?? '—'}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                      if (status == 'pending') ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _busy ? null : () => _decide(a['id'].toString(), false),
                              child: const Text('Reject', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => _decide(a['id'].toString(), true),
                              child: const Text('Approve', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                            ),
                          ],
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
