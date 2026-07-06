import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/Truck.dart';
import 'config.dart';

class TruckService {
  Future<List<Truck>> fetchMyTrucks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('id');

    final response = await http.get(
      Uri.parse('$baseUrl/driver/$userId/trucks'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<Truck> trucks =
          (data['trucks'] as List).map((e) => Truck.fromJson(e)).toList();
      return trucks;
    } else {
      throw Exception('Failed to load trucks (HTTP ${response.statusCode})');
    }
  }

  static Future<Map<String, dynamic>> addMyTruck({
    required String truckNumber,
    required String truckType,
    required bool hasRefrigeration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('id');

      final response = await http.post(
        Uri.parse('$baseUrl/driver/$userId/trucks'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'truck_number': truckNumber,
          'truck_type': truckType,
          'has_refrigeration': hasRefrigeration,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'truck': data['truck'],
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
}
