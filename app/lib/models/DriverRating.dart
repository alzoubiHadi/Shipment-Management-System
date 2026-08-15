/// UC-23/UC-24: a single rating event for a driver — either a company
/// rating tied to one delivered shipment, or a direct Super Admin rating.
class DriverRating {
  final int id;
  final int driverId;
  final int? shipmentId;
  final String source; // company | super_admin
  final int score; // 1-5
  final String? comment;
  final String raterName;
  final String createdAt;

  DriverRating({
    required this.id,
    required this.driverId,
    required this.shipmentId,
    required this.source,
    required this.score,
    required this.comment,
    required this.raterName,
    required this.createdAt,
  });

  factory DriverRating.fromJson(Map<String, dynamic> json) {
    return DriverRating(
      id: json['id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      shipmentId: json['shipment_id'] is int
          ? json['shipment_id']
          : int.tryParse(json['shipment_id']?.toString() ?? ''),
      source: json['source']?.toString() ?? 'company',
      score: json['score'] is int
          ? json['score']
          : int.tryParse(json['score']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString(),
      raterName: json['rated_by']?['name']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
