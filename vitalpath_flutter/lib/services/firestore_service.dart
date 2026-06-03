import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../models/meal.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/activity_log.dart';
import '../models/app_notification.dart';
import '../models/family_member.dart';
import '../models/consultation_note.dart';
import '../models/vital_reading.dart';
import '../core/constants/app_constants.dart';

const _uuid = Uuid();

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // F9: Constant for consultationNotes collection to avoid hardcoded strings.
  static const _colConsultationNotes = 'consultationNotes';

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Patient ──────────────────────────────────────────────────────────────

  Future<PatientProfile?> getPatient(String uid) async {
    final doc = await _db.collection(AppConstants.colPatients).doc(uid).get();
    if (!doc.exists) return null;
    return PatientProfile.fromMap(doc.data()!, uid);
  }

  Future<void> updatePatientProfile(
      String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colPatients).doc(uid).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ─── Doctor ───────────────────────────────────────────────────────────────

  Future<DoctorProfile?> getDoctor(String uid) async {
    final doc = await _db.collection(AppConstants.colDoctors).doc(uid).get();
    if (!doc.exists) return null;
    return DoctorProfile.fromMap(doc.data()!, uid);
  }

  Future<void> updateDoctorProfile(
      String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colDoctors).doc(uid).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  // ── Private batch-fetch helpers ────────────────────────────────────────────
  // Firestore whereIn supports max 30 items; chunking handles any list size.

  Future<List<DoctorProfile>> _fetchDoctorsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <DoctorProfile>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snap = await _db
          .collection(AppConstants.colDoctors)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results
          .addAll(snap.docs.map((d) => DoctorProfile.fromMap(d.data(), d.id)));
    }
    return results;
  }

  Future<List<PatientProfile>> _fetchPatientsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final results = <PatientProfile>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      final snap = await _db
          .collection(AppConstants.colPatients)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results
          .addAll(snap.docs.map((d) => PatientProfile.fromMap(d.data(), d.id)));
    }
    return results;
  }

  // ── Connections (patient ↔ doctor many-to-many) ────────────────────────────
  // Fan-out write on both sides so neither the patient doc nor the doctor doc
  // acts as a write hotspot.  Each connection is its own document → Firestore
  // can handle unlimited concurrent bookings without contention.

  Stream<List<DoctorProfile>> watchMyDoctors(String patientId) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colConnections)
        .snapshots()
        .asyncMap(
            (snap) => _fetchDoctorsByIds(snap.docs.map((d) => d.id).toList()));
  }

  Stream<List<PatientProfile>> watchDoctorPatients(String doctorId) {
    return _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .snapshots()
        .asyncMap(
            (snap) => _fetchPatientsByIds(snap.docs.map((d) => d.id).toList()));
  }

  Stream<int> watchDoctorPatientCount(String doctorId) {
    return _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<List<DoctorProfile>> searchDoctors(
      {String? specialty, String? nameQuery, String? city}) async {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colDoctors);
    if (specialty != null && specialty.isNotEmpty) {
      query = query.where('specialty', isEqualTo: specialty);
    }
    if (city != null && city.isNotEmpty) {
      query = query.where('city', isEqualTo: city);
    }
    final snap = await query.limit(50).get();
    var results =
        snap.docs.map((d) => DoctorProfile.fromMap(d.data(), d.id)).toList();
    if (nameQuery != null && nameQuery.isNotEmpty) {
      final lower = nameQuery.toLowerCase();
      results = results
          .where((d) =>
              d.name.toLowerCase().contains(lower) ||
              (d.specialty?.toLowerCase().contains(lower) ?? false) ||
              (d.hospital?.toLowerCase().contains(lower) ?? false))
          .toList();
    }
    return results;
  }

  Future<bool> isConnected(String doctorId, String patientId) async {
    final doc = await _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .doc(patientId)
        .get();
    return doc.exists;
  }

  Stream<bool> watchConnection(String doctorId, String patientId) {
    return _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .doc(patientId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> removeConnection(String patientId, String doctorId) async {
    final batch = _db.batch();
    batch.delete(_db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colConnections)
        .doc(doctorId));
    batch.delete(_db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .doc(patientId));
    await batch.commit();
  }

  // ─── Medicines ────────────────────────────────────────────────────────────

  Stream<List<Medicine>> watchMedicines(String patientId) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return Medicine.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<Medicine>()
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          return list;
        });
  }

  Future<void> addMedicine(String patientId, Medicine medicine) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicine.id)
        .set(medicine.toMap());
  }

  Future<void> logDose(String patientId, String medicineId,
      {DateTime? at}) async {
    final ts = at ?? DateTime.now();
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayUnion([Timestamp.fromDate(ts)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlogDose(
      String patientId, String medicineId, DateTime at) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayRemove([Timestamp.fromDate(at)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMedicine(
      String patientId, String medicineId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMedicine(String patientId, String medicineId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Family Members ───────────────────────────────────────────────────────

  Stream<List<FamilyMember>> watchFamilyMembers(String uid) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) {
              try {
                return FamilyMember.fromMap(d.data(), d.id);
              } catch (_) {
                return null;
              }
            })
            .whereType<FamilyMember>()
            .toList());
  }

  Future<void> addFamilyMember(String uid, FamilyMember member) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(member.id)
        .set(member.toMap());
  }

  Future<void> updateFamilyMember(String uid, FamilyMember member) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(member.id)
        .update({...member.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteFamilyMember(String uid, String memberId) async {
    // Delete member's medicines first, then the member document.
    // F3: Split into chunks of 499 to stay within Firestore's 500-op batch limit.
    final medSnap = await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .get();

    final medicineDocs = medSnap.docs;
    final memberRef = _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId);

    const chunkSize = 499;
    if (medicineDocs.isEmpty) {
      // No medicines — just delete the member document.
      await memberRef.delete();
      return;
    }

    for (var i = 0; i < medicineDocs.length; i += chunkSize) {
      final batch = _db.batch();
      final chunk =
          medicineDocs.sublist(i, min(i + chunkSize, medicineDocs.length));
      for (final doc in chunk) {
        batch.delete(doc.reference);
      }
      // Only delete the member document on the last chunk.
      if (i + chunkSize >= medicineDocs.length) {
        batch.delete(memberRef);
      }
      await batch.commit();
    }
  }

  // ── Family member medicines ────────────────────────────────────────────────

  Stream<List<Medicine>> watchFamilyMemberMedicines(
      String uid, String memberId) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return Medicine.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<Medicine>()
              .toList()
            ..sort((a, b) => b.startDate.compareTo(a.startDate));
          return list;
        });
  }

  Future<void> addFamilyMemberMedicine(
      String uid, String memberId, Medicine medicine) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicine.id)
        .set(medicine.toMap());
  }

  Future<void> updateFamilyMemberMedicine(String uid, String memberId,
      String medicineId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteFamilyMemberMedicine(
      String uid, String memberId, String medicineId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({'isActive': false, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> logFamilyMemberDose(
      String uid, String memberId, String medicineId,
      {DateTime? at}) async {
    final ts = at ?? DateTime.now();
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayUnion([Timestamp.fromDate(ts)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlogFamilyMemberDose(
      String uid, String memberId, String medicineId, DateTime at) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(uid)
        .collection(AppConstants.colFamilyMembers)
        .doc(memberId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayRemove([Timestamp.fromDate(at)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Meals ────────────────────────────────────────────────────────────────

  // FIXME: date range computed at subscription — rebuild at midnight.
  // The StreamProvider caller should call ref.invalidateSelf() on a midnight timer
  // to re-subscribe with a fresh date range when the day rolls over.
  Stream<List<MealLog>> watchTodayMeals(String patientId) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMeals)
        .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('loggedAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((s) {
      // Re-evaluate today's boundaries on each emission so stale data is filtered
      // when the stream runs past midnight without re-subscribing.
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      return s.docs
          .map((d) {
            try {
              return MealLog.fromMap(d.data(), d.id);
            } catch (_) {
              return null;
            }
          })
          .whereType<MealLog>()
          .where((m) =>
              !m.loggedAt.isBefore(todayStart) && m.loggedAt.isBefore(todayEnd))
          .toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    });
  }

  Future<void> addMeal(String patientId, MealLog meal) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMeals)
        .doc(meal.id)
        .set(meal.toMap());
  }

  Future<void> updateMeal(
      String patientId, String mealId, Map<String, dynamic> data) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMeals)
        .doc(mealId)
        .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteMeal(String patientId, String mealId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMeals)
        .doc(mealId)
        .delete();
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Stream<List<AppNotification>> watchNotifications(String patientId) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colNotifications)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) {
              try {
                return AppNotification.fromMap(d.data(), d.id);
              } catch (_) {
                return null;
              }
            })
            .whereType<AppNotification>()
            .toList());
  }

  Future<void> addNotification(String patientId, AppNotification notif) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colNotifications)
        .doc(notif.id)
        .set(notif.toMap());
  }

  Future<void> markNotificationRead(String patientId, String notifId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colNotifications)
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String patientId) async {
    // F10: Filter by createdAt <= now() so notifications that arrive between
    // the query and batch write are not incorrectly marked as read.
    // Requires composite index: notifications collection, isRead ASC + createdAt ASC.
    // If missing, this query throws failed-precondition and markAllRead silently fails.
    final snap = await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colNotifications)
        .where('isRead', isEqualTo: false)
        .where('createdAt', isLessThanOrEqualTo: Timestamp.now())
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── Activity Logs ────────────────────────────────────────────────────────

  Future<void> saveActivity(String patientId, ActivityLog log) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colActivityLogs)
        .doc(log.id)
        .set(log.toMap());
  }

  Stream<List<ActivityLog>> watchRecentActivity(String patientId) {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colActivityLogs)
        .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .limit(20)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return ActivityLog.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<ActivityLog>()
              .toList()
            ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
          return list;
        });
  }

  // ─── Appointments ─────────────────────────────────────────────────────────

  Stream<List<Appointment>> watchPatientAppointments(String patientId,
      {int limit = 20}) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
      final appts = s.docs
          .map((d) {
            try {
              return Appointment.fromMap(d.data(), d.id);
            } catch (_) {
              return null;
            }
          })
          .whereType<Appointment>()
          .toList();
      return appts;
    });
  }

  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) {
      final appts = s.docs
          .map((d) {
            try {
              return Appointment.fromMap(d.data(), d.id);
            } catch (_) {
              return null;
            }
          })
          .whereType<Appointment>()
          .toList();
      return appts;
    });
  }

  // Booking only creates the appointment — connection is established on confirmation.
  Future<void> bookAppointment(Appointment appt) async {
    await _db
        .collection(AppConstants.colAppointments)
        .doc(appt.id)
        .set(appt.toMap());
  }

  // Confirm appointment: update status, fan-out connection, notify patient.
  Future<void> confirmAppointment({
    required String apptId,
    required String patientId,
    required String doctorId,
    required String doctorName,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection(AppConstants.colAppointments).doc(apptId), {
      'status': AppointmentStatus.confirmed.value,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (notes != null) 'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Bidirectional connection — created only after doctor accepts.
    batch.set(
      _db
          .collection(AppConstants.colPatients)
          .doc(patientId)
          .collection(AppConstants.colConnections)
          .doc(doctorId),
      {'connectedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db
          .collection(AppConstants.colDoctors)
          .doc(doctorId)
          .collection(AppConstants.colConnections)
          .doc(patientId),
      {'connectedAt': FieldValue.serverTimestamp()},
    );

    // In-app notification for the patient.
    batch.set(
      _db
          .collection(AppConstants.colPatients)
          .doc(patientId)
          .collection(AppConstants.colNotifications)
          .doc(_uuid.v4()),
      {
        'title': 'Appointment Confirmed',
        'body':
            'Dr. $doctorName confirmed your appointment for ${_fmtDt(scheduledAt)}.',
        'type': NotificationType.appointment.value,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'scheduledFor': Timestamp.fromDate(scheduledAt),
      },
    );

    await batch.commit();
  }

  Future<void> updateAppointmentStatus(
    String apptId,
    AppointmentStatus status, {
    DateTime? scheduledAt,
    String? notes,
    String? patientId,
    String? doctorId,
    String? doctorName,
  }) async {
    final data = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (scheduledAt != null)
      data['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    if (notes != null) data['notes'] = notes;
    await _db.collection(AppConstants.colAppointments).doc(apptId).update(data);

    if (status == AppointmentStatus.cancelled && patientId != null) {
      // Write in-app notification to patient
      final cancelNotif = <String, dynamic>{
        'title': 'Appointment Cancelled',
        'body': doctorName != null
            ? 'Dr. $doctorName has cancelled your appointment.'
            : 'Your appointment has been cancelled.',
        'type': NotificationType.appointment.value,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      await _db
          .collection(AppConstants.colPatients)
          .doc(patientId)
          .collection(AppConstants.colNotifications)
          .doc(_uuid.v4())
          .set(cancelNotif);

      if (doctorId != null) {
        await _cleanupConnectionIfInactive(patientId, doctorId);
      }
    }

    if (status == AppointmentStatus.completed && patientId != null) {
      // Write in-app notification to patient
      final completedNotif = <String, dynamic>{
        'title': 'Appointment Completed',
        'body': doctorName != null
            ? 'Dr. $doctorName has completed your appointment.'
            : 'Your appointment has been completed.',
        'type': NotificationType.appointment.value,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      await _db
          .collection(AppConstants.colPatients)
          .doc(patientId)
          .collection(AppConstants.colNotifications)
          .doc(_uuid.v4())
          .set(completedNotif);
    }
  }

  Future<void> _cleanupConnectionIfInactive(
      String patientId, String doctorId) async {
    final remaining = await _db
        .collection(AppConstants.colAppointments)
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: ['pending', 'confirmed']).get();
    if (remaining.docs.isEmpty) {
      await removeConnection(patientId, doctorId);
    }
  }

  String _fmtDt(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $period';
  }

  // ─── Prescriptions ────────────────────────────────────────────────────────

  Stream<List<Prescription>> watchPatientPrescriptions(String patientId,
      {int limit = 20}) {
    return _db
        .collection(AppConstants.colPrescriptions)
        .where('patientId', isEqualTo: patientId)
        .limit(limit)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return Prescription.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<Prescription>()
              .toList()
            ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
          return list;
        });
  }

  /// Writes the prescription and all derived medicine entries in a single
  /// atomic batch so a partial failure can never leave data inconsistent.
  Future<void> addPrescription(Prescription rx) async {
    final batch = _db.batch();

    batch.set(
      _db.collection(AppConstants.colPrescriptions).doc(rx.id),
      rx.toMap(),
    );

    for (final med in rx.medicines) {
      final medRef = _db
          .collection(AppConstants.colPatients)
          .doc(rx.patientId)
          .collection(AppConstants.colMedicines)
          .doc();
      batch.set(
        medRef,
        Medicine(
          id: medRef.id,
          patientId: rx.patientId,
          name: med.name,
          dosage: med.dosage,
          frequency: med.frequency,
          prescribedBy: rx.doctorName,
          doctorId: rx.doctorId,
          notes: med.instructions,
          startDate: rx.issuedAt,
        ).toMap(),
      );
    }

    // In-app notification for the patient
    final medCount = rx.medicines.length;
    batch.set(
      _db
          .collection(AppConstants.colPatients)
          .doc(rx.patientId)
          .collection(AppConstants.colNotifications)
          .doc(_uuid.v4()),
      {
        'title': 'New Prescription',
        'body': 'Dr. ${rx.doctorName} prescribed $medCount '
            '${medCount == 1 ? 'medicine' : 'medicines'}'
            '${rx.diagnosis != null ? ' for ${rx.diagnosis}' : ''}.',
        'type': NotificationType.general.value,
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      },
    );

    await batch.commit();
  }

  // ─── Doctor Rating ────────────────────────────────────────────────────────

  Future<void> submitDoctorRating({
    required String appointmentId,
    required String doctorId,
    required int rating,
  }) async {
    // F5: Verify appointment ownership before updating rating.
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    await _db.runTransaction((tx) async {
      final doctorRef = _db.collection(AppConstants.colDoctors).doc(doctorId);
      final apptRef =
          _db.collection(AppConstants.colAppointments).doc(appointmentId);

      final doctorSnap = await tx.get(doctorRef);
      if (!doctorSnap.exists) return;

      // F5: Read and verify appointment ownership inside the transaction.
      final apptSnap = await tx.get(apptRef);
      if (!apptSnap.exists) throw Exception('Appointment not found');
      final apptData = apptSnap.data();
      if (apptData == null || apptData['patientId'] != uid) {
        throw Exception(
            'Unauthorised: appointment does not belong to current user');
      }

      final currentRating =
          (doctorSnap.data()?['rating'] as num?)?.toDouble() ?? 0.0;
      final currentReviewCount =
          (doctorSnap.data()?['reviewCount'] as int?) ?? 0;

      final newCount = currentReviewCount + 1;
      final newRating =
          ((currentRating * currentReviewCount) + rating) / newCount;

      tx.update(doctorRef, {
        'rating': newRating,
        'reviewCount': newCount,
      });
      tx.update(apptRef, {
        'patientRating': rating,
      });
    });
  }

  // ─── Consultation Notes ───────────────────────────────────────────────────

  Stream<List<ConsultationNote>> watchConsultationNotes(
      String patientId, String doctorId) {
    return _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(_colConsultationNotes)
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return ConsultationNote.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<ConsultationNote>()
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> addConsultationNote(ConsultationNote note) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(note.patientId)
        .collection(_colConsultationNotes)
        .doc(note.id)
        .set(note.toMap());
  }

  Future<void> deleteConsultationNote(String patientId, String noteId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(_colConsultationNotes)
        .doc(noteId)
        .delete();
  }

  // ─── Vitals ───────────────────────────────────────────────────────────────

  Stream<List<VitalReading>> watchVitals(String patientId, {int limit = 200}) {
    return _db
        .collection(AppConstants.colVitals)
        .where('patientId', isEqualTo: patientId)
        .limit(limit)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) {
                try {
                  return VitalReading.fromMap(d.data(), d.id);
                } catch (_) {
                  return null;
                }
              })
              .whereType<VitalReading>()
              .toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
          return list;
        });
  }

  Future<void> addVitalReading(VitalReading reading) => _db
      .collection(AppConstants.colVitals)
      .doc(reading.id)
      .set(reading.toMap());

  Future<void> deleteVitalReading(String readingId) =>
      _db.collection(AppConstants.colVitals).doc(readingId).delete();

  // One-shot fetch for doctor "Needs Attention" aggregator (ADR-014).
  // Uses get() instead of snapshots() to avoid N concurrent subscriptions.

  Future<List<Medicine>> getMedicinesOnce(String patientId) async {
    final snap = await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs
        .map((d) {
          try {
            return Medicine.fromMap(d.data(), d.id);
          } catch (_) {
            return null;
          }
        })
        .whereType<Medicine>()
        .toList();
  }

  Future<List<VitalReading>> getVitalsLastNDays(String patientId,
      {int days = 7}) async {
    final cutoff =
        Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
    final snap = await _db
        .collection(AppConstants.colVitals)
        .where('patientId', isEqualTo: patientId)
        .where('recordedAt', isGreaterThanOrEqualTo: cutoff)
        .get();
    return snap.docs
        .map((d) {
          try {
            return VitalReading.fromMap(d.data(), d.id);
          } catch (_) {
            return null;
          }
        })
        .whereType<VitalReading>()
        .toList();
  }

  // ─── Pill Count ───────────────────────────────────────────────────────────

  // M6: Wrap in a transaction to ensure pillsRemaining never goes below 0.
  Future<void> decrementPillCount(String patientId, String medicineId) async {
    final ref = _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['pillsRemaining'] as num?)?.toInt();
      if (current == null || current <= 0) return;
      tx.update(ref, {'pillsRemaining': current - 1});
    });
  }

  Future<void> incrementPillCount(String patientId, String medicineId) async {
    final ref = _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = (snap.data()?['pillsRemaining'] as num?)?.toInt();
      if (current == null) return;
      tx.update(ref, {'pillsRemaining': current + 1});
    });
  }
}
