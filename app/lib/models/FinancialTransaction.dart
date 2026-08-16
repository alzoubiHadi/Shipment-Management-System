/// Mirrors app/Models/FinancialTransaction.php — one Ledger row. Positive
/// `amount` credited the account, negative debited it.
class FinancialTransaction {
  final String id;
  final String accountType; // 'company' | 'driver'
  final String accountId;
  final String transactionType;
  final double amount;
  final String currency;
  final double balanceBefore;
  final double balanceAfter;
  final String? referenceType;
  final String? referenceId;
  final String status; // 'posted' | 'pending' | 'rejected'
  final String? description;
  final DateTime? createdAt;

  FinancialTransaction({
    required this.id,
    required this.accountType,
    required this.accountId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.balanceBefore,
    required this.balanceAfter,
    this.referenceType,
    this.referenceId,
    required this.status,
    this.description,
    this.createdAt,
  });

  bool get isCredit => amount >= 0;

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    return FinancialTransaction(
      id: json['id']?.toString() ?? '',
      accountType: json['account_type']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'AED',
      balanceBefore: double.tryParse(json['balance_before']?.toString() ?? '') ?? 0,
      balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '') ?? 0,
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id']?.toString(),
      status: json['status']?.toString() ?? 'posted',
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

/// Presentable label for a transaction_type value, e.g. 'SHIPMENT_CHARGE' -> 'Shipment charge'.
String financialTransactionTypeLabel(String type) {
  final words = type.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}');
  return words.join(' ');
}
