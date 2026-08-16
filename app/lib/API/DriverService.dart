import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import '../models/Driver.dart';
import '../models/DriverRating.dart';
import 'config.dart';

class DriverService {
  Future<List<Driver>> fetchDriver() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/get/drivers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print(response.body);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Driver> drivers = (data['drivers'] as List)
          .map((e) => Driver.fromMap(e))
          .toList();

      return drivers;
    } else {
      throw Exception(
        'Failed to load drivers (HTTP ${response.statusCode})',
      );
    }
  }
  Future<List<Driver>> fetchDeletedDriver() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/get/drivers/trashed'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print(response.body);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Driver> drivers = (data['drivers'] as List)
          .map((e) => Driver.fromMap(e))
          .toList();

      return drivers;
    } else {
      throw Exception(
        'Failed to load drivers (HTTP ${response.statusCode})',
      );
    }
  }

  static Future<Map<String, dynamic>> createDriver(Driver driver) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/add/drivers'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': driver.name,
          'email': driver.email,
          'password': driver.password,
          'phone': driver.phone,
          'truck_number': driver.truck_number,
          'truck_type': driver.truck_type,
          'nationality': driver.nationality,
          'age': driver.age,
          'driver_license': driver.driver_license,
          'license_expiry': driver.license_expiry,
        }),
      );

      print(response.body);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'driver': data['driver'],
        };
      }

      if (response.statusCode == 422) {
        String message = data['message'] ?? 'Validation failed';

        if (data['errors'] != null) {
          data['errors'].forEach((key, value) {
            message += '\n${value[0]}';
          });
        }

        return {
          'success': false,
          'message': message,
        };
      }

      return {
        'success': false,
        'message':
        data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
  static Future<Map<String, dynamic>> updateDriver(Driver driver) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/update/drivers/${driver.id}'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': driver.name,
          'email': driver.email,
          'password': driver.password,
          'phone': driver.phone,
          'truck_number': driver.truck_number,
          'truck_type': driver.truck_type,
          'nationality': driver.nationality,
          'age': driver.age,
          'driver_license': driver.driver_license,
          'license_expiry': driver.license_expiry,
        }),
      );

      print(response.body);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'driver': data['driver'],
        };
      }

      if (response.statusCode == 422) {
        String message = data['message'] ?? 'Validation failed';

        if (data['errors'] != null) {
          data['errors'].forEach((key, value) {
            message += '\n${value[0]}';
          });
        }

        return {
          'success': false,
          'message': message,
        };
      }

      return {
        'success': false,
        'message':
        data['message'] ?? 'Server Error (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<bool> deleteDriver(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('$baseUrl/delete/drivers/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(response.body);

      return response.statusCode == 200;
    } catch (e) {
      print(e);
      return false;
    }
  }
  static Future<bool> restoreDrivers(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/restore/drivers/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(response.body);

      return response.statusCode == 200;
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Admin approves a pending (self-registered) driver. Fails with the
  /// document issues if the server finds any (expired/missing license,
  /// passport, or residency) so the admin knows exactly why.
  static Future<Map<String, dynamic>> approveDriver(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$id/approve'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(response.body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }

      String message = data['message'] ?? 'Could not approve driver';
      if (data['document_issues'] != null) {
        message += '\n' + (data['document_issues'] as List).join('\n');
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Admin rejects a pending (self-registered) driver, optionally with a
  /// reason that will be shown to the driver in the app.
  static Future<bool> rejectDriver(String id, {String? reason}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$id/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
      );

      print(response.body);
      return response.statusCode == 200;
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// Super Admin: freezes a driver directly (compliance_status='suspended'),
  /// skipping the report/escalation workflow — for serious findings that
  /// don't need the full review process.
  static Future<Map<String, dynamic>> suspendDriver(String id, String reason) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$id/suspend'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': reason}),
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

  static Future<Map<String, dynamic>> reactivateDriver(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/drivers/$id/reactivate'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
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

  /// UC-24: Super Admin rates a driver directly (no shipment attached).
  static Future<Map<String, dynamic>> rateDriver({
    required String driverId,
    required int score,
    String? comment,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/drivers/$driverId/rate'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'score': score,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        }),
      );

      final data = jsonDecode(response.body);
      return {
        'success': response.statusCode == 201,
        'message': data['message'] ?? 'Server Error (${response.statusCode})',
        'driver_rating': data['driver_rating'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// UC-10: driver toggles their own "available for work" status.
  /// [status] must be one of 'available' | 'busy' | 'unavailable'.
  static Future<Map<String, dynamic>> updateMyStatus(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userId = prefs.getString('id');

      final response = await http.put(
        Uri.parse('$baseUrl/driver/$userId/status'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
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

  /// Full rating history for a driver — admin driver-detail view.
  static Future<List<DriverRating>> fetchDriverRatings(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/drivers/$driverId/ratings'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['ratings'] as List)
          .map((e) => DriverRating.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load ratings (HTTP ${response.statusCode})');
  }
}