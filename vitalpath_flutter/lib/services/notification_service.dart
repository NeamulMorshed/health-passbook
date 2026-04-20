import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/constants/app_constants.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local notifications setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create Android notification channels
    await _createChannel(AppConstants.notifChannelMedicine, 'Medicine Reminders', 'Reminders to take your medicine');
    await _createChannel(AppConstants.notifChannelAppointment, 'Appointment Reminders', 'Appointment updates and reminders');
    await _createChannel(AppConstants.notifChannelGeneral, 'General', 'General app notifications');

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          id: message.hashCode,
          title: notification.title ?? 'VitalPath',
          body: notification.body ?? '',
          channel: message.data['channel'] ?? AppConstants.notifChannelGeneral,
        );
      }
    });
  }

  Future<void> _createChannel(String id, String name, String desc) async {
    final channel = AndroidNotificationChannel(id, name, description: desc, importance: Importance.high);
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<String?> getToken() => _fcm.getToken();

  Future<void> saveToken(String uid, String token) async {
    // Save to Firestore under users/{uid}/fcmToken
    // Done via FirestoreService to avoid circular dependency
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String channel = AppConstants.notifChannelGeneral,
  }) async {
    await _local.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(channel, channel, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> scheduleMedicineReminder({
    required int id,
    required String medicineName,
    required DateTime time,
  }) async {
    await _local.zonedSchedule(
      id,
      'Time to take $medicineName',
      'Don\'t forget your dose!',
      _tzDateTimeFrom(time),
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notifChannelMedicine,
          'Medicine Reminders',
          importance: Importance.high,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  dynamic _tzDateTimeFrom(DateTime dt) {
    // In real impl: use timezone package: tz.TZDateTime.from(dt, tz.local)
    return dt;
  }

  Future<void> cancelNotification(int id) => _local.cancel(id);
  Future<void> cancelAllNotifications() => _local.cancelAll();
}
