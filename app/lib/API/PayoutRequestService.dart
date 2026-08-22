import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/PayoutRequest.dart';
import 'config.dart';
import 'error_messages.dart';

/// UC-30/31/32: driver withdrawal requests.
class PayoutRequestService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Driver: request a withdrawal.
  static Future<Map<String, dynamic>> create(double amount) async {
    return _postAction('$baseUrl/payout-requests', {'amount': amount}, 201);
  }

  /// Driver: cancel their own still-pending request.
  static Future<Map<String, dynamic>> cancel(int payoutId) async {
    return _putAction('$baseUrl/payout-requests/$payoutId/cancel', {});
  }

  /// Driver: confirms a 'paid' payout actually arrived — this is what pays
  /// out their balance.
  static Future<Map<String, dynamic>> confirmReceipt(int payoutId) async {
    return _postAction('$baseUrl/payout-requests/$payoutId/confirm', {}, 200);
  }

  /// Driver: reports the transfer never arrived.
  static Future<Map<String, dynamic>> disputeReceipt(
    int payoutId,
    String reason,
  ) async {
    return _postAction(
      '$baseUrl/payout-requests/$payoutId/dispute',
      {'dispute_reason': reason},
      200,
    );
  }

  /// Driver: their own payout history.
  Future<List<PayoutRequest>> myRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-payout-requests'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['payouts'] as List)
          .map((e) => PayoutRequest.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load payout requests (HTTP ${response.statusCode})');
  }

  /// Finance Admin: every payout request.
  Future<List<PayoutRequest>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$baseUrl/payout-requests'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['payouts'] as List)
          .map((e) => PayoutRequest.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load payout requests (HTTP ${response.statusCode})');
  }

  /// Finance Admin: records the outside-the-app transfer with a receipt.
  static Future<Map<String, dynamic>> markPaid({
    required int payoutId,
    required Uint8List receiptBytes,
    required String receiptFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/payout-requests/$payoutId/mark-paid'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'transfer_receipt_file',
        receiptBytes,
        filename: receiptFileName,
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'message': apiErrorMessage(data, response.statusCode),
        'payout': data['payout'],
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }

  static Future<Map<String, dynamic>> reject(int payoutId, String reason) async {
    return _postAction(
      '$baseUrl/payout-requests/$payoutId/reject',
      {'rejection_reason': reason},
      200,
    );
  }

  /// Finance/Super Admin: settles a disputed payout ('confirm' or 'retry').
  static Future<Map<String, dynamic>> resolveDispute(
    int payoutId,
    String resolution,
  ) async {
    return _postAction(
      '$baseUrl/payout-requests/$payoutId/resolve-dispute',
      {'resolution': resolution},
      200,
    );
  }

  static Future<Map<String, dynamic>> _postAction(
    String url,
    Map<String, dynamic> body,
    int successCode,
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
        'success': response.statusCode == successCode,
        'message': apiErrorMessage(data, response.statusCode),
        'payout': data['payout'],
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }

  static Future<Map<String, dynamic>> _putAction(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.put(
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
        'payout': data['payout'],
      };
    } catch (e) {
      return {'success': false, 'message': networkErrorMessage(e)};
    }
  }
}
