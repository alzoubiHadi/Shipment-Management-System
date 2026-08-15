class Company {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String user_id;
  final String password;
  final double balance;
  final double creditLimit;

  Company({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.user_id,
    required this.password,
    this.balance = 0,
    this.creditLimit = 0,
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
    };
  }
}