import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants/app_constants.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezones
    tz.initializeTimeZones();

    // Request FCM permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // FCM background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Local notifications setup
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create Android notification channels
    await _createChannel(AppConstants.notifChannelMedicine, 'Medicine Reminders', 'Reminders to take your medicine');
    await _createChannel(AppConstants.notifChannelAppointment, 'Appointment Reminders', 'Appointment updates and reminders');
    await _createChannel(AppConstants.notifChannelGeneral, 'General', 'General app notifications');

    // Listen to foreground FCM messages
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
    final channel = AndroidNotificationChannel(
      id, name,
      description: desc,
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<String?> getToken() => _fcm.getToken();

  // ── Immediate notification ────────────────────────────────────────────────

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
        android: AndroidNotificationDetails(
          channel, channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Daily repeating reminder (medicine) ───────────────────────────────────

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String channel = AppConstants.notifChannelMedicine,
  }) async {
    await _local.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel, channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── One-time reminder (meal) ──────────────────────────────────────────────

  Future<void> scheduleOnceReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String channel = AppConstants.notifChannelGeneral,
  }) async {
    await _local.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel, channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Cancel helpers ────────────────────────────────────────────────────────

  Future<void> cancelMedicineReminders(String medicineId) async {
    for (int i = 0; i < 3; i++) {
      await cancelNotification(medicineNotifId(medicineId, i));
    }
  }

  Future<void> cancelNotification(int id) => _local.cancel(id);
  Future<void> cancelAllNotifications() => _local.cancelAll();

  // ── Stable ID helpers (deterministic, survives restarts) ─────────────────

  static int medicineNotifId(String medicineId, int timeIndex) =>
      (medicineId.hashCode.abs() % 1000000) * 10 + timeIndex;

  static int mealNotifId(String mealId) =>
      900000000 + (mealId.hashCode.abs() % 100000000);

  // ── Internal ──────────────────────────────────────────────────────────────

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
