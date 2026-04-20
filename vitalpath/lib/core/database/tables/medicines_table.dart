import 'package:drift/drift.dart';

/// Medicines table — stores medication definitions.
/// Inventory count auto-decrements on each log (SRS §4.1).
class Medicines extends Table {
  /// Primary key
  TextColumn get id => text()();

  /// User who owns this medicine
  TextColumn get userId => text()();

  /// Display name (e.g. "Metformin", "Vitamin D")
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Unit: 'mg' | 'ml' | 'pills' | 'tablet' | 'capsule' | 'drops'
  TextColumn get unit => text().withDefault(const Constant('pills'))();

  /// Dosage amount (positive numeric — SRS §4.1 validation)
  RealColumn get dosage => real()();

  /// Frequency: 'daily' | 'weekly' | 'as_needed' | 'twice_daily' | 'thrice_daily'
  TextColumn get frequency => text()();

  /// Scheduled times stored as JSON array string: ["08:00","14:00","20:00"]
  TextColumn get scheduledTimes => text().withDefault(const Constant('[]'))();

  /// Days of week for weekly freq: JSON array ["Mon","Wed","Fri"]
  TextColumn get scheduledDays => text().withDefault(const Constant('[]'))();

  /// When the medication course starts
  DateTimeColumn get startDate => dateTime()();

  /// When the medication course ends (nullable)
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Current pill/dose inventory count
  IntColumn get inventoryCount => integer().withDefault(const Constant(0))();

  /// Refill alert threshold (default: 5 per AppConstants)
  IntColumn get refillThreshold => integer().withDefault(const Constant(5))();

  /// Optional image path for visual identification (SRS §4.1)
  TextColumn get imagePath => text().nullable()();

  /// Notes/instructions (e.g. "Take with food")
  TextColumn get notes => text().nullable()();

  /// Color hex for UI card (e.g. "#60A5FA")
  TextColumn get colorHex => text().withDefault(const Constant('#0B6E4F'))();

  /// Whether this prescription was pushed by a doctor (SRS §4.4)
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  /// Doctor connection ID if verified
  TextColumn get doctorConnectionId => text().nullable()();

  /// Whether the medicine is currently active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  /// Supabase last sync timestamp
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// Local creation timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last update
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks every medicine log action (taken, skipped, snoozed).
class MedicineLogs extends Table {
  TextColumn get id => text()();
  TextColumn get medicineId => text().references(Medicines, #id)();
  TextColumn get userId => text()();

  /// 'taken' | 'skipped' | 'snoozed' | 'rescheduled'
  TextColumn get action => text()();

  /// The ORIGINAL scheduled time for this dose
  DateTimeColumn get scheduledAt => dateTime()();

  /// When the user actually logged it (may differ from scheduled — offline-first)
  DateTimeColumn get loggedAt => dateTime()();

  /// Notes (e.g., reason for skip)
  TextColumn get notes => text().nullable()();

  /// Is this log pending sync to cloud? (SRS §5.1 offline-first)
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  /// Sync retry count
  IntColumn get syncRetryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
