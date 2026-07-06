class ShipmentOffer {
  final int id;
  final int companyId;
  final String companyName;
  final String origin;
  final String destination;
  final String weight;
  final String description;
  final String cargoType;
  final bool requiresCrossBorder;
  final String requiredTruckType;
  final String priceToDriver;
  final String priceToClient;
  final String status;
  final int eligibleDriversCount;
  final String createdAt;

  ShipmentOffer({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.origin,
    required this.destination,
    required this.weight,
    required this.description,
    required this.cargoType,
    required this.requiresCrossBorder,
    required this.requiredTruckType,
    required this.priceToDriver,
    required this.priceToClient,
    required this.status,
    required this.eligibleDriversCount,
    required this.createdAt,
  });

  factory ShipmentOffer.fromJson(Map<String, dynamic> json) {
    return ShipmentOffer(
      id: json['id'] ?? 0,
      companyId: json['company_id'] ?? 0,
      companyName: json['company']?['name']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      cargoType: json['cargo_type']?.toString() ?? 'normal',
      requiresCrossBorder: json['requires_cross_border'] == true ||
          json['requires_cross_border'] == 1,
      requiredTruckType: json['required_truck_type']?.toString() ?? '',
      priceToDriver: json['price_to_driver']?.toString() ?? '',
      priceToClient: json['price_to_client']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      eligibleDriversCount: json['eligible_drivers_count'] is int
          ? json['eligible_drivers_count']
          : int.tryParse(json['eligible_drivers_count']?.toString() ?? '') ??
              0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
