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
    };
  }
}