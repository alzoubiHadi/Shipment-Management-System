import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../API/CompanyService.dart';
import '../API/PaymentOrderService.dart';
import '../API/PayoutRequestService.dart';
import '../API/config.dart';
import '../models/Company.dart';
import '../models/PaymentOrder.dart';
import '../models/PayoutRequest.dart';
import 'AdjustmentsTab.dart';

/// Finance Admin: reviews company top-up requests (UC-29) and driver
/// payout requests (UC-31), plus sets each company's credit limit (the
/// one-time setup every company needs before it can create any priced
/// offer at all — see Company::canAffordOffer()).
///
/// Admin Phase 4 (2026-08-20) redesign to LightColors — also now reachable
/// as a first-class admin bottom-nav tab (see AdminBottomNav.dart), not
/// just via the drawer/Settings.
class AdminFinancePage extends StatefulWidget {
  /// Lets a notification tap land directly on the relevant tab (0=Top-ups,
  /// 1=Payouts, 2=Credit limits, 3=Adjustments) instead of always opening
  /// on Top-ups.
  final int initialTabIndex;
  const AdminFinancePage({super.key, this.initialTabIndex = 0});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: LightColors.textPrimary),
        title: const Text('Finance', style: TextStyle(color: LightColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: LightColors.gold,
          labelColor: LightColors.goldMuted,
          unselectedLabelColor: LightColors.textSecondary,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Top-ups'),
            Tab(text: 'Payouts'),
            Tab(text: 'Credit limits'),
            Tab(text: 'Adjustments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PaymentOrdersTab(),
          _PayoutRequestsTab(),
          _CreditLimitsTab(),
          AdjustmentsTab(),
        ],
      ),
    );
  }
}

// ── Payment orders (top-ups) ────────────────────────────────────────────────

class _PaymentOrdersTab extends StatefulWidget {
  const _PaymentOrdersTab();

  @override
  State<_PaymentOrdersTab> createState() => _PaymentOrdersTabState();
}

