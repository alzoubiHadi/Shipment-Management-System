// ─── api_service.dart ─────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  // True when the server rejected login/otp because the account's email is
  // not verified yet (server already queued a fresh OTP in that case).
  final bool requiresOtpVerification;
  ApiException(this.message, {this.statusCode, this.requiresOtpVerification = false});

  @override
  String toString() => message;
}

class AuthResponse {
  final String token;
  final String userId;
  final String email;
  final String name;
  final String role;

  // True right after a sub-admin's very first login on a one-time temporary
  // password — the app must force a password-change screen before anything
  // else, and this can never be true for a driver/company account.
  final bool mustChangePassword;

  // Only meaningful when role == 'driver'. Defaults to 'approved' for every
  // other role (admin/company) so calling code doesn't need to special-case
  // them when deciding whether to show the "awaiting approval" screen.
  final String driverApprovalStatus;
  final String? driverRejectionReason;
  final List<String> driverDocumentIssues;

  // Only meaningful when role == 'company' — mirrors the driver fields
  // above, since companies now go through the same self-registration +
  // Super Admin approval workflow as drivers.
  final String companyApprovalStatus;
  final String? companyRejectionReason;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.mustChangePassword = false,
    this.driverApprovalStatus = 'approved',
    this.driverRejectionReason,
    this.driverDocumentIssues = const [],
    this.companyApprovalStatus = 'approved',
    this.companyRejectionReason,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final user = data['user'] ?? {};
    // login() and verifyOtp() both return these under top-level 'driver' /
    // 'company' keys (null for other roles, or if not applicable).
    final Map<String, dynamic>? driver =
        json['driver'] is Map ? Map<String, dynamic>.from(json['driver']) : null;
    final Map<String, dynamic>? company =
        json['company'] is Map ? Map<String, dynamic>.from(json['company']) : null;

    final rawIssues = driver == null ? null : driver['document_issues'];

    return AuthResponse(
      token: data['access_token'] ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email'] ?? '',
      name: user['name'] ?? '',
      role: user['type'] ?? '',
      mustChangePassword: user['must_change_password'] == true,
      driverApprovalStatus: driver == null
          ? 'approved'
          : (driver['approval_status']?.toString() ?? 'approved'),
      driverRejectionReason: driver?['rejection_reason']?.toString(),
      driverDocumentIssues: rawIssues is List
          ? List<String>.from(rawIssues.map((e) => e.toString()))
          : const [],
      companyApprovalStatus: company == null
          ? 'approved'
          : (company['approval_status']?.toString() ?? 'approved'),
      companyRejectionReason: company?['rejection_reason']?.toString(),
    );
  }

}

/// Returned by register() — self-registration no longer issues a token
/// immediately (UC-2/UC-3/UC-4): the account must first be verified with
/// the OTP code emailed to it (see ApiService.verifyOtp).
class RegisterResult {
  final String email;
  final String type;

  RegisterResult({required this.email, required this.type});
}

class ApiService {


  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Laravel validation failures come back as {message: "Validation failed",
  /// errors: {field: ["reason", ...]}}. Showing just `message` hides the
  /// actually useful part — this pulls every per-field reason out so the
  /// screen can show e.g. "The password must contain at least one symbol."
  /// instead of a dead-end "Validation failed."
  static String _errorMessage(Map<String, dynamic> json, String fallback) {
    final errors = json['errors'];
    if (errors is Map) {
      final details = errors.values
          .expand((v) => v is List ? v : [v])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .join('\n');
      if (details.isNotEmpty) return details;
    }
    return (json['message'] ?? json['error'] ?? fallback).toString();
  }

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      ..._headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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
      throw ApiException(
        _errorMessage(json, 'Login failed'),
        statusCode: response.statusCode,
        requiresOtpVerification: json['requires_otp_verification'] == true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      // TEMPORARY diagnostic — see the register() function below for why.
      throw ApiException('Could not connect: $e');
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  /// type must be 'driver' or 'company'. driverLicense is required when
  /// type == 'driver'; address is optional and only used when
  /// type == 'company'. Does NOT log the user in — see verifyOtp().
  static Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String type = 'driver',
    String? phone,
    String? driverLicense,
    String? address,
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    final body = jsonEncode({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
      'phone': phone,
      'type': type,
      if (type == 'driver') 'driver_license': driverLicense,
      if (type == 'company') 'address': address,
    });

    try {
      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json['data'] ?? {};
        final user = data['user'] ?? {};
        return RegisterResult(
          email: user['email'] ?? email.trim(),
          type: user['type'] ?? type,
        );
      }

      throw ApiException(_errorMessage(json, 'Registration failed'), statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      // TEMPORARY diagnostic: show the real error instead of the generic
      // message, so we can see exactly what's failing this time (server
      // error page instead of JSON, timeout, socket error, etc).
      throw ApiException('Could not connect: $e');
    }
  }

  // ── Email OTP verification (UC-4) ────────────────────────────────────────

  static Future<AuthResponse> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final uri = Uri.parse('$baseUrl/verify-otp');

    final body = jsonEncode({'email': email.trim(), 'otp_code': otpCode.trim()});

    try {
      final response = await http
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthResponse.fromJson(json);
      }

      throw ApiException(_errorMessage(json, 'Verification failed'), statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not connect: $e');
    }
  }

  static Future<void> resendOtp({required String email}) async {
    final uri = Uri.parse('$baseUrl/resend-otp');

    try {
      final response = await http
          .post(uri, headers: _headers, body: jsonEncode({'email': email.trim()}))
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw ApiException(_errorMessage(json, 'Could not resend code'), statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not connect: $e');
    }
  }

  // ── Forced / voluntary password change (UC-7) ────────────────────────────

  static Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final uri = Uri.parse('$baseUrl/change-password');

    try {
      final response = await http
          .post(
            uri,
            headers: await _authHeaders(),
            body: jsonEncode({
              'current_password': currentPassword,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        throw ApiException(_errorMessage(json, 'Could not change password'), statusCode: response.statusCode);
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not connect: $e');
    }
  }
}
