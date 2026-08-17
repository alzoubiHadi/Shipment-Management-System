import 'package:flutter/material.dart';

import '../API/FinancialTransactionService.dart';
import '../API/config.dart';
import '../models/FinancialTransaction.dart';

/// Shows the Ledger — every posted financial transaction — for the
/// logged-in company or driver. "Where did every AED come from or go?"
/// (see LedgerService on the backend, the only writer of these rows).
class StatementPage extends StatefulWidget {
  const StatementPage({super.key});

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final _service = FinancialTransactionService();
  late Future<List<FinancialTransaction>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.myTransactions();
  }

  void _refresh() => setState(() => _future = _service.myTransactions());

  Color _colorFor(FinancialTransaction t) => t.isCredit ? LightColors.success : LightColors.error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColors.bg,
      appBar: AppBar(
        backgroundColor: LightColors.bg,
        elevation: 0,
        title: const Text('Statement', style: TextStyle(color: LightColors.cream)),
        iconTheme: const IconThemeData(color: LightColors.cream),
      ),
      body: RefreshIndicator(
        color: LightColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<FinancialTransaction>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: LightColors.gold));
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Could not load statement', style: TextStyle(color: LightColors.error)),
              );
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No transactions yet', style: TextStyle(color: LightColors.muted)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = transactions[index];
                final color = _colorFor(t);
                final date = t.createdAt;
                final dateLabel = date == null
                    ? ''
                    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LightColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LightColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          t.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              financialTransactionTypeLabel(t.transactionType),
                              style: const TextStyle(
                                  color: LightColors.cream, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            if ((t.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(t.description!,
                                  style: const TextStyle(color: LightColors.muted, fontSize: 11)),
                            ],
                            const SizedBox(height: 2),
                            Text(dateLabel, style: const TextStyle(color: LightColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.isCredit ? '+' : ''}${t.amount.toStringAsFixed(2)} ${t.currency}',
                            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'bal. ${t.balanceAfter.toStringAsFixed(2)}',
                            style: const TextStyle(color: LightColors.muted, fontSize: 11),
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
