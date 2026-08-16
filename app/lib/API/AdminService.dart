import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/SubAdmin.dart';
import 'config.dart';

/// UC-6: Super Admin creates/manages composable sub-admin accounts.
class AdminService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<PermissionGroup>> fetchPermissionGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/permissions'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['permissions'] as List)
          .map((e) => PermissionGroup.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load permission groups (HTTP ${response.statusCode})');
  }

  Future<List<SubAdmin>> fetchSubAdmins() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/sub-admins'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['admins'] as List)
          .map((e) => SubAdmin.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load sub-admins (HTTP ${response.statusCode})');
  }

  /// Returns the one-time temporary password on success — the caller must
  /// show it to the admin immediately, it's never retrievable again.
  Future<Map<String, dynamic>> createSubAdmin({
    required String name,
    required String email,
    required List<String> permissionKeys,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/sub-admins'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'permissions': permissionKeys,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'temporary_password': data['temporary_password'],
        };
      }

      String message = data['message'] ?? 'Could not create sub-admin';
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

  Future<Map<String, dynamic>> updatePermissions({
    required String adminId,
    required List<String> permissionKeys,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/sub-admins/$adminId/permissions'),
        headers: await _authHeaders(),
        body: jsonEncode({'permissions': permissionKeys}),
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

  Future<Map<String, dynamic>> resetPassword(String adminId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/sub-admins/$adminId/reset-password'),
        headers: await _authHeaders(),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'temporary_password': data['temporary_password'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> suspendSubAdmin(String adminId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/sub-admins/$adminId/suspend'),
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

  Future<Map<String, dynamic>> activateSubAdmin(String adminId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/sub-admins/$adminId/activate'),
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

  Future<bool> deleteSubAdmin(String adminId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/sub-admins/$adminId'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
