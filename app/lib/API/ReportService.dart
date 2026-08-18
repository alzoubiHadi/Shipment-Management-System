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

  /// Reports date filter (2026-08-26): 'all' (default, no filter), 'month'
  /// (this calendar month), or '30d' (last 30 days) — mirrors
  /// ReportController::periodStart() on the backend. Omitted from the
  /// query string entirely when 'all', so existing callers that don't pass
  /// a period keep hitting the exact same URL as before.
  String _periodQuery(String period) => period == 'all' ? '' : '?period=$period';

  /// Admin: completed/cancelled shipment counts for every driver.
  Future<List<Map<String, dynamic>>> fetchDriverReports({String period = 'all'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/drivers${_periodQuery(period)}'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['drivers'] ?? []);
    }
    throw Exception('Failed to load driver report (HTTP ${response.statusCode})');
  }

  /// Driver: this driver's own report (balance, earnings, pending/disputed
  /// amounts, rating, compliance).
  ///
  /// Security fix (2026-08-26): this used to build `/driver/$userId/report`
  /// from the locally-stored user id and send that id in the URL — the old
  /// backend endpoint trusted it blindly (IDOR: any authenticated user
  /// could edit the URL to read a different driver's balance/earnings).
  /// `/my-driver-report` takes no id at all; the server resolves the
  /// driver from the authenticated token instead. See
  /// ReportController::myReport().
  Future<Map<String, dynamic>> fetchMyDriverReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-driver-report'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load your report (HTTP ${response.statusCode})');
  }

  /// Admin: per-company shipment counts by status + top destinations.
  Future<List<Map<String, dynamic>>> fetchCompanyReports({String period = 'all'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/companies${_periodQuery(period)}'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['companies'] ?? []);
    }
    throw Exception('Failed to load company report (HTTP ${response.statusCode})');
  }

  /// Admin: overall commission earned across delivered+confirmed
  /// shipments, plus a delivered/active/cancelled breakdown for the
  /// dashboard chart.
  Future<Map<String, dynamic>> fetchSummaryReport({String period = 'all'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/summary${_periodQuery(period)}'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load summary report (HTTP ${response.statusCode})');
  }
}
