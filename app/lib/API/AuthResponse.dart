// ─── api_service.dart ─────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import 'config.dart';
import 'error_messages.dart';

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

  // 2026-08-29: only meaningful when role is 'driver'/'company'. False right
  // after OTP verification means the account exists but the driver/company
  // profile (documents, truck/license, etc.) hasn't been submitted yet — the
  // app must route to the profile-completion flow instead of the approval-
  // status or home screens. Defaults to true so admin/sub_admin (and any
  // older/unexpected response shape) never gets routed away incorrectly.
  final bool registrationComplete;

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
    this.registrationComplete = true,
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
      // Sent by login() and verifyOtp() under data.registration_complete —
      // only actually false for a driver/company mid-flow (see backend);
      // any other/older shape defaults to true, same reasoning as emailVerified.
      registrationComplete: data['registration_complete'] != false,
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

  // 2026-08-28 fix: this file used to have its own local _errorMessage()
  // helper — a duplicate, English-only implementation that predates (and
  // was missed by) the centralized error-handling pass in error_messages.
  // dart. Its 401 branch unconditionally showed "Your session has expired"
  // for every non-login call, including register()/verifyOtp()/
  // resendOtp() — endpoints that run before any session/token exists —
  // which is exactly the false "Session expired" report during sign-up.
  // Every call site below now goes through the shared, bilingual
  // apiErrorMessage() instead (see its 'register'/'otp' context handling).

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
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(json);
      }

      // Server returned an error message
      throw ApiException(
        apiErrorMessage(json, response.statusCode, context: 'login', fallback: 'Login failed'),
        statusCode: response.statusCode,
        requiresOtpVerification: json['requires_otp_verification'] == true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
    }
  }

  // ── Register: account only (2026-08-29) ─────────────────────────────────

  /// UC-2/UC-3, step 0 only: creates just the User row and sends the OTP —
  /// see UserController::register()'s docblock for why this no longer also
  /// creates the Driver/Company profile. Shared by both driver and company
  /// sign-up; the rest of each role's info is submitted separately, AFTER
  /// OTP success, via completeDriverRegistration() / completeCompanyRegistration()
  /// below. Does NOT log the user in — see verifyOtp().
  static Future<RegisterResult> registerAccount({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String type, // 'driver' | 'company'
  }) async {
    final uri = Uri.parse('$baseUrl/register');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim(),
              'password': password,
              'password_confirmation': passwordConfirmation,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 60));

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json['data'] ?? {};
        final user = data['user'] ?? {};
        return RegisterResult(
          email: user['email'] ?? email.trim(),
          type: user['type'] ?? type,
        );
      }

      throw ApiException(
        apiErrorMessage(json, response.statusCode, context: 'register', fallback: 'Registration failed'),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
    }
  }

  // ── Complete registration (company) ──────────────────────────────────────

  /// UC-2, step 2: called right after verifyOtp() succeeds (a token already
  /// exists at that point). Creates the Company row itself — mirrors what
  /// register() used to do for a company, minus name/email/password (already
  /// on the User row).
  static Future<void> completeCompanyRegistration({
    required String phone,
    String? address,
    required Uint8List licenseFileBytes,
    required String licenseFileName,
  }) async {
    final uri = Uri.parse('$baseUrl/company/complete-registration');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _authHeaders());
      request.fields['phone'] = phone;
      if (address != null) request.fields['address'] = address;
      request.files.add(http.MultipartFile.fromBytes('license_file', licenseFileBytes, filename: licenseFileName));

      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      // Deliberately NOT context: 'register' here — unlike register()/
      // verifyOtp(), these two calls ARE authenticated (a token already
      // exists by this point), so a 401 here genuinely does mean the
      // session/token is no longer valid and should show the real
      // session-expired message rather than the no-session-yet wording.
      throw ApiException(
        apiErrorMessage(json, response.statusCode, fallback: 'Registration failed'),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
    }
  }

  // ── Complete registration (driver) ───────────────────────────────────────

  /// UC-3, step 2: called right after verifyOtp() succeeds. Creates the
  /// Driver+DriverDocument(x N)+DriverDestination(x N)+Truck rows — mirrors
  /// what register() used to do for a driver, minus name/email/password
  /// (already on the User row).
  static Future<void> completeDriverRegistration({
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
    final uri = Uri.parse('$baseUrl/driver/complete-registration');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(await _authHeaders());
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
        return;
      }

      // Deliberately NOT context: 'register' here — unlike register()/
      // verifyOtp(), these two calls ARE authenticated (a token already
      // exists by this point), so a 401 here genuinely does mean the
      // session/token is no longer valid and should show the real
      // session-expired message rather than the no-session-yet wording.
      throw ApiException(
        apiErrorMessage(json, response.statusCode, fallback: 'Registration failed'),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
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

      throw ApiException(
        apiErrorMessage(json, response.statusCode, context: 'otp', fallback: 'Verification failed'),
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
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
        throw ApiException(
          apiErrorMessage(json, response.statusCode, context: 'otp', fallback: 'Could not resend code'),
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
    }
  }

  // ── Logout (audit item 9) ────────────────────────────────────────────────

  /// Revokes the current Sanctum token server-side. Deliberately silent on
  /// failure — the caller (logout_helper.dart's confirmAndLogout) clears
  /// the local session regardless so the user is never trapped by a
  /// network hiccup; server-side revocation just may not have completed in
  /// that case (the token naturally still expires on its own).
  static Future<void> logout() async {
    final uri = Uri.parse('$baseUrl/logout');
    try {
      await http.post(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 15));
    } catch (_) {
      // See docblock above — not surfaced to the caller on purpose.
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
        throw ApiException(
          apiErrorMessage(json, response.statusCode, fallback: 'Could not change password'),
          statusCode: response.statusCode,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(networkErrorMessage(e));
    }
  }
}
