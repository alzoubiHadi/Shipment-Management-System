import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ComplianceReport.dart';
import 'config.dart';

/// UC-25/UC-26: filing, reviewing, and appealing driver compliance/safety
/// reports.
class ComplianceReportService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Company or admin: files a report against a driver, with an optional
  /// evidence file (photo/document).
  Future<Map<String, dynamic>> fileReport({
    required String driverId,
    required String category,
    required String description,
    Uint8List? evidenceBytes,
    String? evidenceFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/drivers/$driverId/compliance-reports'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['category'] = category;
      request.fields['description'] = description;
      if (evidenceBytes != null && evidenceFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'evidence_file',
          evidenceBytes,
          filename: evidenceFileName,
        ));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Super Admin: every report, optionally filtered by status.
  Future<List<ComplianceReport>> fetchAll({String? status}) async {
    final uri = status == null
        ? Uri.parse('$baseUrl/compliance-reports')
        : Uri.parse('$baseUrl/compliance-reports?status=$status');

    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['reports'] as List)
          .map((e) => ComplianceReport.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load compliance reports (HTTP ${response.statusCode})');
  }

  /// Driver: their own report history.
  Future<List<ComplianceReport>> myReports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-compliance-reports'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['reports'] as List)
          .map((e) => ComplianceReport.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load compliance reports (HTTP ${response.statusCode})');
  }

  /// Super Admin: dismiss or uphold (with a resulting action) a report.
  static Future<Map<String, dynamic>> resolve({
    required int reportId,
    required String decision, // dismiss | uphold
    String? resultingAction, // warning | suspension | ban (required if uphold)
  }) async {
    return _post('$baseUrl/compliance-reports/$reportId/resolve', {
      'decision': decision,
      if (resultingAction != null) 'resulting_action': resultingAction,
    });
  }

  /// Driver (UC-26): appeals an upheld report.
  static Future<Map<String, dynamic>> appeal({
    required int reportId,
    required String appealText,
  }) async {
    return _post('$baseUrl/compliance-reports/$reportId/appeal', {
      'appeal_text': appealText,
    });
  }

  /// Super Admin: accepts or rejects a driver's appeal.
  static Future<Map<String, dynamic>> resolveAppeal({
    required int reportId,
    required String decision, // accept | reject
  }) async {
    return _post('$baseUrl/compliance-reports/$reportId/resolve-appeal', {
      'decision': decision,
    });
  }

  static Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'report': data['report'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
