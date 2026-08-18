class ShipmentOffer {
  final int id;
  final int companyId;
  final String companyName;
  final String origin;
  final double? originLat;
  final double? originLng;
  final String destination;
  // Zones / Smart Pricing Engine (2026-08-27) — structured route fields,
  // present on both the company- and driver-facing JSON once an offer was
  // created through the zone-based flow; null for older/legacy offers.
  // pricing* fields are only ever present on the company-facing resource —
  // DriverFacingShipmentOfferResource deliberately omits them (a driver
  // never sees historical pricing/range/confidence), so they simply parse
  // as null for a driver's own offer list.
  final String? originCountry;
  final String? originCity;
  final int? originZoneId;
  final String? originAddress;
  final String? destinationCountry;
  final String? destinationCity;
  final int? destinationZoneId;
  final String? destinationAddress;
  final double? pricingReference;
  final double? pricingLow;
  final double? pricingHigh;
  final String? pricingConfidence;
  final String? pricingLevel;
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
    this.originCountry,
    this.originCity,
    this.originZoneId,
    this.originAddress,
    this.destinationCountry,
    this.destinationCity,
    this.destinationZoneId,
    this.destinationAddress,
    this.pricingReference,
    this.pricingLow,
    this.pricingHigh,
    this.pricingConfidence,
    this.pricingLevel,
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
  bool get hasZoneRoute => originZoneId != null && destinationZoneId != null;

  factory ShipmentOffer.fromJson(Map<String, dynamic> json) {
    bool asBool(dynamic v) => v == true || v == 1 || v == '1';

    return ShipmentOffer(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      companyName: json['company']?['name']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      originLat: json['origin_lat'] != null ? double.tryParse(json['origin_lat'].toString()) : null,
      originLng: json['origin_lng'] != null ? double.tryParse(json['origin_lng'].toString()) : null,
      originCountry: json['origin_country']?.toString(),
      originCity: json['origin_city']?.toString(),
      originZoneId: json['origin_zone_id'] is int ? json['origin_zone_id'] : int.tryParse(json['origin_zone_id']?.toString() ?? ''),
      originAddress: json['origin_address']?.toString(),
      destinationCountry: json['destination_country']?.toString(),
      destinationCity: json['destination_city']?.toString(),
      destinationZoneId: json['destination_zone_id'] is int ? json['destination_zone_id'] : int.tryParse(json['destination_zone_id']?.toString() ?? ''),
      destinationAddress: json['destination_address']?.toString(),
      pricingReference: json['pricing_reference'] != null ? double.tryParse(json['pricing_reference'].toString()) : null,
      pricingLow: json['pricing_low'] != null ? double.tryParse(json['pricing_low'].toString()) : null,
      pricingHigh: json['pricing_high'] != null ? double.tryParse(json['pricing_high'].toString()) : null,
      pricingConfidence: json['pricing_confidence']?.toString(),
      pricingLevel: json['pricing_level']?.toString(),
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
