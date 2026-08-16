/// UC-8: one uploaded version of a driver document. The backend never
/// deletes old versions (append-only audit trail) — only `isCurrent == true`
/// counts for eligibility checks (Driver.documentIssues on the server).
class DriverDocument {
  final String id;
  final String type;
  final String filePath;
  final DateTime? expiryDate;
  final bool isCurrent;
  final DateTime? createdAt;

  DriverDocument({
    required this.id,
    required this.type,
    required this.filePath,
    this.expiryDate,
    this.isCurrent = false,
    this.createdAt,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : null,
      isCurrent: json['is_current'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// Mirrors DriverDocument::TYPES on the backend exactly — keep in sync.
class DriverDocumentType {
  final String key;
  final String label;
  const DriverDocumentType(this.key, this.label);
}

const List<DriverDocumentType> kDriverDocumentTypes = [
  DriverDocumentType('license', 'Driving License'),
  DriverDocumentType('passport', 'Passport'),
  DriverDocumentType('residency', 'Residency'),
  DriverDocumentType('id_card', 'ID Card'),
  DriverDocumentType('medical_certificate', 'Medical Certificate'),
  DriverDocumentType('other', 'Other'),
];

String driverDocumentTypeLabel(String key) {
  return kDriverDocumentTypes
      .firstWhere((t) => t.key == key, orElse: () => DriverDocumentType(key, key))
      .label;
}
