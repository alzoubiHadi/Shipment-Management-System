import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ProfileEditRequest.dart';
import 'config.dart';

/// Self-service "tap your name" profile page — shared by admin, driver and
/// company. Basic contact info (name/phone/email) and the avatar apply
/// immediately; anything material to eligibility (driver documents/
/// destinations, a company's trade license) goes through the pending
/// ProfileEditRequest queue instead (see fetchMyEditRequests()).
class ProfileService {
  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/profile'),
      headers: await _authHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Map<String, dynamic>.from(data['user'] ?? {});
    }
    throw Exception('Failed to load profile (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> updateBasic({
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (email != null) body['email'] = email;

      final response = await http.put(
        Uri.parse('$baseUrl/me/profile'),
        headers: await _authHeaders(json: true),
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      String message = data['message'] ?? 'Could not update profile';
      if (data['errors'] != null) {
        (data['errors'] as Map).forEach((key, value) {
          message += '\n${(value as List).first}';
        });
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/me/profile/avatar'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('avatar', fileBytes, filename: fileName));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'], 'avatar_path': data['avatar_path']};
      }
      String message = data['message'] ?? 'Could not upload avatar';
      if (data['errors'] != null) {
        (data['errors'] as Map).forEach((key, value) {
          message += '\n${(value as List).first}';
        });
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<ProfileEditRequest>> fetchMyEditRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me/profile/edit-requests'),
      headers: await _authHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['requests'] as List).map((e) => ProfileEditRequest.fromJson(e)).toList();
    }
    throw Exception('Failed to load edit requests (HTTP ${response.statusCode})');
  }

  /// Company self-service trade-license renewal — pending admin approval,
  /// same as a driver's document renewal.
  Future<Map<String, dynamic>> submitCompanyLicense({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/me/company/license'));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('license_file', fileBytes, filename: fileName));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      }
      String message = data['message'] ?? 'Could not submit license';
      if (data['errors'] != null) {
        (data['errors'] as Map).forEach((key, value) {
          message += '\n${(value as List).first}';
        });
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Admin review ─────────────────────────────────────────────────────

  Future<List<ProfileEditRequest>> fetchPendingEditRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/profile-edit-requests?status=pending'),
      headers: await _authHeaders(),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['requests'] as List).map((e) => ProfileEditRequest.fromJson(e)).toList();
    }
    throw Exception('Failed to load edit requests (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> approveEditRequest(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/profile-edit-requests/$id/approve'),
        headers: await _authHeaders(),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectEditRequest(String id, {String? reason}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/profile-edit-requests/$id/reject'),
        headers: await _authHeaders(json: true),
        body: jsonEncode({'reason': reason}),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
