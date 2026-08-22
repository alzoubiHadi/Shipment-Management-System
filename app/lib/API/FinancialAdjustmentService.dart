import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'error_messages.dart';

class FinancialAdjustmentService {
  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Every ADJUSTMENT ever proposed (pending/posted/rejected), newest first.
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$baseUrl/financial-adjustments'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['adjustments'] ?? []);
    }
    throw Exception('Failed to load adjustments (HTTP ${response.statusCode})');
  }

  /// Finance Admin proposes a correction — NOT applied to the balance until
  /// a Super Admin approves it.
  Future<Map<String, dynamic>> propose({
    required String accountType,
    required String accountId,
    required double amount,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/financial-adjustments'),
        headers: await _authHeaders(json: true),
        body: jsonEncode({
          'account_type': accountType,
          'account_id': accountId,
          'amount': amount,
          'reason': reason,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      }

      String message = data['message'] ?? 'Could not propose adjustment';
      if (data['errors'] != null) {
        (data['errors'] as Map).forEach((key, value) {
          message += '\n${(value as List).first}';
        });
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> approve(String adjustmentId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/financial-adjustments/$adjustmentId/approve'),
        headers: await _authHeaders(),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': apiErrorMessage(data, response.statusCode),
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> reject(String adjustmentId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/financial-adjustments/$adjustmentId/reject'),
        headers: await _authHeaders(),
      );
      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 200,
        'message': apiErrorMessage(data, response.statusCode),
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }
}
