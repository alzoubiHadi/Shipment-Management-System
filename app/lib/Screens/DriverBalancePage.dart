import 'package:flutter/material.dart';

import '../API/PayoutRequestService.dart';
import '../API/ReportService.dart';
import '../API/config.dart';
import '../models/PayoutRequest.dart';
import 'StatementPage.dart';

/// Driver app (UC-30/31/32): view balance, request a payout, and
/// confirm/dispute one Finance Admin marked as paid.
class DriverBalancePage extends StatefulWidget {
  const DriverBalancePage({super.key});

  @override
  State<DriverBalancePage> createState() => _DriverBalancePageState();
}

class _DriverBalancePageState extends State<DriverBalancePage> {
  final _reportService = ReportService();
  final _payoutService = PayoutRequestService();

  late Future<Map<String, dynamic>> _reportFuture;
  late Future<List<PayoutRequest>> _payoutsFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _reportFuture = _reportService.fetchMyDriverReport();
      _payoutsFuture = _payoutService.myRequests();
    });
  }

  Future<void> _requestPayout(double currentBalance) async {
    final controller = TextEditingController(text: currentBalance.toStringAsFixed(2));

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Request payout', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            labelText: 'Amount (AED)',
            labelStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Request', style: TextStyle(color: LightColors.gold)),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;

    setState(() => _isBusy = true);
    final result = await PayoutRequestService.create(amount);
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _cancel(PayoutRequest payout) async {
    setState(() => _isBusy = true);
    final result = await PayoutRequestService.cancel(payout.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _confirmReceipt(PayoutRequest payout) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Confirm receipt', style: TextStyle(color: LightColors.cream)),
        content: const Text(
          'Only confirm once you have actually verified the money in your account. This closes the request and updates your balance.',
          style: TextStyle(color: LightColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I received it', style: TextStyle(color: LightColors.gold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final result = await PayoutRequestService.confirmReceipt(payout.id);
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _disputeReceipt(PayoutRequest payout) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Report not received', style: TextStyle(color: LightColors.cream)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: LightColors.cream),
          decoration: const InputDecoration(
            hintText: 'Explain what happened',
            hintStyle: TextStyle(color: LightColors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: LightColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    final result = await PayoutRequestService.disputeReceipt(payout.id, reason);
    if (!mounted) return;
    setState(() => _isBusy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.info : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return LightColors.success;
      case 'paid':
        return LightColors.gold;
      case 'disputed':
        return LightColors.error;
      case 'rejected':
        return LightColors.muted;
      default:
        return LightColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('My Balance', style: TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: LightColors.cream),
            tooltip: 'Statement',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatementPage()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: LightColors.gold,
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _reportFuture,
                  builder: (context, snapshot) {
                    final balance =
                        double.tryParse(snapshot.data?['balance']?.toString() ?? '') ?? 0;
                    final hasPending = snapshot.data?['has_pending_payout'] == true;
                    final totalEarnings =
                        double.tryParse(snapshot.data?['total_earnings_this_month']?.toString() ?? '') ?? 0;
                    final pendingAmount =
                        double.tryParse(snapshot.data?['pending_amount']?.toString() ?? '') ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBalanceCard(balance, hasPending),
                        const SizedBox(height: 14),
                        // Driver redesign Phase 4 (2026-08-17 mockup): Total
                        // Earnings / Pending Amount, distinct from the
                        // withdrawable balance above — see
                        // ReportController::driverSelf on the backend for
                        // exactly what each number means.
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStat(
                                label: 'Total Earnings',
                                sublabel: 'This month',
                                value: '${totalEarnings.toStringAsFixed(0)} AED',
                                color: LightColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStat(
                                label: 'Pending Amount',
                                sublabel: 'Awaiting confirmation',
                                value: '${pendingAmount.toStringAsFixed(0)} AED',
                                color: LightColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text('Payout history',
                    style: TextStyle(
                        color: LightColors.cream,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                FutureBuilder<List<PayoutRequest>>(
                  future: _payoutsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: CircularProgressIndicator(color: LightColors.gold)),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Text('Could not load payout history',
                          style: TextStyle(color: LightColors.error));
                    }

                    final payouts = snapshot.data ?? [];
                    if (payouts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No payout requests yet',
                            style: TextStyle(color: LightColors.muted)),
                      );
                    }

                    return Column(
                      children: [
                        for (int i = 0; i < payouts.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _PayoutCard(
                            payout: payouts[i],
                            color: _statusColor(payouts[i].status),
                            onCancel: () => _cancel(payouts[i]),
                            onConfirm: () => _confirmReceipt(payouts[i]),
                            onDispute: () => _disputeReceipt(payouts[i]),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (_isBusy)
            Container(
              color: Colors.black45,
              child: const Center(
                  child: CircularProgressIndicator(color: LightColors.gold)),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance, bool hasPending) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current balance',
              style: TextStyle(color: LightColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            '${balance.toStringAsFixed(2)} AED',
            style: const TextStyle(
              color: LightColors.gold,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (_isBusy || hasPending || balance <= 0)
                  ? null
                  : () => _requestPayout(balance),
              style: ElevatedButton.styleFrom(
                backgroundColor: LightColors.gold,
                disabledBackgroundColor:
                    LightColors.gold.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                hasPending
                    ? 'Payout already in progress'
                    : 'Request payout',
                style: const TextStyle(
                    color: LightColors.deepNavy,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (hasPending) ...[
            const SizedBox(height: 8),
            const Text(
              'You cannot accept new jobs until this payout is confirmed or rejected.',
              style: TextStyle(color: LightColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.sublabel, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
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
          Text(label, style: const TextStyle(color: LightColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sublabel, style: const TextStyle(color: LightColors.mutedLight, fontSize: 10)),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final PayoutRequest payout;
  final Color color;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onDispute;

  const _PayoutCard({
    required this.payout,
    required this.color,
    required this.onCancel,
    required this.onConfirm,
    required this.onDispute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LightColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LightColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${payout.amount.toStringAsFixed(2)} AED',
                    style: const TextStyle(
                        color: LightColors.cream, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payout.status,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (payout.rejectionReason != null) ...[
            const SizedBox(height: 6),
            Text(payout.rejectionReason!,
                style: const TextStyle(color: LightColors.error, fontSize: 11)),
          ],
          if (payout.isPending) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel',
                    style: TextStyle(color: LightColors.error, fontSize: 12)),
              ),
            ),
          ],
          if (payout.isPaidAwaitingConfirmation) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDispute,
                  child: const Text('Not received',
                      style: TextStyle(color: LightColors.error, fontSize: 12)),
                ),
                TextButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm receipt',
                      style: TextStyle(color: LightColors.gold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
