class Company {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String user_id;
  final String password;
  final double balance;
  final double creditLimit;
  // UC-27: 'active' | 'suspended'. suspensionReason is set only while
  // suspended, mirrors Driver.complianceStatus/admin_note.
  final String accountStatus;
  final String? suspensionReason;
  // UC-5: 'pending' | 'approved' | 'rejected' — self-registered companies
  // start 'pending' and need Super Admin approval, mirrors
  // Driver.approvalStatus/rejectionReason exactly.
  final String approvalStatus;
  final String? rejectionReason;
  // Trade/commercial license file uploaded at registration — the relative
  // storage path returned by the backend (e.g. "company_licenses/xyz.pdf"),
  // not yet a full URL. See CompanyDetailsPage for how it's turned into a
  // viewable link.
  final String? licenseFilePath;
  // Unified Approvals redesign (2026-08-22): 'active' | 'action_required' —
  // set by Company::recomputeComplianceStatus() when the trade license
  // expires. Unlike Driver.complianceStatus, there's no misconduct branch
  // here (no company-level suspension/warning states), just this one flag.
  // approval_status stays 'approved' the whole time — the company can still
  // log in and use everything except creating a new shipment (see
  // ShipmentOfferController::create()'s 403 check).
  final String complianceStatus;
  // Laravel's default Eloquent timestamp — when this company row (and thus
  // the registration request) was created. Used by the Registration
  // Requests screen's "Applied on" date.
  final DateTime? createdAt;

  Company({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.user_id,
    required this.password,
    this.balance = 0,
    this.creditLimit = 0,
    this.accountStatus = 'active',
    this.suspensionReason,
    this.approvalStatus = 'approved',
    this.rejectionReason,
    this.licenseFilePath,
    this.complianceStatus = 'active',
    this.createdAt,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      user_id: map['user_id']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      balance: double.tryParse(map['balance']?.toString() ?? '') ?? 0,
      creditLimit: double.tryParse(map['credit_limit']?.toString() ?? '') ?? 0,
      accountStatus: map['account_status']?.toString() ?? 'active',
      suspensionReason: map['suspension_reason']?.toString(),
      approvalStatus: map['approval_status']?.toString() ?? 'approved',
      rejectionReason: map['rejection_reason']?.toString(),
      licenseFilePath: map['license_file_path']?.toString(),
      complianceStatus: map['compliance_status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Company copyWith({
    String? accountStatus,
    String? suspensionReason,
    bool clearSuspensionReason = false,
    String? approvalStatus,
    String? rejectionReason,
    bool clearRejectionReason = false,
    String? licenseFilePath,
    String? complianceStatus,
  }) {
    return Company(
      id: id,
      name: name,
      email: email,
      phone: phone,
      user_id: user_id,
      password: password,
      balance: balance,
      creditLimit: creditLimit,
      accountStatus: accountStatus ?? this.accountStatus,
      suspensionReason:
          clearSuspensionReason ? null : (suspensionReason ?? this.suspensionReason),
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason:
          clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
      licenseFilePath: licenseFilePath ?? this.licenseFilePath,
      complianceStatus: complianceStatus ?? this.complianceStatus,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'user_id': user_id,
      'password': password,
      'balance': balance,
      'credit_limit': creditLimit,
      'account_status': accountStatus,
      'suspension_reason': suspensionReason,
      'approval_status': approvalStatus,
      'rejection_reason': rejectionReason,
      'license_file_path': licenseFilePath,
      'compliance_status': complianceStatus,
    };
  }
}