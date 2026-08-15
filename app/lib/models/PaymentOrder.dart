/// UC-28/UC-29: a company's balance top-up request.
class PaymentOrder {
  final int id;
  final int companyId;
  final String companyName;
  final double amount;
  final String receiptFilePath;
  final String status; // pending | approved | rejected
  final String? rejectionReason;
  final String createdAt;

  PaymentOrder({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.amount,
    required this.receiptFilePath,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      companyName: json['company']?['name']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      receiptFilePath: json['receipt_file_path']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
