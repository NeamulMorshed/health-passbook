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
    tz.initializeTimeZones();

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _createChannel(AppConstants.notifChannelMedicine, 'Medicine Reminders', 'Reminders to take your medicine');
    await _createChannel(AppConstants.notifChannelAppointment, 'Appointment Reminders', 'Appointment updates and reminders');
    await _createChannel(AppConstants.notifChannelGeneral, 'General', 'General app notifications');

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
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<String?> getToken() => _fcm.getToken();

  // Returns true when the user has granted notification permission on this device.
  Future<bool> isPermissionGranted() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // ── Immediate notification ────────────────────────────────────────────────

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String channel = AppConstants.notifChannelGeneral,
  }) async {
    await _local.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(channel, channel, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Medicine reminder helper ──────────────────────────────────────────────
  // Builds a medicine notification title, optionally prefixed with the
  // family member's name: "[Name]'s medicine: [MedicineName]"

  static String medicineReminderTitle(String medicineName, {String? familyMemberName}) {
    if (familyMemberName != null && familyMemberName.isNotEmpty) {
      return "$familyMemberName's medicine: $medicineName";
    }
    return 'Time to take $medicineName';
  }

  // ── Unified scheduled reminder ────────────────────────────────────────────
  // repeat: 'daily' | 'weekly' | 'once'

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String repeat,
    String channel = AppConstants.notifChannelMedicine,
    String? familyMemberName,
  }) async {
    final effectiveTitle = familyMemberName != null
        ? medicineReminderTitle(title, familyMemberName: familyMemberName)
        : title;
    final DateTimeComponents? components = switch (repeat) {
      'daily'  => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      _        => null, // 'once'
    };
    await _local.zonedSchedule(
      id, effectiveTitle, body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(channel, channel, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: components,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Legacy wrappers kept for any callers that haven't migrated
  Future<void> scheduleDailyReminder({required int id, required String title, required String body, required int hour, required int minute, String channel = AppConstants.notifChannelMedicine}) =>
      scheduleReminder(id: id, title: title, body: body, hour: hour, minute: minute, repeat: 'daily', channel: channel);

  Future<void> scheduleOnceReminder({required int id, required String title, required String body, required int hour, required int minute, String channel = AppConstants.notifChannelGeneral}) =>
      scheduleReminder(id: id, title: title, body: body, hour: hour, minute: minute, repeat: 'once', channel: channel);

  // ── Cancel helpers ────────────────────────────────────────────────────────

  Future<void> cancelMedicineReminders(String medicineId) async {
    for (int i = 0; i < 3; i++) {
      await cancelNotification(medicineNotifId(medicineId, i));
    }
  }

  Future<void> cancelNotification(int id) => _local.cancel(id);
  Future<void> cancelAllNotifications() => _local.cancelAll();

  // ── Stable ID helpers ─────────────────────────────────────────────────────

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
