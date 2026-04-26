import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  medicineReminder('medicine_reminder'),
  mealReminder('meal_reminder'),
  appointment('appointment'),
  general('general');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String? value) => switch (value) {
    'medicine_reminder' => NotificationType.medicineReminder,
    'meal_reminder'     => NotificationType.mealReminder,
    'appointment'       => NotificationType.appointment,
    _                   => NotificationType.general,
  };
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? scheduledFor;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = NotificationType.general,
    this.isRead = false,
    required this.createdAt,
    this.scheduledFor,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id:           id,
      title:        map['title']  ?? '',
      body:         map['body']   ?? '',
      type:         NotificationType.fromString(map['type']),
      isRead:       map['isRead'] ?? false,
      createdAt:    (map['createdAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledFor: (map['scheduledFor'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title':        title,
    'body':         body,
    'type':         type.value,
    'isRead':       isRead,
    'createdAt':    Timestamp.fromDate(createdAt),
    'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
  };
}
