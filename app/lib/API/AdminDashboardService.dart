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
  // Unified Approvals redesign (2026-08-22) — mirrors
  // AdminDashboardController::stats()'s new fields.
  final int pendingApprovals; // registration + document renewals + changes required
  final int documentRenewalsPending;
  final int changesRequiredTotal;
  final int documentsExpiringSoon;
  final int documentsExpired;
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
    required this.pendingApprovals,
    required this.documentRenewalsPending,
    required this.changesRequiredTotal,
    required this.documentsExpiringSoon,
    required this.documentsExpired,
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
        pendingApprovals: 0,
        documentRenewalsPending: 0,
        changesRequiredTotal: 0,
        documentsExpiringSoon: 0,
        documentsExpired: 0,
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
      pendingApprovals: (s['pending_approvals'] ?? 0) as int,
      documentRenewalsPending: (s['document_renewals_pending'] ?? 0) as int,
      changesRequiredTotal: (s['changes_required_total'] ?? 0) as int,
      documentsExpiringSoon: (s['documents_expiring_soon'] ?? 0) as int,
      documentsExpired: (s['documents_expired'] ?? 0) as int,
      alerts: alertsRaw.map((e) => AdminDashboardAlert.fromJson(Map<String, dynamic>.from(e))).toList(),
    );
  }
}

/// One affected driver/company from AdminDashboardController::documentAlerts()
/// — the alert-click "who's affected" list, deliberately separate from an
/// approval (they may not have submitted a renewal yet).
class AdminDocumentAlertItem {
  final String subjectType; // 'driver' | 'company'
  final String subjectId;
  final String name;
  final String documentType;
  final String? expiryDate;

  AdminDocumentAlertItem({
    required this.subjectType,
    required this.subjectId,
    required this.name,
    required this.documentType,
    this.expiryDate,
  });

  factory AdminDocumentAlertItem.fromJson(Map<String, dynamic> json) => AdminDocumentAlertItem(
        subjectType: json['subject_type']?.toString() ?? '',
        subjectId: json['subject_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        documentType: json['document_type']?.toString() ?? '',
        expiryDate: json['expiry_date']?.toString(),
      );
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

  /// Backs the dashboard alert tap-through — [status] is 'expiring_soon' or
  /// 'expired', matching AdminDashboardController::documentAlerts()'s
  /// `status` query param.
  Future<List<AdminDocumentAlertItem>> fetchDocumentAlerts(String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/admin/document-alerts?status=$status'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['items'] as List).map((e) => AdminDocumentAlertItem.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('Failed to load document alerts (HTTP ${response.statusCode})');
  }
}
