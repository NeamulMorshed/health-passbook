import 'package:drift/drift.dart';

/// Offline-First Sync Queue — the heart of the offline architecture (SRS §5.1).
///
/// When a user logs a medicine or meal while offline, the action is stored
/// here. The background sync service drains this queue upon reconnection,
/// preserving the ORIGINAL timestamp (not the sync time).
class SyncQueue extends Table {
  TextColumn get id => text()();

  /// Entity type: 'medicine_log' | 'meal_log' | 'walk_session' | 'profile_update'
  TextColumn get entityType => text()();

  /// The local entity ID
  TextColumn get entityId => text()();

  /// Operation: 'create' | 'update' | 'delete'
  TextColumn get operation => text()();

  /// The full JSON payload to sync
  TextColumn get payload => text()();

  /// ORIGINAL timestamp when action occurred (SRS §5.1)
  DateTimeColumn get originalTimestamp => dateTime()();

  /// Status: 'pending' | 'in_progress' | 'failed' | 'synced'
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();

  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
