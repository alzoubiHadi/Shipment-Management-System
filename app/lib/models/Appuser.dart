enum UserRole {
  driver,
  company,
  admin,
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarInitials;

  // Only meaningful for role == 'super_admin'/'admin'/'sub_admin' — the
  // permission keys (finance/trainer/technical_check/crm) this admin
  // account holds, used to filter AdminDrawer/ApprovalsPage and to show
  // badges on UserProfilePage. A super admin gets every key (see
  // ProfileController::show() and UserController::login() on the
  // backend, which both return the full catalog for that case). Empty
  // for drivers/companies.
  final List<String> permissions;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarInitials,
    this.permissions = const [],
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'],
      avatarInitials: map['avatarInitials'] as String?,
      permissions: map['permissions'] is List
          ? List<String>.from((map['permissions'] as List).map((e) => e.toString()))
          : const [],
    );
  }

  bool hasPermission(String key) {
    return isSuperAdmin || permissions.contains(key);
  }

  // 2026-08-29: centralizes what the backend's User::isSuperAdmin() already
  // does — both 'super_admin' and the legacy 'admin' role are treated as
  // Super Admin there. Individual screens used to each hand-roll their own
  // `role == 'super_admin'` check (AdminDrawer.dart, AdminSettingsPage.dart),
  // which silently excluded the legacy 'admin' account from Super-Admin-only
  // UI (Activity Log, Platform Settings, Admin Accounts, recycle bins, ...)
  // even though the backend would happily authorize it for those same
  // actions. Every Super-Admin-only UI check should go through this getter
  // instead of comparing `role` directly.
  bool get isSuperAdmin {
    final r = role.toLowerCase();
    return r == 'super_admin' || r == 'admin';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatarInitials': avatarInitials,
      'permissions': permissions,
    };
  }
}