import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ActivityLogEntry.dart';
import 'config.dart';

/// NFR (Security): read-only client for the Super-Admin-only audit trail.
class ActivityLogService {
  Future<List<ActivityLogEntry>> fetchLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/activity-logs'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['logs'] as List)
          .map((e) => ActivityLogEntry.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load activity log (HTTP ${response.statusCode})');
  }
}
