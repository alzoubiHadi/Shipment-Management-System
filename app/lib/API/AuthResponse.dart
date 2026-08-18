// ─── api_service.dart ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

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

  // False only when this account was never verified via the sign-up OTP
  // screen. Login no longer blocks on this (see UserController::login) —
  // the app lets them in, then routes to OtpVerificationScreen instead of
  // HomeScreen so they can finish verifying with the fresh OTP the server
  // just queued. Defaults to true so any older/unexpected response shape
  // never accidentally locks a normal user out of their own home screen.
  final bool emailVerified;

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

  // Only meaningful when role is one of the admin types — see AppUser's
  // matching field for how this gets used (AdminDrawer filtering,
  // UserProfilePage badges).
  final List<String> permissions;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    this.emailVerified = true,
    this.mustChangePassword = false,
    this.driverApprovalStatus = 'approved',
    this.driverRejectionReason,
    this.driverDocumentIssues = const [],
    this.companyApprovalStatus = 'approved',
    this.companyRejectionReason,
    this.permissions = const [],
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
    final rawPermissions = user['permissions'];

    return AuthResponse(
      token: data['access_token'] ?? '',
      userId: user['id']?.toString() ?? '',
      email: user['email'] ?? '',
      name: user['name'] ?? '',
      role: user['type'] ?? '',
      // Only trust an explicit `false` from the server as "not verified" —
      // any other shape (missing key, older backend) defaults to true.
      emailVerified: user['email_verified'] != false,
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
      permissions: rawPermissions is List
          ? List<String>.from(rawPermissions.map((e) => e.toString()))
          : const [],
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
          .timeout(const Duration(seconds: 60));
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

  // ── Register (company) ───────────────────────────────────────────────────

  /// Company self-registration (UC-2). Driver registration uses the
  /// dedicated registerDriver() below, since it now collects a lot more
  /// (documents, destinations, truck) that doesn't belong on this signature.
  /// Does NOT log the user in — see verifyOtp().
  static Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String type = 'company',
    String? phone,
    String? address,
    Uint8List? licenseFileBytes,
    String? licenseFileName,
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.fields['name'] = name.trim();
      request.fields['email'] = email.trim();
      request.fields['password'] = password;
      request.fields['password_confirmation'] = passwordConfirmation;
      request.fields['type'] = type;
      if (phone != null) request.fields['phone'] = phone;
      if (address != null) request.fields['address'] = address;
      if (licenseFileBytes != null && licenseFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'license_file',
          licenseFileBytes,
          filename: licenseFileName,
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);

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

  // ── Register (driver) ────────────────────────────────────────────────────

  /// UC-3, revised: one submission covers both the driver's own info
  /// (documents, health, destinations) AND their truck — see
  /// UserController::register()'s driver branch on the backend, which
  /// creates the User+Driver+DriverDocument(x3)+DriverDestination(x N)+Truck
  /// rows all in one DB transaction. Does NOT log the user in — see
  /// verifyOtp().
  static Future<RegisterResult> registerDriver({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String phone,
    required String driverLicense,
    required String age,
    required String nationality,
    required Uint8List licenseFileBytes,
    required String licenseFileName,
    required String licenseExpiry, // yyyy-MM-dd
    required Uint8List passportFileBytes,
    required String passportFileName,
    required String passportExpiry,
    required Uint8List residencyFileBytes,
    required String residencyFileName,
    required String residencyExpiry,
    required String bloodType,
    String? healthConditions,
    required List<String> destinations,
    required String truckNumber,
    required String truckType,
    required Uint8List truckLicenseFileBytes,
    required String truckLicenseFileName,
    String? truckLicenseExpiry,
    String? permitType,
    // New-registration-design batch (2026-08-19) — all optional so this
    // still works if a caller doesn't collect them.
    Uint8List? licenseBackFileBytes,
    String? licenseBackFileName,
    Uint8List? driverPhotoFileBytes,
    String? driverPhotoFileName,
    Uint8List? truckInsuranceFileBytes,
    String? truckInsuranceFileName,
    String? truckInsuranceExpiry,
    Uint8List? truckInspectionFileBytes,
    String? truckInspectionFileName,
    String? truckInspectionExpiry,
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.fields['type'] = 'driver';
      request.fields['name'] = name.trim();
      request.fields['email'] = email.trim();
      request.fields['password'] = password;
      request.fields['password_confirmation'] = passwordConfirmation;
      request.fields['phone'] = phone;
      request.fields['driver_license'] = driverLicense;
      request.fields['age'] = age;
      request.fields['nationality'] = nationality;
      request.fields['license_expiry'] = licenseExpiry;
      request.fields['passport_expiry'] = passportExpiry;
      request.fields['residency_expiry'] = residencyExpiry;
      request.fields['blood_type'] = bloodType;
      if (healthConditions != null && healthConditions.isNotEmpty) {
        request.fields['health_conditions'] = healthConditions;
      }
      // http's MultipartRequest.fields is a Map, so a single repeated key
      // would silently overwrite itself — Laravel accepts indexed keys
      // (destinations[0], destinations[1], ...) as the array-field form.
      for (var i = 0; i < destinations.length; i++) {
        request.fields['destinations[$i]'] = destinations[i];
      }
      request.fields['truck_number'] = truckNumber;
      request.fields['truck_type'] = truckType;
      if (truckLicenseExpiry != null) request.fields['truck_license_expiry'] = truckLicenseExpiry;
      if (permitType != null && permitType.isNotEmpty) request.fields['permit_type'] = permitType;
      if (truckInsuranceExpiry != null) request.fields['truck_insurance_expiry'] = truckInsuranceExpiry;
      if (truckInspectionExpiry != null) request.fields['truck_inspection_expiry'] = truckInspectionExpiry;

      request.files.add(http.MultipartFile.fromBytes('license_file', licenseFileBytes, filename: licenseFileName));
      request.files.add(http.MultipartFile.fromBytes('passport_file', passportFileBytes, filename: passportFileName));
      request.files.add(http.MultipartFile.fromBytes('residency_file', residencyFileBytes, filename: residencyFileName));
      request.files.add(http.MultipartFile.fromBytes('truck_license_file', truckLicenseFileBytes, filename: truckLicenseFileName));
      if (licenseBackFileBytes != null && licenseBackFileName != null) {
        request.files.add(http.MultipartFile.fromBytes('license_back_file', licenseBackFileBytes, filename: licenseBackFileName));
      }
      if (driverPhotoFileBytes != null && driverPhotoFileName != null) {
        request.files.add(http.MultipartFile.fromBytes('driver_photo_file', driverPhotoFileBytes, filename: driverPhotoFileName));
      }
      if (truckInsuranceFileBytes != null && truckInsuranceFileName != null) {
        request.files.add(http.MultipartFile.fromBytes('truck_insurance_file', truckInsuranceFileBytes, filename: truckInsuranceFileName));
      }
      if (truckInspectionFileBytes != null && truckInspectionFileName != null) {
        request.files.add(http.MultipartFile.fromBytes('truck_inspection_file', truckInspectionFileBytes, filename: truckInspectionFileName));
      }

      // Up to 8 files in one request (license, passport, residency, truck
      // license, plus the 4 optional ones) — 60s was cutting this off on a
      // slow connection with a "stuck" submit button and no visible error.
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json['data'] ?? {};
        final user = data['user'] ?? {};
        return RegisterResult(
          email: user['email'] ?? email.trim(),
          type: user['type'] ?? 'driver',
        );
      }

      throw ApiException(_errorMessage(json, 'Registration failed'), statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
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
          .timeout(const Duration(seconds: 60));

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
          .timeout(const Duration(seconds: 60));

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
          .timeout(const Duration(seconds: 60));

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
