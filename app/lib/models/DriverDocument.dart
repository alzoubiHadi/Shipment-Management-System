/// UC-8: one uploaded version of a driver document. The backend never
/// deletes old versions (append-only audit trail) — only `isCurrent == true`
/// counts for eligibility checks (Driver.documentIssues on the server).
class DriverDocument {
  final String id;
  final String type;
  final String filePath;
  final DateTime? expiryDate;
  final bool isCurrent;
  // Compliance/Approval separation feature (2026-08-23): the real,
  // backend-tracked lifecycle status — 'valid' | 'expiring_soon' |
  // 'expired' | 'pending_review' | 'changes_required' | 'superseded' — see
  // DriverDocument::STATUSES on the server. Previously the app derived its
  // own expired/valid label purely from expiryDate; this is now the
  // source of truth so pending/changes-required states can be shown too.
  final String status;
  final DateTime? createdAt;

  DriverDocument({
    required this.id,
    required this.type,
    required this.filePath,
    this.expiryDate,
    this.isCurrent = false,
    this.status = 'valid',
    this.createdAt,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Whole days left until expiry — negative once expired. Null when
  /// there's no expiry date at all (e.g. a non-dated document type).
  int? get daysRemaining {
    if (expiryDate == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final expiry = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return expiry.difference(today).inDays;
  }

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : null,
      isCurrent: json['is_current'] == true,
      status: json['status']?.toString() ?? 'valid',
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
