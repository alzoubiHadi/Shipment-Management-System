class ShipmentOffer {
  final int id;
  final int companyId;
  final String companyName;
  final String origin;
  final double? originLat;
  final double? originLng;
  final String destination;
  final String weight;
  final String description;
  final bool needsPermit;
  final bool isHazardous;
  final bool isFragile;
  final String orderType; // 'internal' or 'external'
  final String requiredTruckType;
  final String priceToDriver;
  final String priceToClient;
  final String? pricingMode; // 'auto', 'manual', or null
  // pending, awaiting_manual_price, escalated, accepted, cancelled
  final String status;
  final int eligibleDriversCount;
  final String createdAt;

  ShipmentOffer({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.origin,
    this.originLat,
    this.originLng,
    required this.destination,
    required this.weight,
    required this.description,
    required this.needsPermit,
    required this.isHazardous,
    required this.isFragile,
    required this.orderType,
    required this.requiredTruckType,
    required this.priceToDriver,
    required this.priceToClient,
    required this.pricingMode,
    required this.status,
    required this.eligibleDriversCount,
    required this.createdAt,
  });

  bool get isAwaitingManualPrice => status == 'awaiting_manual_price';
  bool get isEscalated => status == 'escalated';
  bool get isPending => status == 'pending';

  factory ShipmentOffer.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) => v == true || v == 1 || v == '1';

    return ShipmentOffer(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      companyName: json['company']?['name']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      originLat: json['origin_lat'] != null ? double.tryParse(json['origin_lat'].toString()) : null,
      originLng: json['origin_lng'] != null ? double.tryParse(json['origin_lng'].toString()) : null,
      destination: json['destination']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      needsPermit: asBool(json['needs_permit']),
      isHazardous: asBool(json['is_hazardous']),
      isFragile: asBool(json['is_fragile']),
      orderType: json['order_type']?.toString() ?? 'internal',
      requiredTruckType: json['required_truck_type']?.toString() ?? '',
      priceToDriver: json['price_to_driver']?.toString() ?? '',
      priceToClient: json['price_to_client']?.toString() ?? '',
      pricingMode: json['pricing_mode']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      eligibleDriversCount: json['eligible_drivers_count'] is int
          ? json['eligible_drivers_count']
          : int.tryParse(json['eligible_drivers_count']?.toString() ?? '') ??
              0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
