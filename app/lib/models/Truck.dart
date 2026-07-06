class Truck {
  final String id;
  final String truckNumber;
  final String truckType;
  final bool hasRefrigeration;

  Truck({
    required this.id,
    required this.truckNumber,
    required this.truckType,
    required this.hasRefrigeration,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    return Truck(
      id: json['id']?.toString() ?? '',
      truckNumber: json['truck_number']?.toString() ?? '',
      truckType: json['truck_type']?.toString() ?? '',
      hasRefrigeration: json['has_refrigeration'] == true ||
          json['has_refrigeration'] == 1,
    );
  }
}
