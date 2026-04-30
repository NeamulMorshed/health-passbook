import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../models/meal.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/patient.dart';
import '../models/activity_log.dart';
import '../models/app_notification.dart';
import '../models/family_member.dart';
import '../core/constants/app_constants.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

const _uuid = Uuid();

// ─── Patient Profile ──────────────────────────────────────────────────────────
final patientProfileProvider = FutureProvider.family<PatientProfile?, String>((ref, uid) async {
  return ref.watch(firestoreServiceProvider).getPatient(uid);
});

// ─── Medicines Stream ─────────────────────────────────────────────────────────
final medicinesProvider = StreamProvider.family<List<Medicine>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchMedicines(patientId);
});

// ─── Today's Meals Stream ─────────────────────────────────────────────────────
final todayMealsProvider = StreamProvider.family<List<MealLog>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchTodayMeals(patientId);
});

// ─── Activity Logs Stream ─────────────────────────────────────────────────────
final activityLogsProvider = StreamProvider.family<List<ActivityLog>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchRecentActivity(patientId);
});

// ─── Patient Appointments Stream (paginated) ─────────────────────────────────
// Use a record key so the limit is part of the cache key — incrementing the
// limit in the UI transparently re-subscribes with a larger Firestore query.
typedef ApptsKey = ({String patientId, int limit});

final patientAppointmentsProvider = StreamProvider.family<List<Appointment>, ApptsKey>((ref, key) {
  return ref.watch(firestoreServiceProvider).watchPatientAppointments(key.patientId, limit: key.limit);
});

// ─── Patient Prescriptions Stream ────────────────────────────────────────────
final patientPrescriptionsProvider = StreamProvider.family<List<Prescription>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchPatientPrescriptions(patientId);
});

// ─── Notifications Stream ─────────────────────────────────────────────────────
final notificationsProvider = StreamProvider.family<List<AppNotification>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchNotifications(patientId);
});

// ─── Family Members ───────────────────────────────────────────────────────────
final familyMembersProvider =
    StreamProvider.family<List<FamilyMember>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchFamilyMembers(uid);
});

typedef FamilyMedKey = ({String uid, String memberId});

final familyMemberMedicinesProvider =
    StreamProvider.family<List<Medicine>, FamilyMedKey>((ref, key) {
  return ref
      .watch(firestoreServiceProvider)
      .watchFamilyMemberMedicines(key.uid, key.memberId);
});

class FamilyMemberNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  FamilyMemberNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> add(String uid, {
    required String name,
    required String relationship,
    int? age,
    String? photoUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final member = FamilyMember(
        id: _uuid.v4(),
        name: name,
        relationship: relationship,
        age: age,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
      );
      await _db.addFamilyMember(uid, member);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> update(String uid, FamilyMember member) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateFamilyMember(uid, member);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> delete(String uid, String memberId) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteFamilyMember(uid, memberId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final familyMemberNotifierProvider =
    StateNotifierProvider<FamilyMemberNotifier, AsyncValue<void>>((ref) {
  return FamilyMemberNotifier(ref.watch(firestoreServiceProvider));
});

class FamilyMedicinePatch {
  final FirestoreService _db;
  FamilyMedicinePatch(this._db);

  Future<void> add(String uid, String memberId, {
    required String name,
    required String dosage,
    required String frequency,
    String? notes,
    String? scannedPhotoUrl,
    List<String> reminderTimes = const [],
    String reminderRepeat = 'daily',
  }) async {
    final med = Medicine(
      id: _uuid.v4(),
      patientId: memberId,
      name: name,
      dosage: dosage,
      frequency: frequency,
      notes: notes,
      startDate: DateTime.now(),
      scannedPhotoUrl: scannedPhotoUrl,
      reminderTimes: reminderTimes,
      reminderRepeat: reminderRepeat,
    );
    await _db.addFamilyMemberMedicine(uid, memberId, med);
  }

  Future<void> logDose(String uid, String memberId, String medicineId) =>
      _db.logFamilyMemberDose(uid, memberId, medicineId);

  Future<void> delete(String uid, String memberId, String medicineId) =>
      _db.deleteFamilyMemberMedicine(uid, memberId, medicineId);

  Future<void> update(String uid, String memberId, String medicineId,
      Map<String, dynamic> data) =>
      _db.updateFamilyMemberMedicine(uid, memberId, medicineId, data);
}

final familyMedicinePatchProvider = Provider<FamilyMedicinePatch>((ref) {
  return FamilyMedicinePatch(ref.watch(firestoreServiceProvider));
});

// ─── Medicine Notifier ────────────────────────────────────────────────────────
class MedicineNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  final NotificationService _notif;
  MedicineNotifier(this._db, this._notif) : super(const AsyncValue.data(null));

  Future<void> add(String patientId, {
    required String name,
    required String dosage,
    required String frequency,
    String? notes,
    List<String> reminderTimes = const [],
    String reminderRepeat = 'daily',
    String? scannedPhotoUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      final medId = _uuid.v4();
      final med = Medicine(
        id: medId,
        patientId: patientId,
        name: name,
        dosage: dosage,
        frequency: frequency,
        notes: notes,
        startDate: DateTime.now(),
        reminderTimes: reminderTimes,
        reminderRepeat: reminderRepeat,
        scannedPhotoUrl: scannedPhotoUrl,
      );
      await _db.addMedicine(patientId, med);
      await _scheduleAndSaveMedicineReminders(patientId, medId, name, dosage, reminderTimes, reminderRepeat);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> update(String patientId, String medicineId, {
    required String name,
    required String dosage,
    required String frequency,
    String? notes,
    List<String> reminderTimes = const [],
    String reminderRepeat = 'daily',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _notif.cancelMedicineReminders(medicineId);
      await _db.updateMedicine(patientId, medicineId, {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'notes': notes,
        'reminderTimes': reminderTimes,
        'reminderRepeat': reminderRepeat,
      });
      await _scheduleAndSaveMedicineReminders(patientId, medicineId, name, dosage, reminderTimes, reminderRepeat);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> _scheduleAndSaveMedicineReminders(
    String patientId, String medId, String name, String dosage,
    List<String> reminderTimes, String repeat,
  ) async {
    for (int i = 0; i < reminderTimes.length; i++) {
      final parts = reminderTimes[i].split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      await _notif.scheduleReminder(
        id: NotificationService.medicineNotifId(medId, i),
        title: 'Time to take $name',
        body: 'Your $dosage dose is due now.',
        hour: hour,
        minute: minute,
        repeat: repeat,
      );
      final repeatLabel = repeat == 'weekly' ? 'Weekly' : 'Daily';
      await _db.addNotification(patientId, AppNotification(
        id: _uuid.v4(),
        title: 'Medicine reminder set',
        body: '$name — $dosage at ${reminderTimes[i]} ($repeatLabel)',
        type: NotificationType.medicineReminder,
        createdAt: DateTime.now(),
        scheduledFor: _todayAt(hour, minute),
      ));
    }
  }

  Future<void> logDose(String patientId, String medicineId) async {
    await _db.logDose(patientId, medicineId);
  }

  Future<void> delete(String patientId, String medicineId) async {
    await _notif.cancelMedicineReminders(medicineId);
    await _db.deleteMedicine(patientId, medicineId);
  }
}

final medicineNotifierProvider = StateNotifierProvider<MedicineNotifier, AsyncValue<void>>((ref) {
  return MedicineNotifier(ref.watch(firestoreServiceProvider), ref.watch(notificationServiceProvider));
});

// ─── Meal Notifier ────────────────────────────────────────────────────────────
class MealNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  final NotificationService _notif;
  MealNotifier(this._db, this._notif) : super(const AsyncValue.data(null));

  Future<void> add(String patientId, {
    required String mealType,
    required String description,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? reminderTime,
    String reminderRepeat = 'once',
  }) async {
    state = const AsyncValue.loading();
    try {
      final mealId = _uuid.v4();
      final meal = MealLog(
        id: mealId,
        patientId: patientId,
        mealType: mealType,
        description: description,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        loggedAt: DateTime.now(),
        reminderTime: reminderTime,
        reminderRepeat: reminderRepeat,
      );
      await _db.addMeal(patientId, meal);
      if (reminderTime != null) {
        await _scheduleAndSaveMealReminder(patientId, mealId, mealType, reminderTime, reminderRepeat);
      }
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> update(String patientId, String mealId, {
    required String mealType,
    required String description,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? reminderTime,
    String reminderRepeat = 'once',
  }) async {
    state = const AsyncValue.loading();
    try {
      await _notif.cancelNotification(NotificationService.mealNotifId(mealId));
      await _db.updateMeal(patientId, mealId, {
        'mealType': mealType,
        'description': description,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'reminderTime': reminderTime,
        'reminderRepeat': reminderRepeat,
      });
      if (reminderTime != null) {
        await _scheduleAndSaveMealReminder(patientId, mealId, mealType, reminderTime, reminderRepeat);
      }
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> _scheduleAndSaveMealReminder(
    String patientId, String mealId, String mealType, String reminderTime, String repeat,
  ) async {
    final parts = reminderTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = int.tryParse(parts[1]) ?? 0;
    await _notif.scheduleReminder(
      id: NotificationService.mealNotifId(mealId),
      title: 'Time for $mealType!',
      body: 'Reminder to have your $mealType.',
      hour: hour,
      minute: minute,
      repeat: repeat,
      channel: AppConstants.notifChannelGeneral,
    );
    final repeatLabel = repeat == 'daily' ? 'Daily' : 'Once';
    await _db.addNotification(patientId, AppNotification(
      id: _uuid.v4(),
      title: 'Meal reminder set',
      body: '$mealType at $reminderTime ($repeatLabel)',
      type: NotificationType.mealReminder,
      createdAt: DateTime.now(),
      scheduledFor: _todayAt(hour, minute),
    ));
  }

  Future<void> delete(String patientId, String mealId) async {
    await _notif.cancelNotification(NotificationService.mealNotifId(mealId));
    await _db.deleteMeal(patientId, mealId);
  }
}

final mealNotifierProvider = StateNotifierProvider<MealNotifier, AsyncValue<void>>((ref) {
  return MealNotifier(ref.watch(firestoreServiceProvider), ref.watch(notificationServiceProvider));
});

// ─── Notification Notifier ────────────────────────────────────────────────────
class NotificationNotifier extends StateNotifier<void> {
  final FirestoreService _db;
  NotificationNotifier(this._db) : super(null);

  Future<void> markRead(String patientId, String notifId) =>
      _db.markNotificationRead(patientId, notifId);

  Future<void> markAllRead(String patientId) =>
      _db.markAllNotificationsRead(patientId);
}

final notificationNotifierProvider = StateNotifierProvider<NotificationNotifier, void>((ref) {
  return NotificationNotifier(ref.watch(firestoreServiceProvider));
});

// ─── Appointment Notifier ─────────────────────────────────────────────────────
class AppointmentNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  AppointmentNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> book({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    String? doctorSpecialty,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final appt = Appointment(
        id: _uuid.v4(),
        patientId: patientId,
        patientName: patientName,
        doctorId: doctorId,
        doctorName: doctorName,
        doctorSpecialty: doctorSpecialty,
        status: AppointmentStatus.pending,
        patientNote: note,
        createdAt: DateTime.now(),
      );
      await _db.bookAppointment(appt);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> cancel(
    String apptId, {
    required String patientId,
    required String doctorId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateAppointmentStatus(
        apptId,
        AppointmentStatus.cancelled,
        patientId: patientId,
        doctorId: doctorId,
      );
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final appointmentNotifierProvider = StateNotifierProvider<AppointmentNotifier, AsyncValue<void>>((ref) {
  return AppointmentNotifier(ref.watch(firestoreServiceProvider));
});

// ─── Activity Notifier ────────────────────────────────────────────────────────
class ActivityNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  ActivityNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> save(String patientId, {
    required String type,
    required int durationSeconds,
    double? distanceKm,
    int? steps,
    int? caloriesBurned,
  }) async {
    final log = ActivityLog(
      id: _uuid.v4(),
      patientId: patientId,
      type: type,
      durationSeconds: durationSeconds,
      distanceKm: distanceKm,
      steps: steps,
      caloriesBurned: caloriesBurned,
      loggedAt: DateTime.now(),
    );
    await _db.saveActivity(patientId, log);
  }
}

final activityNotifierProvider = StateNotifierProvider<ActivityNotifier, AsyncValue<void>>((ref) {
  return ActivityNotifier(ref.watch(firestoreServiceProvider));
});

// ─── Helper ───────────────────────────────────────────────────────────────────
DateTime _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour, minute);
}