class _PaymentOrdersTabState extends State<_PaymentOrdersTab> {
  final _service = PaymentOrderService();
  late Future<List<PaymentOrder>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.fetchAll());

  Future<void> _approve(PaymentOrder order) async {
    final result = await PaymentOrderService.approve(order.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _reject(PaymentOrder order) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject top-up', style: TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final result = await PaymentOrderService.reject(order.id, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: LightColors.gold,
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<PaymentOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: LightColors.gold));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load', style: TextStyle(color: LightColors.error)));
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                    child: Text('No top-up requests', style: TextStyle(color: LightColors.textSecondary))),
              ),
            ]);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                          child: Text(
                            o.companyName.isEmpty ? 'Company #${o.companyId}' : o.companyName,
                            style: const TextStyle(
                                color: LightColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${o.amount.toStringAsFixed(2)} AED',
                            style: const TextStyle(
                                color: LightColors.goldMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(o.status, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                    if (o.receiptFilePath.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: LightColors.surface,
                            content: Image.network(storageUrl(o.receiptFilePath)),
                          ),
                        ),
                        child: const Text('View receipt',
                            style: TextStyle(color: LightColors.navy, fontSize: 12)),
                      ),
                    ],
                    if (o.isPending) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _reject(o),
                            child: const Text('Reject',
                                style: TextStyle(color: LightColors.error, fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => _approve(o),
                            child: const Text('Approve',
                                style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
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
    );
  }
}

// ── Payout requests ──────────────────────────────────────────────────────────

class _PayoutRequestsTab extends StatefulWidget {
  const _PayoutRequestsTab();

  @override
  State<_PayoutRequestsTab> createState() => _PayoutRequestsTabState();
}

class _PayoutRequestsTabState extends State<_PayoutRequestsTab> {
  final _service = PayoutRequestService();
  late Future<List<PayoutRequest>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.fetchAll());

  Future<void> _markPaid(PayoutRequest payout) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return;

    final result = await PayoutRequestService.markPaid(
      payoutId: payout.id,
      receiptBytes: picked.files.single.bytes!,
      receiptFileName: picked.files.single.name,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _reject(PayoutRequest payout) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: const Text('Reject payout', style: TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Reason',
            hintStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject', style: TextStyle(color: LightColors.error)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    final result = await PayoutRequestService.reject(payout.id, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) _refresh();
  }

  Future<void> _resolveDispute(PayoutRequest payout, String resolution) async {
    final result = await PayoutRequestService.resolveDispute(payout.id, resolution);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '')),
    );
    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: LightColors.gold,
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<PayoutRequest>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: LightColors.gold));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load', style: TextStyle(color: LightColors.error)));
          }

          final payouts = snapshot.data ?? [];
          if (payouts.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                    child: Text('No payout requests', style: TextStyle(color: LightColors.textSecondary))),
              ),
            ]);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payouts.length,
            itemBuilder: (context, index) {
              final p = payouts[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
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
                          child: Text(
                            p.driverName.isEmpty ? 'Driver #${p.driverId}' : p.driverName,
                            style: const TextStyle(
                                color: LightColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${p.amount.toStringAsFixed(2)} AED',
                            style: const TextStyle(
                                color: LightColors.goldMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(p.status, style: const TextStyle(color: LightColors.textSecondary, fontSize: 12)),
                    if (p.disputeReason != null) ...[
                      const SizedBox(height: 4),
                      Text(p.disputeReason!,
                          style: const TextStyle(color: LightColors.error, fontSize: 12)),
                    ],
                    if (p.isPending) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _reject(p),
                            child: const Text('Reject',
                                style: TextStyle(color: LightColors.error, fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => _markPaid(p),
                            child: const Text('Mark paid (upload receipt)',
                                style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                    if (p.isDisputed) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _resolveDispute(p, 'retry'),
                            child: const Text('Retry transfer',
                                style: TextStyle(color: LightColors.navy, fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => _resolveDispute(p, 'confirm'),
                            child: const Text('Confirm it arrived',
                                style: TextStyle(color: LightColors.goldMuted, fontSize: 12)),
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
    );
  }
}

// ── Credit limits ─────────────────────────────────────────────────────────────

class _CreditLimitsTab extends StatefulWidget {
  const _CreditLimitsTab();

  @override
  State<_CreditLimitsTab> createState() => _CreditLimitsTabState();
}

class _CreditLimitsTabState extends State<_CreditLimitsTab> {
  final _service = CompanyService();
  late Future<List<Company>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _service.fetchCompaines());

  Future<void> _edit(Company company) async {
    final controller = TextEditingController(text: company.creditLimit.toStringAsFixed(2));

    final newLimit = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LightColors.surface,
        title: Text('Credit limit — ${company.name}',
            style: const TextStyle(color: LightColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: LightColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Credit limit (AED)',
            labelStyle: TextStyle(color: LightColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: LightColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('Save', style: TextStyle(color: LightColors.gold)),
          ),
        ],
      ),
    );

    if (newLimit == null) return;

    final result = await CompanyService.setCreditLimit(
      companyId: company.id,
      creditLimit: newLimit,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? ''),
        backgroundColor: result['success'] == true ? LightColors.success : LightColors.error,
      ),
    );
    if (result['success'] == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: LightColors.gold,
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Company>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: LightColors.gold));
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Could not load', style: TextStyle(color: LightColors.error)));
          }

          final companies = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              final c = companies[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: LightColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LightColors.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  color: LightColors.textPrimary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            'Balance: ${c.balance.toStringAsFixed(2)} · Limit: ${c.creditLimit.toStringAsFixed(2)} AED',
                            style: const TextStyle(color: LightColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _edit(c),
                      icon: const Icon(Icons.edit_outlined, color: LightColors.goldMuted, size: 18),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
