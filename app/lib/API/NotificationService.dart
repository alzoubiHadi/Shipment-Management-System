import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/AppNotification.dart';
import 'config.dart';

/// In-app notification center (always populated, independent of whether
/// real FCM push is configured — see server's NotificationController).
class NotificationService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<({List<AppNotification> notifications, int unreadCount})>
      fetchNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _authHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final notifications = (data['notifications'] as List)
          .map((e) => AppNotification.fromJson(e))
          .toList();
      return (
        notifications: notifications,
        unreadCount: data['unread_count'] is int ? data['unread_count'] as int : 0,
      );
    }
    throw Exception(
        'Failed to load notifications (HTTP ${response.statusCode})');
  }

  Future<bool> markRead(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$id/read'),
      headers: await _authHeaders(),
    );
    return response.statusCode == 200;
  }

  Future<bool> markAllRead() async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: await _authHeaders(),
    );
    return response.statusCode == 200;
  }

  /// Registers/updates this device's FCM token. Safe to call even without
  /// firebase_messaging wired in yet — simply not called until it is.
  Future<bool> updateFcmToken(String fcmToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/me/fcm-token'),
      headers: await _authHeaders(),
      body: jsonEncode({'fcm_token': fcmToken}),
    );
    return response.statusCode == 200;
  }
}
