import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/PaymentOrderService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import '../models/PaymentOrder.dart';
import 'StatementPage.dart';

/// Company app (UC-28): view current balance/credit limit and submit /
/// track top-up requests.
class CompanyBalancePage extends StatefulWidget {
  const CompanyBalancePage({super.key});

  @override
  State<CompanyBalancePage> createState() => _CompanyBalancePageState();
}

class _CompanyBalancePageState extends State<CompanyBalancePage> {
  final _companyService = CompanyService();
  final _orderService = PaymentOrderService();

  late Future<Company> _companyFuture;
  late Future<List<PaymentOrder>> _ordersFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _companyFuture = _companyService.fetchMyCompany();
      _ordersFuture = _orderService.myOrders();
    });
  }

  Future<void> _submitTopUp() async {
    final amountController = TextEditingController();
    PlatformFile? pickedFile;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightColors.surface,
          title: const Text('Top up balance',
              style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: LightColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Amount (AED)',
                  labelStyle: TextStyle(color: LightColors.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );
                  if (result != null) {
                    setDialogState(() => pickedFile = result.files.single);
                  }
                },
                icon: const Icon(Icons.upload_file, color: LightColors.goldMuted),
                label: Text(
                  pickedFile == null
                      ? 'Attach bank transfer receipt'
                      : pickedFile!.name,
                  style: const TextStyle(color: LightColors.goldMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit', style: TextStyle(color: LightColors.goldMuted, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (pickedFile == null || pickedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach a receipt file')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await _orderService.create(
      amount: amount,
      receiptBytes: pickedFile!.bytes!,
      receiptFileName: pickedFile!.name,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor:
            result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return LightColors.success;
      case 'rejected':
        return LightColors.error;
      default:
        return LightColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('My Balance', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: LightColors.textPrimary),
            tooltip: 'Statement',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatementPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _submitTopUp,
        backgroundColor: LightColors.gold,
        icon: const Icon(Icons.add, color: LightColors.textPrimary),
        label: const Text('Top up',
            style: TextStyle(color: LightColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            FutureBuilder<Company>(
              future: _companyFuture,
              builder: (context, snapshot) {
                final balance = snapshot.data?.balance ?? 0;
                final creditLimit = snapshot.data?.creditLimit ?? 0;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: LightColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current balance',
                          style: TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${balance.toStringAsFixed(2)} AED',
                        style: TextStyle(
                          color: balance < 0 ? LightColors.error : LightColors.goldMuted,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Credit limit: ${creditLimit.toStringAsFixed(2)} AED',
                        style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Top-up history',
                style: TextStyle(
                    color: LightColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            FutureBuilder<List<PaymentOrder>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: CircularProgressIndicator(color: LightColors.gold)),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Could not load history',
                      style: TextStyle(color: LightColors.error));
                }

                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No top-up requests yet',
                        style: TextStyle(color: LightColors.textSecondary)),
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < orders.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: LightColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LightColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${orders[i].amount.toStringAsFixed(2)} AED',
                                      style: const TextStyle(
                                          color: LightColors.textPrimary,
                                          fontWeight: FontWeight.w700)),
                                  if (orders[i].rejectionReason != null) ...[
                                    const SizedBox(height: 4),
                                    Text(orders[i].rejectionReason!,
                                        style: const TextStyle(
                                            color: LightColors.error, fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(orders[i].status)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                orders[i].status,
                                style: TextStyle(
                                    color: _statusColor(orders[i].status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
