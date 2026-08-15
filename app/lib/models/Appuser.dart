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

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarInitials,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'],
      avatarInitials: map['avatarInitials'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatarInitials': avatarInitials,
    };
  }
}