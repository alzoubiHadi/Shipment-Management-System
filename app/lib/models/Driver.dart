class Driver {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String truck_number;
  final String truck_type;
  final String nationality;
  final String age;
  final String driver_license;
  final String license_expiry;
  final String user_id;
  final String password;

  // Added for the admin-approval + document-check workflow.
  final String employmentType; // 'internal' or 'external'
  final String status; // 'available' | 'busy' | 'unavailable'
  final String approvalStatus; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final String residencyExpiry;
  final String passportExpiry;
  final String bloodType;
  // Human-readable problems with this driver's documents, computed by the
  // server (Driver::documentIssues()) — e.g. "Driver license expired".
  final List<String> documentIssues;
  // UC-23/24: recency-weighted average of company + Super Admin ratings.
  final double rating;
  // UC-25/26: active | warning | suspended | banned — separate axis from
  // approvalStatus. Suspended/banned drivers never appear in matching.
  final String complianceStatus;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.truck_number,
    required this.truck_type,
    required this.nationality,
    required this.age,
    required this.driver_license,
    required this.license_expiry,
    required this.user_id,
    required this.password,
    this.employmentType = 'internal',
    this.status = 'available',
    this.approvalStatus = 'approved',
    this.rejectionReason,
    this.residencyExpiry = '',
    this.passportExpiry = '',
    this.bloodType = '',
    this.documentIssues = const [],
    this.rating = 4.50,
    this.complianceStatus = 'active',
  });

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      truck_number: map['truck_number']?.toString() ?? '',
      truck_type: map['truck_type']?.toString() ?? '',
      nationality: map['nationality']?.toString() ?? '',
      age: map['age']?.toString() ?? '',
      driver_license: map['driver_license']?.toString() ?? '',
      license_expiry: map['license_expiry']?.toString() ?? '',
      user_id: map['user_id']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      employmentType: map['employment_type']?.toString() ?? 'internal',
      status: map['status']?.toString() ?? 'available',
      approvalStatus: map['approval_status']?.toString() ?? 'approved',
      rejectionReason: map['rejection_reason']?.toString(),
      residencyExpiry: map['residency_expiry']?.toString() ?? '',
      passportExpiry: map['passport_expiry']?.toString() ?? '',
      bloodType: map['blood_type']?.toString() ?? '',
      documentIssues: map['document_issues'] is List
          ? List<String>.from(
              (map['document_issues'] as List).map((e) => e.toString()))
          : const [],
      rating: double.tryParse(map['rating']?.toString() ?? '') ?? 4.50,
      complianceStatus: map['compliance_status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'truck_number': truck_number,
      'truck_type': truck_type,
      'nationality': nationality,
      'age': age,
      'driver_license': driver_license,
      'license_expiry': license_expiry,
      'user_id': user_id,
      'password': password,
      'employment_type': employmentType,
      'status': status,
      'approval_status': approvalStatus,
      'rejection_reason': rejectionReason,
      'residency_expiry': residencyExpiry,
      'passport_expiry': passportExpiry,
      'blood_type': bloodType,
    };
  }
}
