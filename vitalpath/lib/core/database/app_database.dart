import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'daos/activity_dao.dart';
import 'daos/doctor_sync_dao.dart';
import 'daos/medicine_dao.dart';
import 'daos/meal_routine_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/user_profile_dao.dart';
import 'tables/activity_table.dart';
import 'tables/doctor_sync_table.dart';
import 'tables/meal_routines_table.dart';
import 'tables/medicines_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/user_profile_table.dart';

part 'app_database.g.dart';

/// VitalPath local database.
/// Drift (SQLite) is used for offline-first capability and complex relational
/// queries across health data dimensions (SRS §2.1, Technology Blueprint §1.1).
@DriftDatabase(
  tables: [
    UserProfiles,
    Medicines,
    MedicineLogs,
    MealRoutines,
    MealLogs,
    ActivityLogs,
    WalkSessions,
    DoctorConnections,
    Prescriptions,
    Appointments,
    SyncQueue,
  ],
  daos: [
    UserProfileDao,
    MedicineDao,
    MealRoutineDao,
    ActivityDao,
    DoctorSyncDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _createIndexes(m);
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Version migrations will be added here as schema evolves
        },
        beforeOpen: (details) async {
          // Enable WAL mode for better concurrent performance
          await customStatement('PRAGMA journal_mode=WAL');
          // Enable foreign key enforcement
          await customStatement('PRAGMA foreign_keys=ON');
          // Optimize for mobile SQLite
          await customStatement('PRAGMA synchronous=NORMAL');
          await customStatement('PRAGMA cache_size=10000');
        },
      );

  /// Creates indexes for performance-critical queries.
  Future<void> _createIndexes(Migrator m) async {
    // Fast lookups for daily dashboard
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_medicine_logs_user_scheduled '
      'ON medicine_logs(user_id, scheduled_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_logs_user_date '
      'ON activity_logs(user_id, date)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_medicines_user_active '
      'ON medicines(user_id, is_active)',
    );
    // Sync queue draining
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status '
      'ON sync_queue(status, created_at)',
    );
    // Medicine log — duplicate detection (SRS §5.2)
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_medicine_logs_medicine_logged '
      'ON medicine_logs(medicine_id, logged_at)',
    );
    // Meal logs
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_meal_logs_user_scheduled '
      'ON meal_logs(user_id, scheduled_at)',
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'vitalpath_db');
  }
}

/// Provides the singleton AppDatabase instance.
@riverpod
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
