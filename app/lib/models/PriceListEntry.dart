class PriceListEntry {
  final int id;
  final String destination;
  final String truckType;
  final double basePrice;

  PriceListEntry({
    required this.id,
    required this.destination,
    required this.truckType,
    required this.basePrice,
  });

  factory PriceListEntry.fromJson(Map<String, dynamic> json) {
    return PriceListEntry(
      id: json['id'] ?? 0,
      destination: json['destination']?.toString() ?? '',
      truckType: json['truck_type']?.toString() ?? '',
      basePrice: double.tryParse(json['base_price']?.toString() ?? '') ?? 0,
    );
  }
}
