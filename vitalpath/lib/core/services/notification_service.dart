import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';
import 'haptic_service.dart';

part 'notification_service.g.dart';

/// Notification channel IDs for Android
abstract final class NotificationChannels {
  static const String medicine = 'vitalpath_medicine';
  static const String meal = 'vitalpath_meal';
  static const String steps = 'vitalpath_steps';
  static const String refill = 'vitalpath_refill';
  static const String doctor = 'vitalpath_doctor';
  static const String sync = 'vitalpath_sync';
  static const String critical = 'vitalpath_critical';
}

/// Notification IDs — ranges to avoid collisions
abstract final class NotificationIds {
  static const int medicineBase = 1000;
  static const int mealBase = 2000;
  static const int stepsBase = 3000;
  static const int refillBase = 4000;
  static const int doctorBase = 5000;
  static const int dailyOutlook = 9000;
}

/// VitalPath's notification engine.
///
/// Implements:
/// - Medicine dose reminders with distinct haptic patterns (SRS §7)
/// - Pre-meal reminders 15 minutes before window (SRS §4.2)
/// - Duplicate log overdose warnings (SRS §5.2)
/// - Refill reminders at inventory threshold (SRS §4.1)
/// - Notification fatigue detection (SRS §5.2)
/// - Daily Outlook notification (SRS §3.1)
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final HapticService _haptics;

  NotificationService({
    required FlutterLocalNotificationsPlugin plugin,
    required HapticService haptics,
  })  : _plugin = plugin,
        _haptics = haptics;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final currentTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimezone));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    await _createChannels();
  }

  Future<void> _createChannels() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Medicine — HIGH importance, distinct vibration pattern (SRS §7)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.medicine,
        'Medications',
        description: 'Reminders to take your medications',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('medicine_alert'),
        vibrationPattern: Int64List.fromList([0, 100, 50, 100]), // Short, sharp (SRS §7)
        enableVibration: true,
        playSound: true,
      ),
    );

    // Meal — MEDIUM importance
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.meal,
        'Meal Reminders',
        description: 'Pre-meal preparation reminders',
        importance: Importance.defaultImportance,
        enableVibration: true,
      ),
    );

    // Steps — LOW importance
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.steps,
        'Step Goals',
        description: 'Step goal milestone notifications',
        importance: Importance.low,
        vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 400]), // Long, celebratory (SRS §7)
      ),
    );

    // Refill — HIGH importance
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.refill,
        'Refill Reminders',
        description: 'Medication refill alerts',
        importance: Importance.high,
      ),
    );

    // Doctor — HIGH importance
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.doctor,
        'Doctor Updates',
        description: 'Messages and updates from your doctor',
        importance: Importance.high,
      ),
    );

    // Critical — MAX importance (overdose warnings, timezone leap)
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        NotificationChannels.critical,
        'Critical Alerts',
        description: 'Critical health alerts requiring immediate attention',
        importance: Importance.max,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 0, 0),
      ),
    );
  }

  // ── Daily Outlook (SRS §3.1) ──────────────────────────────────

  Future<void> scheduleDailyOutlook({required int hourOfDay}) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hourOfDay,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      NotificationIds.dailyOutlook,
      'Good morning! Your daily health outlook is ready.',
      'Tap to review your medications, meals, and step goal for today.',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.medicine,
          'Daily Outlook',
          channelDescription: 'Your morning health summary',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: const BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Medicine Reminders (SRS §4.1) ────────────────────────────

  Future<void> scheduleMedicineReminder({
    required int notificationId,
    required String medicineName,
    required String medicineId,
    required double dosage,
    required String unit,
    required tz.TZDateTime scheduledTime,
  }) async {
    await _plugin.zonedSchedule(
      NotificationIds.medicineBase + notificationId,
      'Time for your $medicineName',
      '${dosage.toStringAsFixed(dosage.truncateToDouble() == dosage ? 0 : 1)} $unit — Tap to log',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.medicine,
          'Medications',
          channelDescription: 'Medication reminders',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          actions: [
            const AndroidNotificationAction(
              'action_log_taken',
              'Taken',
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'action_snooze_30',
              'Snooze 30m',
              showsUserInterface: false,
            ),
            const AndroidNotificationAction(
              'action_skip',
              'Skip',
              showsUserInterface: false,
            ),
          ],
          additionalFlags: Int32List.fromList([4]), // FLAG_NO_CLEAR
          tag: 'medicine_$medicineId',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'medicine|$medicineId',
    );
  }

  Future<void> cancelMedicineReminder(int notificationId) {
    return _plugin.cancel(NotificationIds.medicineBase + notificationId);
  }

  // ── Pre-Meal Reminder (SRS §4.2 — 15 min before) ─────────────

  Future<void> scheduleMealReminder({
    required int notificationId,
    required String mealName,
    required String mealRoutineId,
    required tz.TZDateTime preMealTime,
  }) async {
    await _plugin.zonedSchedule(
      NotificationIds.mealBase + notificationId,
      'Prepare for $mealName in 15 minutes',
      'Your meal window opens soon — time to get ready.',
      preMealTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.meal,
          'Meal Reminders',
          channelDescription: 'Pre-meal reminders',
          importance: Importance.defaultImportance,
          actions: [
            const AndroidNotificationAction('action_log_meal', 'Log Now'),
            const AndroidNotificationAction('action_snooze_meal', 'Snooze'),
          ],
          tag: 'meal_$mealRoutineId',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'meal|$mealRoutineId',
    );
  }

  // ── Refill Reminder (SRS §4.1) ───────────────────────────────

  Future<void> showRefillReminder({
    required String medicineName,
    required String medicineId,
    required int remainingCount,
  }) async {
    await _haptics.medicineImpact();
    await _plugin.show(
      NotificationIds.refillBase + medicineName.hashCode.abs() % 1000,
      'Refill needed: $medicineName',
      'Only $remainingCount ${remainingCount == 1 ? 'dose' : 'doses'} remaining. Time to refill!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.refill,
          'Refill Reminders',
          channelDescription: 'Medication refill alerts',
          importance: Importance.high,
          color: const Color.fromARGB(255, 247, 164, 64),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ),
      payload: 'refill|$medicineId',
    );
  }

  // ── Overdose Warning (SRS §5.2 — Duplicate Log) ──────────────

  Future<void> showDuplicateLogWarning({
    required String medicineName,
    required DateTime lastLoggedAt,
  }) async {
    await _haptics.warningImpact();
    final timeStr =
        '${lastLoggedAt.hour.toString().padLeft(2, '0')}:${lastLoggedAt.minute.toString().padLeft(2, '0')}';

    await _plugin.show(
      99001,
      'WARNING: Possible Duplicate Dose',
      '$medicineName was already logged at $timeStr. Taking another may result in an overdose.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.critical,
          'Critical Alerts',
          channelDescription: 'Critical health alerts',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          color: const Color.fromARGB(255, 239, 68, 68),
        ),
      ),
    );
  }

  // ── Step Goal Reached ─────────────────────────────────────────

  Future<void> showStepGoalReached(int steps) async {
    await _haptics.stepGoalImpact();
    await _plugin.show(
      NotificationIds.stepsBase,
      'Step Goal Reached!',
      'Amazing! You\'ve completed $steps steps today. Keep it up!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.steps,
          'Step Goals',
          channelDescription: 'Step goal achievements',
          importance: Importance.low,
          vibrationPattern:
              Int64List.fromList([0, 200, 100, 200, 100, 400]), // Celebratory (SRS §7)
        ),
      ),
    );
  }

  // ── Notification Fatigue (SRS §5.2) ──────────────────────────

  Future<void> suggestCriticalAlerts() async {
    await _plugin.show(
      99002,
      'Are you missing your reminders?',
      'We noticed you\'ve missed several alerts. Enable Critical Alerts to ensure you never miss a dose.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.medicine,
          'Medications',
          channelDescription: 'Notification settings suggestion',
          importance: Importance.defaultImportance,
          actions: [
            const AndroidNotificationAction(
              'action_enable_critical',
              'Enable Critical Alerts',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'action_dismiss_fatigue',
              'Dismiss',
            ),
          ],
        ),
      ),
    );
  }

  // ── Doctor Updates (SRS §4.4) ─────────────────────────────────

  Future<void> showDoctorUpdate({
    required String doctorName,
    required String message,
  }) async {
    await _plugin.show(
      NotificationIds.doctorBase,
      'Update from Dr. $doctorName',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationChannels.doctor,
          'Doctor Updates',
          channelDescription: 'Doctor messages',
          importance: Importance.high,
        ),
      ),
      payload: 'doctor|update',
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload}');
    // Navigation is handled by the app's router after parsing the payload
    // The router listens for notification payload via a stream
  }

  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Background tap: ${response.payload}');
  }
}

@riverpod
NotificationService notificationService(Ref ref) {
  return NotificationService(
    plugin: FlutterLocalNotificationsPlugin(),
    haptics: ref.watch(hapticServiceProvider),
  );
}
