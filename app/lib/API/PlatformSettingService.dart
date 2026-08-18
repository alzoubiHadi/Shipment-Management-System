import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// A single row from `GET /platform-settings` — always a string `value`
/// (the backend stores everything as text; callers parse to num/etc as
/// needed). See server's PlatformSettingController::EDITABLE_KEYS for the
/// fixed whitelist of keys this can ever contain.
class PlatformSettingEntry {
  final String key;
  final String value;

  PlatformSettingEntry({required this.key, required this.value});

  factory PlatformSettingEntry.fromJson(Map<String, dynamic> json) {
    return PlatformSettingEntry(
      key: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

/// Finance Admin: platform-wide configuration (profit margin, matching
/// weights/timeout, driver-ops defaults) — see server's
/// PlatformSettingController. Never had a Flutter screen before
/// (2026-08-27 gap found while building the Zones/Pricing feature).
class PlatformSettingService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<PlatformSettingEntry>> fetchSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/platform-settings'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['settings'] as List).map((e) => PlatformSettingEntry.fromJson(e)).toList();
    }
    throw Exception('Failed to load platform settings (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> updateSetting({required String key, required String value}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/platform-settings/$key'),
        headers: await _authHeaders(),
        body: jsonEncode({'value': value}),
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
