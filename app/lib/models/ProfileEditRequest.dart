/// A pending/approved/rejected self-service change to a driver's documents
/// or destinations, or a company's trade license — see
/// server ProfileController for the approval workflow.
class ProfileEditRequest {
  final String id;
  final String userId;
  final String? userName;
  final String category; // 'document' | 'destinations' | 'company_license'
  final Map<String, dynamic> payload;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? adminNote;
  final DateTime? createdAt;

  ProfileEditRequest({
    required this.id,
    required this.userId,
    this.userName,
    required this.category,
    required this.payload,
    required this.status,
    this.adminNote,
    this.createdAt,
  });

  factory ProfileEditRequest.fromJson(Map<String, dynamic> json) {
    return ProfileEditRequest(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      userName: json['user'] is Map ? json['user']['name']?.toString() : null,
      category: json['category']?.toString() ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : <String, dynamic>{},
      status: json['status']?.toString() ?? 'pending',
      adminNote: json['admin_note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String get categoryLabel => switch (category) {
        'document' => 'Document renewal (${payload['type'] ?? ''})',
        'destinations' => 'Work destinations change',
        'company_license' => 'Trade license renewal',
        _ => category,
      };
}
