/// Wraps a row from Laravel's standard `notifications` table, as created by
/// App\Notifications\AppPushNotification::toDatabase(). The `data` column
/// on the backend is itself a JSON object shaped like:
/// { notification_type, title, body, data: {...event-specific payload} }.
class AppNotification {
  final String id;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final inner = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    return AppNotification(
      id: json['id']?.toString() ?? '',
      notificationType: inner['notification_type']?.toString() ?? '',
      title: inner['title']?.toString() ?? 'Notification',
      body: inner['body']?.toString() ?? '',
      data: inner['data'] is Map
          ? Map<String, dynamic>.from(inner['data'] as Map)
          : <String, dynamic>{},
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
