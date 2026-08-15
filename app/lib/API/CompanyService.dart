import 'dart:convert';

import 'package:app/models/Company.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/Shipment.dart';
import 'config.dart';


class CompanyService {

  /// Company app: its own record (balance/credit_limit) — used by the
  /// balance page.
  Future<Company> fetchMyCompany() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/my-company'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Company.fromMap(data['company']);
    }
    throw Exception('Failed to load company (HTTP ${response.statusCode})');
  }

  static Future<Map<String, dynamic>> setCreditLimit({
    required String companyId,
    required double creditLimit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/companies/$companyId/credit-limit'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'credit_limit': creditLimit}),
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

  Future<List<Company>> fetchCompaines() async {
    final prefs = await SharedPreferences.getInstance();
    //
    String? token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('${baseUrl}/get/companies'),
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers here if needed, e.g.:
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);


    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Company> companies =
      (data['companies'] as List)
          .map((e) => Company.fromMap(e))
          .toList();

      return companies;
    } else {
      throw Exception(
        'Failed to load companies (HTTP ${response.statusCode})',
      );
    }
  }
  Future<List<Company>> fetchCompainesdeleted() async {
    final prefs = await SharedPreferences.getInstance();
    //
    String? token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('${baseUrl}/get/companies/trashed'),
      headers: {
        'Content-Type': 'application/json',
        // Add auth headers here if needed, e.g.:
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);


    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<Company> companies =
      (data['companies'] as List)
          .map((e) => Company.fromMap(e))
          .toList();

      return companies;
    } else {
      throw Exception(
        'Failed to load companies (HTTP ${response.statusCode})',
      );
    }
  }
  static Future<Map<String, dynamic>> createCompany(Company company) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/add/companies'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': company.name,
          'email': company.email,
          'password': company.password,
          'phone': company.phone,
        }),
      );

      print(response.body);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'],
          'company': data['company'],
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
  static Future<Map<String, dynamic>> updateCompany(Company company) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/update/companies/${company.id}'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': company.name,
          'email': company.email,
          'password': company.password,
          'phone': company.phone,
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

  static Future<bool> deleteCompany(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('$baseUrl/delete/companies/$id'),
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
  static Future<bool> restoreCompany(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.put(
        Uri.parse('$baseUrl/restore/companies/$id'),
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

}