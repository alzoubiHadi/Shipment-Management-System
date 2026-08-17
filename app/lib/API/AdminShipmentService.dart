import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Admin Shipments redesign (2026-08-24): thin wrapper around the new
/// unified list + status-aware detail endpoints (AdminShipmentController).
/// Returns raw decoded JSON on purpose (not a strongly-typed model for the
/// detail call) — the detail payload's shape genuinely differs between a
/// still-matching offer (`kind: 'offer'`) and a real shipment
/// (`kind: 'shipment'`), so each screen reads only the fields it needs
/// straight off the map rather than forcing one rigid class to cover both.
class AdminShipmentService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// [group]: all | active | pending | delivered | cancelled.
  static Future<Map<String, dynamic>> fetchShipments({
    String group = 'all',
    String search = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final headers = await _headers();

    final uri = Uri.parse('$baseUrl/admin/shipments').replace(queryParameters: {
      'group': group,
      if (search.isNotEmpty) 'search': search,
      'page': '$page',
      'per_page': '$perPage',
    });

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load shipments (HTTP ${response.statusCode})');
  }

  static Future<Map<String, dynamic>> fetchDetail(String trackingNumber) async {
    final headers = await _headers();

    final response = await http.get(
      Uri.parse('$baseUrl/admin/shipments/$trackingNumber'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load shipment detail (HTTP ${response.statusCode})');
  }
}
