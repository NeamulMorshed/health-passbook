import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medicine.dart';
import '../models/meal.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/patient.dart';
import '../models/doctor.dart';
import '../models/activity_log.dart';
import '../core/constants/app_constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Patient ──────────────────────────────────────────────────────────────

  Future<PatientProfile?> getPatient(String uid) async {
    final doc = await _db.collection(AppConstants.colPatients).doc(uid).get();
    if (!doc.exists) return null;
    return PatientProfile.fromMap(doc.data()!, uid);
  }

  Future<void> updatePatientProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colPatients).doc(uid).set(data, SetOptions(merge: true));
  }

  // ─── Doctor ───────────────────────────────────────────────────────────────

  Future<DoctorProfile?> getDoctor(String uid) async {
    final doc = await _db.collection(AppConstants.colDoctors).doc(uid).get();
    if (!doc.exists) return null;
    return DoctorProfile.fromMap(doc.data()!, uid);
  }

  Future<void> updateDoctorProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colDoctors).doc(uid).set(data, SetOptions(merge: true));
  }

  Future<List<DoctorProfile>> searchDoctors({String? specialty, String? name}) async {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colDoctors);
    if (specialty != null && specialty.isNotEmpty) {
      query = query.where('specialty', isEqualTo: specialty);
    }
    final snap = await query.limit(50).get();
    return snap.docs.map((d) => DoctorProfile.fromMap(d.data(), d.id)).toList();
  }

  Future<List<PatientProfile>> getDoctorPatients(List<String> patientIds) async {
    if (patientIds.isEmpty) return [];
    final snap = await _db
        .collection(AppConstants.colPatients)
        .where(FieldPath.documentId, whereIn: patientIds.take(10).toList())
        .get();
    return snap.docs.map((d) => PatientProfile.fromMap(d.data(), d.id)).toList();
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
    });
  }

  Future<void> deleteMedicine(String patientId, String medicineId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMedicines)
        .doc(medicineId)
        .update({'isActive': false});
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

  Future<void> deleteMeal(String patientId, String mealId) async {
    await _db
        .collection(AppConstants.colPatients)
        .doc(patientId)
        .collection(AppConstants.colMeals)
        .doc(mealId)
        .delete();
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

  Stream<List<Appointment>> watchPatientAppointments(String patientId) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<Appointment>> watchDoctorAppointments(String doctorId) {
    return _db
        .collection(AppConstants.colAppointments)
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Appointment.fromMap(d.data(), d.id)).toList());
  }

  Future<void> bookAppointment(Appointment appt) async {
    await _db.collection(AppConstants.colAppointments).doc(appt.id).set(appt.toMap());
    // Add patient to doctor's list
    await _db.collection(AppConstants.colDoctors).doc(appt.doctorId).update({
      'patientIds': FieldValue.arrayUnion([appt.patientId]),
    });
  }

  Future<void> updateAppointmentStatus(String apptId, String status, {DateTime? scheduledAt, String? notes}) async {
    final data = <String, dynamic>{'status': status};
    if (scheduledAt != null) data['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    if (notes != null) data['notes'] = notes;
    await _db.collection(AppConstants.colAppointments).doc(apptId).update(data);
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

  Future<void> addPrescription(Prescription rx) async {
    await _db.collection(AppConstants.colPrescriptions).doc(rx.id).set(rx.toMap());
    // Also add medicines to patient's medicine list
    for (final med in rx.medicines) {
      final medDoc = _db
          .collection(AppConstants.colPatients)
          .doc(rx.patientId)
          .collection(AppConstants.colMedicines)
          .doc();
      await medDoc.set(Medicine(
        id: medDoc.id,
        patientId: rx.patientId,
        name: med.name,
        dosage: med.dosage,
        frequency: med.frequency,
        prescribedBy: rx.doctorName,
        doctorId: rx.doctorId,
        notes: med.instructions,
        startDate: rx.issuedAt,
      ).toMap());
    }
  }
}
