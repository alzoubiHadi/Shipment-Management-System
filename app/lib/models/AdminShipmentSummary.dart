/// Admin Shipments redesign (2026-08-24): one card in the unified list —
/// merges still-matching ShipmentOffer rows (kind: 'offer') and real
/// Shipment rows (kind: 'shipment') into one shape, see
/// AdminShipmentController::summarizeOffer()/summarizeShipment().
class AdminShipmentSummary {
  final String kind; // 'offer' | 'shipment'
  final int id;
  final String trackingNumber;
  final String statusGroup; // pending | active | delivered | cancelled
  final String statusLabel;
  final String origin;
  final String destination;
  final String? orderType;
  final num? weight;
  final int? currentStage;
  final int? totalStages;
  final String? companyName;
  final String? driverName;
  final String? truckLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AdminShipmentSummary({
    required this.kind,
    required this.id,
    required this.trackingNumber,
    required this.statusGroup,
    required this.statusLabel,
    required this.origin,
    required this.destination,
    this.orderType,
    this.weight,
    this.currentStage,
    this.totalStages,
    this.companyName,
    this.driverName,
    this.truckLabel,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminShipmentSummary.fromJson(Map<String, dynamic> json) {
    num? _num(dynamic v) => v is num ? v : num.tryParse('$v');
    int? _int(dynamic v) => v is int ? v : int.tryParse('$v');

    return AdminShipmentSummary(
      kind: json['kind']?.toString() ?? 'shipment',
      id: _int(json['id']) ?? 0,
      trackingNumber: json['tracking_number']?.toString() ?? '',
      statusGroup: json['status_group']?.toString() ?? 'pending',
      statusLabel: json['status_label']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      orderType: json['order_type']?.toString(),
      weight: _num(json['weight']),
      currentStage: _int(json['current_stage']),
      totalStages: _int(json['total_stages']),
      companyName: json['company_name']?.toString(),
      driverName: json['driver_name']?.toString(),
      truckLabel: (json['truck_label']?.toString().isEmpty ?? true) ? null : json['truck_label']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
