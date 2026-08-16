/// UC-6: composable sub-admin account. `permissionKeys` is the list of
/// permission group keys (e.g. 'finance', 'crm') currently held — a single
/// sub-admin can hold several at once.
class SubAdmin {
  final String id;
  final String name;
  final String email;
  final bool mustChangePassword;
  final bool isSuspended;
  final List<String> permissionKeys;

  SubAdmin({
    required this.id,
    required this.name,
    required this.email,
    required this.mustChangePassword,
    this.isSuspended = false,
    required this.permissionKeys,
  });

  factory SubAdmin.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    return SubAdmin(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mustChangePassword: json['must_change_password'] == true,
      isSuspended: json['is_suspended'] == true,
      permissionKeys: perms is List
          ? perms.map((p) => p['key']?.toString() ?? '').where((k) => k.isNotEmpty).toList()
          : const [],
    );
  }
}

/// One selectable permission group (e.g. key: 'finance', label: 'Finance Admin').
class PermissionGroup {
  final String key;
  final String label;

  PermissionGroup({required this.key, required this.label});

  factory PermissionGroup.fromJson(Map<String, dynamic> json) {
    return PermissionGroup(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}
