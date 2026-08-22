import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/PriceListEntry.dart';
import 'config.dart';
import 'error_messages.dart';

/// Zones / Smart Pricing Engine (2026-08-27) — one zone-based lane row from
/// `GET /price-list/zone-lanes`, used by the Admin "Market Adjustment"
/// screen. Deliberately keeps reference_price/suggested_low/suggested_high
/// as read-only display fields — only marketAdjustmentPercent is ever
/// edited (see PriceListEntry::adjustedSuggestedPrice() on the backend).
class ZoneLaneEntry {
  final int id;
  final String originLabel;
  final String destinationLabel;
  final String truckType;
  final double? referencePrice;
  final double? suggestedLow;
  final double? suggestedHigh;
  final int? historicalTripCount;
  final String? confidence;
  final double marketAdjustmentPercent;
  final String? pricingLevel;

  ZoneLaneEntry({
    required this.id,
    required this.originLabel,
    required this.destinationLabel,
    required this.truckType,
    this.referencePrice,
    this.suggestedLow,
    this.suggestedHigh,
    this.historicalTripCount,
    this.confidence,
    required this.marketAdjustmentPercent,
    this.pricingLevel,
  });

  double? get adjustedSuggestedPrice {
    if (referencePrice == null) return null;
    return double.parse((referencePrice! * (1 + marketAdjustmentPercent / 100)).toStringAsFixed(2));
  }

  static String _zoneLabel(Map<String, dynamic>? zone) {
    if (zone == null) return '—';
    final parts = [zone['name'], zone['city'], zone['country']]
        .where((p) => p != null && p.toString().isNotEmpty)
        .map((p) => p.toString());
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  factory ZoneLaneEntry.fromJson(Map<String, dynamic> json) {
    return ZoneLaneEntry(
      id: json['id'] as int,
      originLabel: _zoneLabel(json['origin_zone'] as Map<String, dynamic>?),
      destinationLabel: _zoneLabel(json['destination_zone'] as Map<String, dynamic>?),
      truckType: json['truck_type']?.toString() ?? '',
      referencePrice: json['reference_price'] != null ? double.tryParse(json['reference_price'].toString()) : null,
      suggestedLow: json['suggested_low'] != null ? double.tryParse(json['suggested_low'].toString()) : null,
      suggestedHigh: json['suggested_high'] != null ? double.tryParse(json['suggested_high'].toString()) : null,
      historicalTripCount: json['historical_trip_count'] is int ? json['historical_trip_count'] : int.tryParse(json['historical_trip_count']?.toString() ?? ''),
      confidence: json['confidence']?.toString(),
      marketAdjustmentPercent: double.tryParse(json['market_adjustment_percent']?.toString() ?? '') ?? 0,
      pricingLevel: json['pricing_level']?.toString(),
    );
  }
}

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

  // ── Zones / Smart Pricing Engine (2026-08-27): Admin Market Adjustment ──

  Future<Map<String, dynamic>> fetchZoneLanes({String search = '', int page = 1}) async {
    final uri = Uri.parse('$baseUrl/price-list/zone-lanes').replace(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      'page': page.toString(),
    });

    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'entries': (data['entries'] as List).map((e) => ZoneLaneEntry.fromJson(e)).toList(),
        'currentPage': data['current_page'] ?? 1,
        'lastPage': data['last_page'] ?? 1,
        'total': data['total'] ?? 0,
      };
    }
    throw Exception('Failed to load zone lanes (HTTP ${response.statusCode})');
  }

  Future<Map<String, dynamic>> updateMarketAdjustment({
    required int entryId,
    required double marketAdjustmentPercent,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/price-list/zone-lanes/$entryId/market-adjustment'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'market_adjustment_percent': marketAdjustmentPercent}),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': apiErrorMessage(data, response.statusCode),
        'entry': data['entry'] != null ? ZoneLaneEntry.fromJson(data['entry']) : null,
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
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
      'message': apiErrorMessage(data, response.statusCode),
      'updated': data['updated'] ?? 0,
      'skipped': data['skipped'] is List
          ? List<String>.from(data['skipped'])
          : <String>[],
    };
  }
}
