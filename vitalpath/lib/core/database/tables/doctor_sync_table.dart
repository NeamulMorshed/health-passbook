import 'package:drift/drift.dart';

/// Doctor-Patient connections (SRS §4.4).
class DoctorConnections extends Table {
  TextColumn get id => text()();

  /// The patient's user ID
  TextColumn get patientId => text()();

  /// The doctor's Supabase user ID (set after QR/code sync)
  TextColumn get doctorId => text().nullable()();

  TextColumn get doctorName => text()();
  TextColumn get clinicName => text().nullable()();
  TextColumn get contactNumber => text().nullable()();

  /// Specialty (e.g., "Cardiologist", "General Practitioner")
  TextColumn get specialty => text().nullable()();

  /// Status: 'pending' | 'active' | 'revoked'
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  /// The 6-digit code used for pairing (SRS §3.2)
  TextColumn get syncCode => text().nullable()();

  /// When the sync code expires
  DateTimeColumn get syncCodeExpiresAt => dateTime().nullable()();

  DateTimeColumn get connectedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Prescriptions pushed from doctor to patient (SRS §3.2 — Protocol Management).
class Prescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get doctorConnectionId =>
      text().references(DoctorConnections, #id)();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();

  /// The medicine record created from this prescription
  TextColumn get medicineId => text().nullable()();

  TextColumn get medicineName => text()();
  RealColumn get dosage => real()();
  TextColumn get unit => text()();
  TextColumn get frequency => text()();
  TextColumn get scheduledTimes => text().withDefault(const Constant('[]'))();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  TextColumn get instructions => text().nullable()();

  /// Status: 'active' | 'completed' | 'cancelled'
  TextColumn get status =>
      text().withDefault(const Constant('active'))();

  /// Server-side timestamp (wins during conflict resolution — SRS §5.3)
  DateTimeColumn get serverTimestamp => dateTime()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Appointments scheduled by the doctor
class Appointments extends Table {
  TextColumn get id => text()();
  TextColumn get doctorConnectionId =>
      text().references(DoctorConnections, #id)();
  TextColumn get patientId => text()();

  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get appointmentAt => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();

  TextColumn get notes => text().nullable()();

  /// 'scheduled' | 'completed' | 'cancelled' | 'rescheduled'
  TextColumn get status =>
      text().withDefault(const Constant('scheduled'))();

  /// Doctor-set entries are verified (SRS §4.4)
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  DateTimeColumn get serverTimestamp => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
