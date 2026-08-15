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

  // ── Company: list this company's own offers ────────────────────────────
  Future<List<ShipmentOffer>> fetchMyOffers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-shipment-offers'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['offers'] as List)
          .map((e) => ShipmentOffer.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load your offers (HTTP ${response.statusCode})');
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

  // ── Any authenticated user: the fixed list of valid external destinations
  // (used by the company offer-creation form when order_type = external).
  static Future<List<String>> fetchExternalDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/price-list/destinations'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['destinations'] ?? []);
    }
    throw Exception('Failed to load destinations (HTTP ${response.statusCode})');
  }

  // ── Company: create a new offer (self-service, UC-11) ──────────────────
  // Pricing is fully automatic (or falls back to manual review) — no price
  // fields are sent here, and there is no company picker: the backend
  // resolves the company from the authenticated user.
  static Future<Map<String, dynamic>> createOffer({
    required String origin,
    required String destination,
    double? originLat,
    double? originLng,
    String? weight,
    String? description,
    required bool needsPermit,
    required bool isHazardous,
    required bool isFragile,
    required String orderType, // 'internal' or 'external'
    required String requiredTruckType,
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
          'origin': origin,
          'origin_lat': originLat,
          'origin_lng': originLng,
          'destination': destination,
          'weight': weight,
          'description': description,
          'needs_permit': needsPermit,
          'is_hazardous': isHazardous,
          'is_fragile': isFragile,
          'order_type': orderType,
          'required_truck_type': requiredTruckType,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'offer': data['offer'],
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

  // ── Company: raise the price shown to drivers (can only go up) ────────
  static Future<Map<String, dynamic>> raisePrice({
    required int offerId,
    required double priceToClient,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/shipment-offers/$offerId/raise-price'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'price_to_client': priceToClient}),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'offer': data['offer'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── CRM Admin: set a manual price for an 'awaiting_manual_price' offer ─
  static Future<Map<String, dynamic>> manualPrice({
    required int offerId,
    required double priceToDriver,
    required double priceToClient,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipment-offers/$offerId/manual-price'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'price_to_driver': priceToDriver,
          'price_to_client': priceToClient,
        }),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'offer': data['offer'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Super Admin: force a new matching round right now ──────────────────
  static Future<Map<String, dynamic>> rematch(int offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipment-offers/$offerId/rematch'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'offer': data['offer'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ── Super Admin: manually assign an escalated offer to a driver+truck ──
  static Future<Map<String, dynamic>> assignDriver({
    required int offerId,
    required int driverId,
    required int truckId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/shipment-offers/$offerId/assign-driver'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'driver_id': driverId, 'truck_id': truckId}),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'shipment': data['shipment'],
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

  // ── Company/Admin: cancel a not-yet-accepted offer with a reason ───────
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
