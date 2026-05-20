import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../app/navigation_key.dart';
import '../core/constants/app_constants.dart';
import '../models/medicine.dart';
import 'firestore_service.dart';

// ── Background handler (top-level, required by firebase_messaging) ────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically shows a heads-up notification for notification messages
  // when the app is in the background. Nothing extra needed here.
}

// ── SharedPreferences keys ────────────────────────────────────────────────────
// Maps each notification channel to the toggle key used in NotificationSettings.
const _channelPrefKeys = {
  AppConstants.notifChannelMedicine:    'notif_medicines',
  AppConstants.notifChannelAppointment: 'notif_appointments',
  AppConstants.notifChannelGeneral:     'notif_doctors',
};

// Prefix for the per-channel set of scheduled notification IDs.
// Stored as a JSON-encoded List<int> in SharedPreferences.
const _channelIdsPrefix = 'notif_ids_';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz));

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // ── Local notifications ───────────────────────────────────────────────
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      // Bug 4 fix: handle taps on local (medicine/meal) notifications.
      onDidReceiveNotificationResponse: (response) {
        final route = _routeForChannel(response.payload);
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) ctx.go(route);
      },
    );

    await _createChannel(AppConstants.notifChannelMedicine,    'Medicine Reminders',    'Reminders to take your medicine');
    await _createChannel(AppConstants.notifChannelAppointment, 'Appointment Reminders', 'Appointment updates and reminders');
    await _createChannel(AppConstants.notifChannelGeneral,     'General',               'General app notifications');

    // ── Foreground FCM messages ───────────────────────────────────────────
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          id: message.hashCode,
          title: notification.title ?? 'Omra',
          body: notification.body ?? '',
          channel: message.data['channel'] ?? AppConstants.notifChannelGeneral,
        );
      }
    });

    // Bug 4 fix: navigate when user taps an FCM notification while app is in background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigateForFcmMessage(message);
    });
  }

  // Bug 4 fix: call after runApp() to handle the notification that cold-started the app.
  Future<void> handleInitialMessage() async {
    final message = await _fcm.getInitialMessage();
    if (message == null) return;
    // Small delay lets the widget tree settle before navigating.
    await Future.delayed(const Duration(milliseconds: 600));
    _navigateForFcmMessage(message);
  }

  // Bug 2 fix: save the device FCM token to Firestore whenever the user logs in
  // or the token rotates.  Call once per session from fcmTokenSyncProvider.
  Future<void> syncTokenForUser(String uid, FirestoreService db) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await db.saveFcmToken(uid, token);

      _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await db.saveFcmToken(uid, newToken);
        } catch (_) {}
      });
    } catch (_) {}
  }

  // ── Permission check ──────────────────────────────────────────────────────

  Future<bool> isPermissionGranted() async {
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() => _fcm.getToken();

  // ── Immediate local notification ──────────────────────────────────────────

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String channel = AppConstants.notifChannelGeneral,
  }) async {
    await _local.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel, channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: channel,
    );
  }

  // ── Scheduled reminder ────────────────────────────────────────────────────
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
    // Bug 5 fix: respect the per-category toggle in Notification Settings.
    if (!await _isChannelEnabled(channel)) return;

    final effectiveTitle = familyMemberName != null
        ? medicineReminderTitle(title, familyMemberName: familyMemberName)
        : title;

    final DateTimeComponents? components = switch (repeat) {
      'daily'  => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      _        => null,
    };

    await _local.zonedSchedule(
      id, effectiveTitle, body,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel, channel,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: components,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: channel,
    );

    // Track this ID so cancelAllForChannel can cancel it later.
    await _trackId(id, channel);
  }

  // Bug 5 fix: cancel every scheduled notification belonging to a channel.
  Future<void> cancelAllForChannel(String channel) async {
    final ids = await _loadIds(channel);
    for (final id in ids) {
      await _local.cancel(id);
    }
    await _clearIds(channel);
  }

  // ── Medicine reminder helpers ─────────────────────────────────────────────

  static String medicineReminderTitle(String medicineName, {String? familyMemberName}) {
    if (familyMemberName != null && familyMemberName.isNotEmpty) {
      return "$familyMemberName's medicine: $medicineName";
    }
    return 'Time to take $medicineName';
  }

  Future<void> scheduleMedicineReminders(String uid, Medicine medicine) async {
    for (int i = 0; i < medicine.reminderTimes.length; i++) {
      final parts = medicine.reminderTimes[i].split(':');
      if (parts.length != 2) continue;
      final hour   = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      await scheduleReminder(
        id:     medicineNotifId(medicine.id, i),
        title:  'Time to take ${medicine.name}',
        body:   '${medicine.dosage} dose is due now.',
        hour:   hour,
        minute: minute,
        repeat: medicine.reminderRepeat,
      );
    }
  }

  // Legacy wrappers kept for existing callers
  Future<void> scheduleDailyReminder({
    required int id, required String title, required String body,
    required int hour, required int minute,
    String channel = AppConstants.notifChannelMedicine,
  }) => scheduleReminder(id: id, title: title, body: body, hour: hour, minute: minute, repeat: 'daily', channel: channel);

  Future<void> scheduleOnceReminder({
    required int id, required String title, required String body,
    required int hour, required int minute,
    String channel = AppConstants.notifChannelGeneral,
  }) => scheduleReminder(id: id, title: title, body: body, hour: hour, minute: minute, repeat: 'once', channel: channel);

  // ── Cancel helpers ────────────────────────────────────────────────────────

  // Cancel up to 8 reminder slots per medicine.
  Future<void> cancelMedicineReminders(String medicineId) async {
    for (int i = 0; i < 8; i++) {
      await cancelNotification(medicineNotifId(medicineId, i));
    }
  }

  Future<void> cancelNotification(int id) => _local.cancel(id);
  Future<void> cancelAllNotifications() => _local.cancelAll();

  // ── Startup reschedule ────────────────────────────────────────────────────
  // After a reinstall the OS clears all scheduled alarms. This runs once per
  // install (per uid) to restore them.  Called from the home screen.

  Future<void> rescheduleAllRemindersIfNeeded(String uid, List<Medicine> medicines) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = 'reminders_scheduled_$uid';
    if (prefs.getBool(flagKey) ?? false) return;

    for (final medicine in medicines) {
      if (medicine.isActive && medicine.reminderTimes.isNotEmpty) {
        await scheduleMedicineReminders(uid, medicine);
      }
    }
    await prefs.setBool(flagKey, true);
  }

  // ── Stable ID helpers ─────────────────────────────────────────────────────

  static int medicineNotifId(String medicineId, int timeIndex) =>
      (medicineId.hashCode.abs() % 1000000) * 10 + timeIndex;

  static int mealNotifId(String mealId) =>
      900000000 + (mealId.hashCode.abs() % 100000000);

  // ── Internal helpers ──────────────────────────────────────────────────────

  Future<void> _createChannel(String id, String name, String desc) async {
    final channel = AndroidNotificationChannel(
      id, name, description: desc, importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Returns false when the user has turned off the toggle for this channel.
  Future<bool> _isChannelEnabled(String channel) async {
    final key = _channelPrefKeys[channel];
    if (key == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  // Persist a notification ID under its channel so it can be cancelled later.
  Future<void> _trackId(int id, String channel) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_channelIdsPrefix$channel';
    final existing = _decodeIds(prefs.getString(key));
    existing.add(id);
    await prefs.setString(key, jsonEncode(existing.toList()));
  }

  Future<Set<int>> _loadIds(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeIds(prefs.getString('$_channelIdsPrefix$channel'));
  }

  Future<void> _clearIds(String channel) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_channelIdsPrefix$channel');
  }

  Set<int> _decodeIds(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Maps a notification channel (or FCM data key) to the in-app route to open.
  static String _routeForChannel(String? channel) {
    return switch (channel) {
      AppConstants.notifChannelMedicine    => '/medicines',
      AppConstants.notifChannelAppointment => '/appointments',
      _                                    => '/notifications',
    };
  }

  void _navigateForFcmMessage(RemoteMessage message) {
    final channel = message.data['channel'] as String?;
    final route = _routeForChannel(channel);
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) ctx.go(route);
  }
}
