import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

const _uuid = Uuid();

// ─── Doctor Profile ───────────────────────────────────────────────────────────
final doctorProfileProvider = FutureProvider.family<DoctorProfile?, String>((ref, uid) async {
  return ref.watch(firestoreServiceProvider).getDoctor(uid);
});

// ─── Doctor Appointments ──────────────────────────────────────────────────────
final doctorAppointmentsProvider = StreamProvider.family<List<Appointment>, String>((ref, doctorId) {
  return ref.watch(firestoreServiceProvider).watchDoctorAppointments(doctorId);
});

// ─── Search Doctors (for patients) ───────────────────────────────────────────
final doctorSearchProvider = FutureProvider.family<List<DoctorProfile>, String>((ref, specialty) async {
  return ref.watch(firestoreServiceProvider).searchDoctors(specialty: specialty.isEmpty ? null : specialty);
});

// ─── Doctor's Patient List ────────────────────────────────────────────────────
final doctorPatientsProvider = FutureProvider.family<List<PatientProfile>, List<String>>((ref, ids) async {
  return ref.watch(firestoreServiceProvider).getDoctorPatients(ids);
});

// ─── Doctor Appointment Notifier ─────────────────────────────────────────────
class DoctorAppointmentNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  DoctorAppointmentNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> confirm(String apptId, DateTime scheduledAt, {String? notes}) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateAppointmentStatus(apptId, AppointmentStatus.confirmed, scheduledAt: scheduledAt, notes: notes);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> complete(String apptId) async {
    await _db.updateAppointmentStatus(apptId, AppointmentStatus.completed);
  }

  Future<void> cancel(String apptId) async {
    await _db.updateAppointmentStatus(apptId, AppointmentStatus.cancelled);
  }
}

final doctorAppointmentNotifierProvider = StateNotifierProvider<DoctorAppointmentNotifier, AsyncValue<void>>((ref) {
  return DoctorAppointmentNotifier(ref.watch(firestoreServiceProvider));
});

// ─── Prescription Notifier ────────────────────────────────────────────────────
class PrescriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  PrescriptionNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> add({
    required String patientId,
    required String doctorId,
    required String doctorName,
    required List<PrescribedMed> medicines,
    String? diagnosis,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final rx = Prescription(
        id: _uuid.v4(),
        patientId: patientId,
        doctorId: doctorId,
        doctorName: doctorName,
        medicines: medicines,
        diagnosis: diagnosis,
        notes: notes,
        issuedAt: DateTime.now(),
      );
      await _db.addPrescription(rx);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final prescriptionNotifierProvider = StateNotifierProvider<PrescriptionNotifier, AsyncValue<void>>((ref) {
  return PrescriptionNotifier(ref.watch(firestoreServiceProvider));
});
