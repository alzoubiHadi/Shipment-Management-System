import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/PriceListEntry.dart';
import 'config.dart';

/// Finance Admin: central price matrix management (UC-33). CSV-based on
/// purpose — see server's PriceListController docblock for why (no
/// verified-installable Excel-writing package in this environment; a CSV
/// opens/saves in Excel identically for this purpose).
class PriceListService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<PriceListEntry>> fetchEntries() async {
    final response = await http.get(
      Uri.parse('$baseUrl/price-list'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['entries'] as List)
          .map((e) => PriceListEntry.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load price list (HTTP ${response.statusCode})');
  }

  /// Returns the raw CSV text of the full grid (every destination x every
  /// truck type), pre-filled with existing prices — blank cells are still
  /// unpriced. The caller decides how to present/save it.
  Future<String> exportCsv() async {
    final response = await http.get(
      Uri.parse('$baseUrl/price-list/export'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      return response.body;
    }
    throw Exception('Failed to export price list (HTTP ${response.statusCode})');
  }

  /// Uploads an edited CSV. Returns {updated, skipped: [messages]}.
  Future<Map<String, dynamic>> importCsv({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/price-list/import'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body);

    return {
      'success': response.statusCode == 200,
      'message': data['message'] ?? 'Server Error (${response.statusCode})',
      'updated': data['updated'] ?? 0,
      'skipped': data['skipped'] is List
          ? List<String>.from(data['skipped'])
          : <String>[],
    };
  }
}
