/// UC-30/31/32: a driver's withdrawal request.
class PayoutRequest {
  final int id;
  final int driverId;
  final String driverName;
  final double amount;
  final String status; // pending | paid | confirmed | rejected | disputed
  final String? transferReceiptFilePath;
  final String? rejectionReason;
  final String? disputeReason;
  final String createdAt;

  PayoutRequest({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.amount,
    required this.status,
    required this.transferReceiptFilePath,
    required this.rejectionReason,
    required this.disputeReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isPaidAwaitingConfirmation => status == 'paid';
  bool get isDisputed => status == 'disputed';

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      driverName: json['driver']?['name']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      status: json['status']?.toString() ?? 'pending',
      transferReceiptFilePath: json['transfer_receipt_file_path']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      disputeReason: json['dispute_reason']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
