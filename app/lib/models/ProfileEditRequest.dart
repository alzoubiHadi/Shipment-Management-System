/// A pending/approved/rejected self-service change to a driver's documents,
/// truck documents, destinations, or a company's trade license — see
/// server ProfileController for the approval workflow.
class ProfileEditRequest {
  final String id;
  final String userId;
  final String? userName;
  final String? userType; // 'driver' | 'company' | ...
  final String category; // 'document' | 'truck_document' | 'destinations' | 'company_license'
  final Map<String, dynamic> payload;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminNote;
  final DateTime? createdAt;
  // Only populated for document/truck_document/company_license categories —
  // the previously-current document, for the admin's "Old vs New" review UI.
  final Map<String, dynamic>? oldDocument;

  ProfileEditRequest({
    required this.id,
    required this.userId,
    this.userName,
    this.userType,
    required this.category,
    required this.payload,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.oldDocument,
  });

  factory ProfileEditRequest.fromJson(Map<String, dynamic> json) {
    return ProfileEditRequest(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      userName: json['user'] is Map ? json['user']['name']?.toString() : null,
      userType: json['user'] is Map ? json['user']['type']?.toString() : null,
      category: json['category']?.toString() ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      status: json['status']?.toString() ?? 'pending',
      adminNote: json['admin_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      oldDocument: json['old_document'] is Map
          ? Map<String, dynamic>.from(json['old_document'] as Map)
          : null,
    );
  }

  bool get isDocumentRenewal => category == 'document' || category == 'truck_document' || category == 'company_license';

  String get documentTypeLabel {
    final type = payload['type']?.toString() ?? 'trade_license';
    return switch (type) {
      'license' => category == 'truck_document' ? 'Vehicle Registration/License' : 'Driver License',
      'passport' => 'Passport',
      'residency' => 'Residency',
      'insurance' => 'Insurance',
      'technical_inspection' => 'Technical Inspection',
      'trade_license' => 'Trade License',
      _ => type,
    };
  }

  String get categoryLabel => switch (category) {
        'document' => 'Document renewal (${payload['type'] ?? ''})',
        'truck_document' => 'Truck document renewal (${payload['type'] ?? ''})',
        'destinations' => 'Work destinations change',
        'company_license' => 'Trade license renewal',
        _ => category,
      };
}
