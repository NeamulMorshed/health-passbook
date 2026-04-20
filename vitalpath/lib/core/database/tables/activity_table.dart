import 'package:drift/drift.dart';

/// Daily step summaries pulled from Android Health Connect (SRS §4.3).
class ActivityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// The calendar date for this step count: stored as "yyyy-MM-dd"
  TextColumn get date => text()();

  /// Total steps recorded for this day
  IntColumn get stepCount => integer().withDefault(const Constant(0))();

  /// Step goal for this day
  IntColumn get stepGoal => integer().withDefault(const Constant(10000))();

  /// Distance in meters
  RealColumn get distanceMeters => real().withDefault(const Constant(0.0))();

  /// Active calories burned
  RealColumn get caloriesBurned => real().nullable()();

  /// Active minutes
  IntColumn get activeMinutes => integer().withDefault(const Constant(0))();

  /// Last time step data was pulled from Health Connect
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, date},
      ];
}

/// GPS Walk sessions — stores polyline data for route mapping (SRS §4.3).
class WalkSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();

  /// Total distance walked in meters
  RealColumn get distanceMeters => real().withDefault(const Constant(0.0))();

  /// Step count recorded during this session
  IntColumn get stepCount => integer().withDefault(const Constant(0))();

  /// Duration in seconds
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();

  /// Average pace in seconds per km
  RealColumn get avgPaceSecPerKm => real().nullable()();

  /// GPS polyline points stored as JSON: [{"lat":...,"lng":...,"t":...}, ...]
  /// NOTE: Per SRS §5.3 — if storage is full, this is discarded. stepCount survives.
  TextColumn get polylineJson => text().nullable()();

  /// Was the session completed normally or interrupted?
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
