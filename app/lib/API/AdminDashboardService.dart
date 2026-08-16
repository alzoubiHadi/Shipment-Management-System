import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class AdminDashboardStats {
  final int registrationPending;
  final int registrationPendingDrivers;
  final int registrationPendingCompanies;
  final int driversActive;
  final int trucksAvailable;
  final int companiesActive;
  final int shipmentsActive;
  final int shipmentsCompletedThisMonth;
  final List<AdminDashboardAlert> alerts;

  AdminDashboardStats({
    required this.registrationPending,
    required this.registrationPendingDrivers,
    required this.registrationPendingCompanies,
    required this.driversActive,
    required this.trucksAvailable,
    required this.companiesActive,
    required this.shipmentsActive,
    required this.shipmentsCompletedThisMonth,
    required this.alerts,
  });

  factory AdminDashboardStats.empty() => AdminDashboardStats(
        registrationPending: 0,
        registrationPendingDrivers: 0,
        registrationPendingCompanies: 0,
        driversActive: 0,
        trucksAvailable: 0,
        companiesActive: 0,
        shipmentsActive: 0,
        shipmentsCompletedThisMonth: 0,
        alerts: const [],
      );

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    final s = Map<String, dynamic>.from(json['stats'] ?? {});
    final alertsRaw = json['alerts'] is List ? json['alerts'] as List : const [];
    return AdminDashboardStats(
      registrationPending: (s['registration_pending'] ?? 0) as int,
      registrationPendingDrivers: (s['registration_pending_drivers'] ?? 0) as int,
      registrationPendingCompanies: (s['registration_pending_companies'] ?? 0) as int,
      driversActive: (s['drivers_active'] ?? 0) as int,
      trucksAvailable: (s['trucks_available'] ?? 0) as int,
      companiesActive: (s['companies_active'] ?? 0) as int,
      shipmentsActive: (s['shipments_active'] ?? 0) as int,
      shipmentsCompletedThisMonth: (s['shipments_completed_this_month'] ?? 0) as int,
      alerts: alertsRaw.map((e) => AdminDashboardAlert.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

class AdminDashboardAlert {
  final String type;
  final int count;
  final String message;

  AdminDashboardAlert({required this.type, required this.count, required this.message});

  factory AdminDashboardAlert.fromJson(Map<String, dynamic> json) => AdminDashboardAlert(
        type: json['type']?.toString() ?? '',
        count: (json['count'] ?? 0) as int,
        message: json['message']?.toString() ?? '',
      );
}

class AdminDashboardService {
  Future<AdminDashboardStats> fetchStats() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/admin/dashboard-stats'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return AdminDashboardStats.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard stats (HTTP ${response.statusCode})');
  }
}
