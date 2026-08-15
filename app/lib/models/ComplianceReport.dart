/// UC-25/UC-26: a compliance/safety report filed against a driver, and its
/// review/appeal state.
class ComplianceReport {
  final int id;
  final int driverId;
  final String driverName;
  final String category; // traffic | cargo_damage | complaint | criminal | smuggling | forgery | other
  final String description;
  final String? evidenceFilePath;
  final String status; // open | under_review | upheld | dismissed
  final String? resultingAction; // none | warning | suspension | ban
  final String? appealText;
  final String appealStatus; // none | pending | accepted | rejected
  final String createdAt;

  ComplianceReport({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.category,
    required this.description,
    required this.evidenceFilePath,
    required this.status,
    required this.resultingAction,
    required this.appealText,
    required this.appealStatus,
    required this.createdAt,
  });

  bool get isPendingReview => status == 'open' || status == 'under_review';
  bool get isUpheld => status == 'upheld';
  bool get canAppeal => isUpheld && appealStatus == 'none';
  bool get hasPendingAppeal => appealStatus == 'pending';

  static const categories = [
    'traffic',
    'cargo_damage',
    'complaint',
    'criminal',
    'smuggling',
    'forgery',
    'other',
  ];

  factory ComplianceReport.fromJson(Map<String, dynamic> json) {
    return ComplianceReport(
      id: json['id'] ?? 0,
      driverId: json['driver_id'] ?? 0,
      driverName: json['driver']?['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      description: json['description']?.toString() ?? '',
      evidenceFilePath: json['evidence_file_path']?.toString(),
      status: json['status']?.toString() ?? 'open',
      resultingAction: json['resulting_action']?.toString(),
      appealText: json['appeal_text']?.toString(),
      appealStatus: json['appeal_status']?.toString() ?? 'none',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
