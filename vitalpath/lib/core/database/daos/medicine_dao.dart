import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/medicines_table.dart';

part 'medicine_dao.g.dart';

/// Data Access Object for all medicine-related DB operations.
/// Implements the offline-first refill logic from SRS §4.1.
@DriftAccessor(tables: [Medicines, MedicineLogs])
class MedicineDao extends DatabaseAccessor<AppDatabase>
    with _$MedicineDaoMixin {
  MedicineDao(super.db);

  // ── Medicines ─────────────────────────────────────────────────

  /// Watch all active medicines for a user (reactive stream for Riverpod)
  Stream<List<Medicine>> watchActiveMedicines(String userId) {
    return (select(medicines)
          ..where((m) => m.userId.equals(userId) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .watch();
  }

  /// Get a single medicine by ID
  Future<Medicine?> getMedicineById(String id) {
    return (select(medicines)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new medicine
  Future<void> insertMedicine(MedicinesCompanion medicine) {
    return into(medicines).insert(medicine, mode: InsertMode.insertOrReplace);
  }

  /// Update a medicine record
  Future<bool> updateMedicine(MedicinesCompanion medicine) {
    return update(medicines).replace(medicine);
  }

  /// Soft-delete (deactivate) a medicine
  Future<int> deactivateMedicine(String id) {
    return (update(medicines)..where((m) => m.id.equals(id)))
        .write(MedicinesCompanion(isActive: const Value(false)));
  }

  /// Decrement inventory count after a dose is logged.
  /// Returns the new count. Triggers refill check in the service layer.
  Future<int> decrementInventory(String medicineId) async {
    final medicine = await getMedicineById(medicineId);
    if (medicine == null) return 0;

    final newCount = (medicine.inventoryCount - 1).clamp(0, 99999);
    await (update(medicines)..where((m) => m.id.equals(medicineId)))
        .write(MedicinesCompanion(inventoryCount: Value(newCount)));
    return newCount;
  }

  /// Get all medicines with inventory at or below refill threshold (SRS §4.1)
  Future<List<Medicine>> getMedicinesNeedingRefill(String userId) {
    return (select(medicines)
          ..where((m) =>
              m.userId.equals(userId) &
              m.isActive.equals(true) &
              m.inventoryCount.isSmallerOrEqualValue(m.refillThreshold as int)))
        .get();
  }

  // ── Medicine Logs ─────────────────────────────────────────────

  /// Insert a medicine log entry
  Future<void> insertMedicineLog(MedicineLogsCompanion log) {
    return into(medicineLogs).insert(log);
  }

  /// Watch logs for a specific medicine on a given date
  Stream<List<MedicineLog>> watchLogsForDate(String userId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    return (select(medicineLogs)
          ..where((l) =>
              l.userId.equals(userId) &
              l.scheduledAt.isBiggerOrEqualValue(dayStart) &
              l.scheduledAt.isSmallerThanValue(dayEnd))
          ..orderBy([(l) => OrderingTerm.asc(l.scheduledAt)]))
        .watch();
  }

  /// Check for duplicate log within the time window (SRS §5.2 — overdose prevention)
  Future<MedicineLog?> findRecentLog({
    required String medicineId,
    required DateTime since,
  }) {
    return (select(medicineLogs)
          ..where((l) =>
              l.medicineId.equals(medicineId) &
              l.loggedAt.isBiggerOrEqualValue(since) &
              l.action.equals('taken'))
          ..orderBy([(l) => OrderingTerm.desc(l.loggedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get pending sync logs (offline-first — SRS §5.1)
  Future<List<MedicineLog>> getPendingSyncLogs() {
    return (select(medicineLogs)
          ..where((l) => l.pendingSync.equals(true))
          ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
        .get();
  }

  /// Mark a log as synced
  Future<int> markLogSynced(String logId) {
    return (update(medicineLogs)..where((l) => l.id.equals(logId)))
        .write(const MedicineLogsCompanion(pendingSync: Value(false)));
  }

  /// Get adherence report for a date range (used by doctor portal — SRS §3.2)
  Future<List<MedicineLog>> getAdherenceReport({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    return (select(medicineLogs)
          ..where((l) =>
              l.userId.equals(userId) &
              l.scheduledAt.isBiggerOrEqualValue(from) &
              l.scheduledAt.isSmallerThanValue(to))
          ..orderBy([(l) => OrderingTerm.asc(l.scheduledAt)]))
        .get();
  }

  /// Complex query: medications taken on days user walked >5km (Technology Blueprint §1.1)
  Future<List<MedicineLog>> getMedsOnHighActivityDays({
    required String userId,
    required double minDistanceKm,
  }) async {
    final minDistanceMeters = minDistanceKm * 1000;

    // Get high-activity dates
    final result = await customSelect(
      '''
      SELECT ml.* FROM medicine_logs ml
      INNER JOIN activity_logs al
        ON al.user_id = ml.user_id
        AND al.date = strftime('%Y-%m-%d', ml.scheduled_at / 1000000, 'unixepoch')
      WHERE ml.user_id = ?
        AND al.distance_meters >= ?
        AND ml.action = 'taken'
      ORDER BY ml.scheduled_at ASC
      ''',
      variables: [Variable.withString(userId), Variable.withReal(minDistanceMeters)],
      readsFrom: {medicineLogs, db.activityLogs},
    ).get();

    return result.map((row) => MedicineLog.fromData(row.data)).toList();
  }
}
