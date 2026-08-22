import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/PaymentOrder.dart';
import 'config.dart';
import 'error_messages.dart';

/// UC-28/UC-29: company balance top-up requests.
class PaymentOrderService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Company: submit a top-up request with a bank-transfer receipt.
  Future<Map<String, dynamic>> create({
    required double amount,
    required Uint8List receiptBytes,
    required String receiptFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/payment-orders'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['amount'] = amount.toString();
      request.files.add(http.MultipartFile.fromBytes(
        'receipt_file',
        receiptBytes,
        filename: receiptFileName,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'message': apiErrorMessage(data, response.statusCode),
        'order': data['order'],
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }

  /// Company: their own top-up history.
  Future<List<PaymentOrder>> myOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-payment-orders'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['orders'] as List)
          .map((e) => PaymentOrder.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load payment orders (HTTP ${response.statusCode})');
  }

  /// Finance Admin: every top-up request.
  Future<List<PaymentOrder>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payment-orders'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['orders'] as List)
          .map((e) => PaymentOrder.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load payment orders (HTTP ${response.statusCode})');
  }

  static Future<Map<String, dynamic>> approve(int orderId) async {
    return _postAction('$baseUrl/payment-orders/$orderId/approve', {});
  }

  static Future<Map<String, dynamic>> reject(int orderId, String reason) async {
    return _postAction(
      '$baseUrl/payment-orders/$orderId/reject',
      {'rejection_reason': reason},
    );
  }

  static Future<Map<String, dynamic>> _postAction(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': apiErrorMessage(data, response.statusCode),
        'order': data['order'],
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }
}
