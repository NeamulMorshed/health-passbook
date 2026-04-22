import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'medicine_reminder', 'meal_reminder', 'general'
  final bool isRead;
  final DateTime createdAt;
  final DateTime? scheduledFor;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'general',
    this.isRead = false,
    required this.createdAt,
    this.scheduledFor,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'general',
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledFor: (map['scheduledFor'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'type': type,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
        'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
      };
}
