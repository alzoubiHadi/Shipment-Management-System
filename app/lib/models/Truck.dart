class Truck {
  final String id;
  final String truckNumber;
  final String truckType;
  final bool hasRefrigeration;
  // Added for the admin request-review screen's Truck Info/Truck Documents
  // tabs (Phase 3 of the admin dashboard redesign) — optional/nullable so
  // existing callers (driver's own truck list) that don't send these keep
  // working unchanged.
  final String? permitType;
  final DateTime? permitExpiry;
  final DateTime? insuranceExpiry;
  final String? insuranceFilePath;
  final DateTime? licenseExpiry;
  final String? licenseFilePath;
  final DateTime? technicalInspectionExpiry;
  final String? technicalInspectionFilePath;
  final bool isActive;
  // Driver redesign Phase 4 (2026-08-17) "My Truck" screen's Capacity
  // field — a real column (Truck::$fillable on the backend) that was
  // never parsed on the Flutter side until now.
  final double? maxLoad;

  Truck({
    required this.id,
    required this.truckNumber,
    required this.truckType,
    required this.hasRefrigeration,
    this.permitType,
    this.permitExpiry,
    this.insuranceExpiry,
    this.insuranceFilePath,
    this.licenseExpiry,
    this.licenseFilePath,
    this.technicalInspectionExpiry,
    this.technicalInspectionFilePath,
    this.isActive = true,
    this.maxLoad,
  });

  factory Truck.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return Truck(
      id: json['id']?.toString() ?? '',
      truckNumber: json['truck_number']?.toString() ?? '',
      truckType: json['truck_type']?.toString() ?? '',
      hasRefrigeration: json['has_refrigeration'] == true ||
          json['has_refrigeration'] == 1,
      maxLoad: json['max_load'] != null ? double.tryParse(json['max_load'].toString()) : null,
      permitType: json['permit_type']?.toString(),
      permitExpiry: parseDate(json['permit_expiry']),
      insuranceExpiry: parseDate(json['insurance_expiry']),
      insuranceFilePath: json['insurance_file_path']?.toString(),
      licenseExpiry: parseDate(json['license_expiry']),
      licenseFilePath: json['license_file_path']?.toString(),
      technicalInspectionExpiry: parseDate(json['technical_inspection_expiry']),
      technicalInspectionFilePath: json['technical_inspection_file_path']?.toString(),
      isActive: json['is_active'] == null ? true : (json['is_active'] == true || json['is_active'] == 1),
    );
  }
}
