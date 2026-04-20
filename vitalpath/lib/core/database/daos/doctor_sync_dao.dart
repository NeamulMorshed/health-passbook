import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/doctor_sync_table.dart';

part 'doctor_sync_dao.g.dart';

@DriftAccessor(tables: [DoctorConnections, Prescriptions, Appointments])
class DoctorSyncDao extends DatabaseAccessor<AppDatabase>
    with _$DoctorSyncDaoMixin {
  DoctorSyncDao(super.db);

  // ── Doctor Connections ────────────────────────────────────────

  Stream<List<DoctorConnection>> watchConnections(String patientId) {
    return (select(doctorConnections)
          ..where((d) => d.patientId.equals(patientId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<void> upsertConnection(DoctorConnectionsCompanion connection) {
    return into(doctorConnections)
        .insert(connection, mode: InsertMode.insertOrReplace);
  }

  Future<int> revokeConnection(String connectionId) {
    return (update(doctorConnections)
          ..where((d) => d.id.equals(connectionId)))
        .write(const DoctorConnectionsCompanion(
            status: Value('revoked')));
  }

  // ── Prescriptions ─────────────────────────────────────────────

  Stream<List<Prescription>> watchActivePrescriptions(String patientId) {
    return (select(prescriptions)
          ..where((p) =>
              p.patientId.equals(patientId) & p.status.equals('active'))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<void> upsertPrescription(PrescriptionsCompanion prescription) {
    return into(prescriptions)
        .insert(prescription, mode: InsertMode.insertOrReplace);
  }

  // ── Appointments ──────────────────────────────────────────────

  Stream<List<Appointment>> watchUpcomingAppointments(String patientId) {
    return (select(appointments)
          ..where((a) =>
              a.patientId.equals(patientId) &
              a.status.equals('scheduled') &
              a.appointmentAt.isBiggerThanValue(DateTime.now()))
          ..orderBy([(a) => OrderingTerm.asc(a.appointmentAt)]))
        .watch();
  }

  Future<void> upsertAppointment(AppointmentsCompanion appointment) {
    return into(appointments)
        .insert(appointment, mode: InsertMode.insertOrReplace);
  }

  /// Attempting to delete a verified entry — requires double confirmation (SRS §4.4)
  Future<bool> isVerifiedAppointment(String appointmentId) async {
    final appt = await (select(appointments)
          ..where((a) => a.id.equals(appointmentId)))
        .getSingleOrNull();
    return appt?.isVerified ?? false;
  }
}
