import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/FinancialTransaction.dart';
import 'config.dart';

class FinancialTransactionService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// The logged-in company's or driver's own statement.
  Future<List<FinancialTransaction>> myTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/my-transactions'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['transactions'] as List)
          .map((e) => FinancialTransaction.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load transactions (HTTP ${response.statusCode})');
  }

  /// Finance Admin: any account's statement.
  Future<List<FinancialTransaction>> fetchFor({
    required String accountType,
    required String accountId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/financial-transactions?account_type=$accountType&account_id=$accountId'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['transactions'] as List)
          .map((e) => FinancialTransaction.fromJson(e))
          .toList();
    }
    throw Exception('Failed to load transactions (HTTP ${response.statusCode})');
  }
}
