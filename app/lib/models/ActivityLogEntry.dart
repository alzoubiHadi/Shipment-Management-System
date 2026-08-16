/// NFR (Security): one row of the audit trail — mirrors ActivityLog.php.
class ActivityLogEntry {
  final int id;
  final String? userName;
  final String action;
  final String? subjectType;
  final String? subjectId;
  final String description;
  final String createdAt;

  ActivityLogEntry({
    required this.id,
    required this.userName,
    required this.action,
    required this.subjectType,
    required this.subjectId,
    required this.description,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userName: json['user_name']?.toString(),
      action: json['action']?.toString() ?? '',
      subjectType: json['subject_type']?.toString(),
      subjectId: json['subject_id']?.toString(),
      description: json['description']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
