import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ShipmentOffer.dart';
import 'config.dart';

class ShipmentOfferService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Admin: list every offer ────────────────────────────────────────────
  Future<List<ShipmentOffer>> fetchAllOffers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/shipment-offers'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['offers'] as List)
          .map((e) => ShipmentOffer.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load offers (HTTP ${response.statusCode})');
  }

  // ── Driver: list offers this driver currently qualifies for ───────────
  Future<List<ShipmentOffer>> fetchAvailableOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('id');

    final response = await http.get(
      Uri.parse('$baseUrl/driver/$userId/available-offers'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['offers'] as List)
          .map((e) => ShipmentOffer.fromJson(e))
          .toList();
    }
    throw Exception(
        'Failed to load available offers (HTTP ${response.statusCode})');
  }

  // ── Admin: create a new offer ──────────────────────────────────────────
  static Future<Map<String, dynamic>> createOffer({
    required int companyId,
    required String origin,
    required String destination,
    String? weight,
    String? description,
    required String cargoType,
    required bool requiresCrossBorder,
    String? requiredTruckType,
    String? priceToDriver,
    String? priceToClient,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipment-offers'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'company_id': companyId,
          'origin': origin,
          'destination': destination,
          'weight': weight,
          'description': description,
          'cargo_type': cargoType,
          'requires_cross_border': requiresCrossBorder,
          'required_truck_type': requiredTruckType,
          'price_to_driver': priceToDriver,
          'price_to_client': priceToClient,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'eligible_drivers_count': data['eligible_drivers_count'],
        };
      }

      if (response.statusCode == 422) {
        String message = data['message'] ?? 'Validation failed';
        if (data['errors'] != null) {
          data['errors'].forEach((key, value) {
            message += '\n${value[0]}';
          });
        }
        return {'success': false, 'message': message};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Driver: accept an offer with a chosen truck ────────────────────────
  static Future<Map<String, dynamic>> acceptOffer({
    required int offerId,
    required int truckId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('id');

      final response = await http.post(
        Uri.parse('$baseUrl/shipment-offers/accept'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'offer_id': offerId,
          'driver_user_id': userId,
          'truck_id': truckId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'shipment': data['shipment'],
        };
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Admin: cancel a pending offer with a reason ────────────────────────
  static Future<bool> cancelOffer({
    required int offerId,
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.put(
      Uri.parse('$baseUrl/shipment-offers/$offerId/cancel'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'cancellation_reason': reason}),
    );

    return response.statusCode == 200;
  }
}
