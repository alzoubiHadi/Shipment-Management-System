import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Reports are simple, ad-hoc JSON shapes (not full domain models), so this
/// service just returns the decoded maps/lists directly for the report
/// screens to render.
class ReportService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Admin: completed/cancelled shipment counts for every driver.
  Future<List<Map<String, dynamic>>> fetchDriverReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/drivers'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['drivers'] ?? []);
    }
    throw Exception('Failed to load driver report (HTTP ${response.statusCode})');
  }

  /// Driver: this driver's own completed/cancelled counts.
  Future<Map<String, dynamic>> fetchMyDriverReport() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('id');

    final response = await http.get(
      Uri.parse('$baseUrl/driver/$userId/report'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load your report (HTTP ${response.statusCode})');
  }

  /// Admin: per-company shipment counts by status + top destinations.
  Future<List<Map<String, dynamic>>> fetchCompanyReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/companies'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['companies'] ?? []);
    }
    throw Exception('Failed to load company report (HTTP ${response.statusCode})');
  }

  /// Admin: overall commission earned across delivered shipments.
  Future<Map<String, dynamic>> fetchSummaryReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/summary'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load summary report (HTTP ${response.statusCode})');
  }
}
