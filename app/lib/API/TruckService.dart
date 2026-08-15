import 'dart:convert';
import 'dart:typed_data';

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

  /// Admin: same endpoint as [fetchMyTrucks] but for an arbitrary driver
  /// (by their user id) — used by the Super Admin "assign driver" flow for
  /// escalated offers, where the admin needs to pick one of the chosen
  /// driver's own trucks.
  Future<List<Truck>> fetchTrucksForDriver(String driverUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/driver/$driverUserId/trucks'),
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

  /// license_file* are required by the backend (UC-9: vehicle license
  /// upload) — pass the bytes read via file_picker's withData:true so this
  /// works on web as well as mobile/desktop (no reliance on a filesystem
  /// path, which web file_picker doesn't provide).
  static Future<Map<String, dynamic>> addMyTruck({
    required String truckNumber,
    required String truckType,
    required bool hasRefrigeration,
    Uint8List? licenseFileBytes,
    String? licenseFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('id');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/driver/$userId/trucks'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['truck_number'] = truckNumber;
      request.fields['truck_type'] = truckType;
      request.fields['has_refrigeration'] = hasRefrigeration ? '1' : '0';

      if (licenseFileBytes != null && licenseFileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'license_file',
          licenseFileBytes,
          filename: licenseFileName,
        ));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
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
