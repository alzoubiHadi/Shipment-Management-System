// ─── api_service.dart ─────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:http/http.dart' as http;


import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthResponse {
  final String token;
  final String userId;
  final String email;
  final String name;
  final String role;

  AuthResponse({required this.token, required this.userId, required this.email, required this.name, required this.role});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final user = data['user'] ?? {};

    return AuthResponse(
      token: data['access_token'] ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email'] ?? '',
      name: user['name'] ?? '',
      role: user['type'] ?? '',
    );
  }

}


class ApiService {


  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Login ──────────────────────────────────────────────────────────────────

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/login');

    final body = jsonEncode({
      'email': email.trim(),
      'password': password,
    });

    try {
      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));
      print(response.body);
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(json);
      }

      // Server returned an error message
      final message = json['message'] ?? json['error'] ?? 'Login failed';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not connect. Check your internet connection.');
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  static Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? driverLicense,
    bool isAlbatransFleet = false,
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    final body = jsonEncode({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone,
      // backend only requires/uses these when type == 'driver', which is
      // the default for self-registration
      'driver_license': driverLicense,
      'is_albatrans_fleet': isAlbatransFleet,
    });

    try {
      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(json);
      }

      final message = json['message'] ?? json['error'] ?? 'Registration failed';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not connect. Check your internet connection.');
    }
  }
}