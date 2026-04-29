import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../models/meal.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/activity_log.dart';
import '../models/app_notification.dart';
import '../core/constants/app_constants.dart';

const _uuid = Uuid();

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Users ────────────────────────────────────────────────────────────────

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Patient ──────────────────────────────────────────────────────────────

  Future<PatientProfile?> getPatient(String uid) async {
    final doc = await _db.collection(AppConstants.colPatients).doc(uid).get();
    if (!doc.exists) return null;
    return PatientProfile.fromMap(doc.data()!, uid);
  }

  Future<void> updatePatientProfile(String uid, Map<String, dynamic> data) async {
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

  Future<void> updateDoctorProfile(String uid, Map<String, dynamic> data) async {
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
      results.addAll(snap.docs.map((d) => DoctorProfile.fromMap(d.data(), d.id)));
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
      results.addAll(snap.docs.map((d) => PatientProfile.fromMap(d.data(), d.id)));
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
        .asyncMap((snap) => _fetchDoctorsByIds(snap.docs.map((d) => d.id).toList()));
  }

  Stream<List<PatientProfile>> watchDoctorPatients(String doctorId) {
    return _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .snapshots()
        .asyncMap((snap) => _fetchPatientsByIds(snap.docs.map((d) => d.id).toList()));
  }

  Stream<int> watchDoctorPatientCount(String doctorId) {
    return _db
        .collection(AppConstants.colDoctors)
        .doc(doctorId)
        .collection(AppConstants.colConnections)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<List<DoctorProfile>> searchDoctors({String? specialty, String? nameQuery}) async {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colDoctors);
    if (specialty != null && specialty.isNotEmpty) {
      query = query.where('specialty', isEqualTo: specialty);
    }
    final snap = await query.limit(50).get();
    var results = snap.docs.map((d) => DoctorProfile.fromMap(d.data(), d.id)).toList();
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
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Medicine.fromMap(d.data(), d.id)).toList());
  }

  Future<void> addMedicine(String patientId, Medicine medicine) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicine.id)
        .set(medicine.toMap());
  }

  Future<void> logDose(String patientId, String medicineId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({
      'loggedDoses': FieldValue.arrayUnion([Timestamp.fromDate(DateTime.now())]),
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

  // ─── Meals ────────────────────────────────────────────────────────────────

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
        .orderBy('loggedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MealLog.fromMap(d.data(), d.id)).toList());
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
        .map((s) => s.docs.map((d) => AppNotification.fromMap(d.data(), d.id)).toList());
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
    final snap = await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colNotifications)
        .where('isRead', isEqualTo: false)
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
        .orderBy('loggedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => ActivityLog.fromMap(d.data(), d.id)).toList());
  }

  // ─── Appointments ─────────────────────────────────────────────────────────

  Stream<List<Appointment>> watchPatientAppointments(String patientId, {int limit = 20}) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList());
  }

  // Booking only creates the appointment — connection is established on confirmation.
  Future<void> bookAppointment(Appointment appt) async {
    await _db.collection(AppConstants.colAppointments).doc(appt.id).set(appt.toMap());
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
      _db.collection(AppConstants.colPatients).doc(patientId)
          .collection(AppConstants.colConnections).doc(doctorId),
      {'connectedAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection(AppConstants.colDoctors).doc(doctorId)
          .collection(AppConstants.colConnections).doc(patientId),
      {'connectedAt': FieldValue.serverTimestamp()},
    );

    // In-app notification for the patient.
    batch.set(
      _db.collection(AppConstants.colPatients).doc(patientId)
          .collection(AppConstants.colNotifications).doc(_uuid.v4()),
      {
        'title': 'Appointment Confirmed',
        'body': 'Dr. $doctorName confirmed your appointment for ${_fmtDt(scheduledAt)}.',
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
  }) async {
    final data = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (scheduledAt != null) data['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    if (notes != null) data['notes'] = notes;
    await _db.collection(AppConstants.colAppointments).doc(apptId).update(data);

    if (status == AppointmentStatus.cancelled &&
        patientId != null && doctorId != null) {
      await _cleanupConnectionIfInactive(patientId, doctorId);
    }
  }

  Future<void> _cleanupConnectionIfInactive(String patientId, String doctorId) async {
    final remaining = await _db
        .collection(AppConstants.colAppointments)
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();
    if (remaining.docs.isEmpty) {
      await removeConnection(patientId, doctorId);
    }
  }

  String _fmtDt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $period';
  }

  // ─── Prescriptions ────────────────────────────────────────────────────────

  Stream<List<Prescription>> watchPatientPrescriptions(String patientId) {
    return _db
        .collection(AppConstants.colPrescriptions)
        .where('patientId', isEqualTo: patientId)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Prescription.fromMap(d.data(), d.id)).toList());
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
          id:           medRef.id,
          patientId:    rx.patientId,
          name:         med.name,
          dosage:       med.dosage,
          frequency:    med.frequency,
          prescribedBy: rx.doctorName,
          doctorId:     rx.doctorId,
          notes:        med.instructions,
          startDate:    rx.issuedAt,
        ).toMap(),
      );
    }

    await batch.commit();
  }
}
