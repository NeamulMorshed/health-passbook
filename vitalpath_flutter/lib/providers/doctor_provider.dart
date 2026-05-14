import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/prescription.dart';
import '../models/consultation_note.dart';
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

// ─── My Doctors (patient's connected doctors via subcollection) ───────────────
final myDoctorsProvider = StreamProvider.family<List<DoctorProfile>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchMyDoctors(patientId);
});

// ─── Doctor's Patient List (stream via connections subcollection) ─────────────
final doctorPatientsStreamProvider = StreamProvider.family<List<PatientProfile>, String>((ref, doctorId) {
  return ref.watch(firestoreServiceProvider).watchDoctorPatients(doctorId);
});

// ─── Doctor's Patient Count (live badge on dashboard) ────────────────────────
final doctorPatientCountProvider = StreamProvider.family<int, String>((ref, doctorId) {
  return ref.watch(firestoreServiceProvider).watchDoctorPatientCount(doctorId);
});

// ─── Search Doctors (for patients) ───────────────────────────────────────────
typedef DoctorSearchKey = ({String nameQuery, String specialty, String city});

final doctorSearchProvider = FutureProvider.family<List<DoctorProfile>, DoctorSearchKey>((ref, key) async {
  return ref.watch(firestoreServiceProvider).searchDoctors(
    specialty: key.specialty.isEmpty ? null : key.specialty,
    nameQuery: key.nameQuery.isEmpty ? null : key.nameQuery,
    city: key.city.isEmpty || key.city == 'All' ? null : key.city,
  );
});

// ─── Connection check (for patient view route guard) ─────────────────────────
typedef ConnectionKey = ({String doctorId, String patientId});

final connectionCheckProvider = StreamProvider.family<bool, ConnectionKey>((ref, key) {
  return ref.watch(firestoreServiceProvider).watchConnection(key.doctorId, key.patientId);
});

// ─── Connection removal notifier ─────────────────────────────────────────────
class ConnectionNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  ConnectionNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> remove(String patientId, String doctorId) async {
    state = const AsyncValue.loading();
    try {
      await _db.removeConnection(patientId, doctorId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final connectionNotifierProvider =
    StateNotifierProvider<ConnectionNotifier, AsyncValue<void>>((ref) {
  return ConnectionNotifier(ref.watch(firestoreServiceProvider));
});

// ─── Doctor Appointment Notifier ─────────────────────────────────────────────
class DoctorAppointmentNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  DoctorAppointmentNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> confirm(
    String apptId,
    DateTime scheduledAt, {
    required String patientId,
    required String doctorId,
    required String doctorName,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _db.confirmAppointment(
        apptId: apptId,
        patientId: patientId,
        doctorId: doctorId,
        doctorName: doctorName,
        scheduledAt: scheduledAt,
        notes: notes,
      );
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> complete(String apptId) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateAppointmentStatus(apptId, AppointmentStatus.completed);
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

// ─── Consultation Notes ───────────────────────────────────────────────────────
typedef ConsultationNotesKey = ({String patientId, String doctorId});

final consultationNotesProvider = StreamProvider.family<List<ConsultationNote>, ConsultationNotesKey>((ref, key) {
  return ref.watch(firestoreServiceProvider).watchConsultationNotes(key.patientId, key.doctorId);
});

class ConsultationNoteNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  ConsultationNoteNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> add({
    required String patientId,
    required String doctorId,
    required String doctorName,
    required String note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final cn = ConsultationNote(
        id: const Uuid().v4(),
        patientId: patientId,
        doctorId: doctorId,
        doctorName: doctorName,
        note: note,
        createdAt: DateTime.now(),
      );
      await _db.addConsultationNote(cn);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> delete(String patientId, String noteId) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteConsultationNote(patientId, noteId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final consultationNoteNotifierProvider =
    StateNotifierProvider<ConsultationNoteNotifier, AsyncValue<void>>((ref) {
  return ConsultationNoteNotifier(ref.watch(firestoreServiceProvider));
});
