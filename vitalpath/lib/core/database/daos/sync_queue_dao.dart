import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  Future<void> enqueue(SyncQueueCompanion entry) {
    return into(syncQueue).insert(entry);
  }

  Future<List<SyncQueueEntry>> getPendingEntries({int limit = 50}) {
    return (select(syncQueue)
          ..where((s) =>
              s.status.equals('pending') | s.status.equals('failed'))
          ..where((s) => s.retryCount.isSmallerThanValue(3))
          ..orderBy([(s) => OrderingTerm.asc(s.originalTimestamp)])
          ..limit(limit))
        .get();
  }

  Future<int> markInProgress(String entryId) {
    return (update(syncQueue)..where((s) => s.id.equals(entryId)))
        .write(const SyncQueueCompanion(status: Value('in_progress')));
  }

  Future<int> markSynced(String entryId) {
    return (update(syncQueue)..where((s) => s.id.equals(entryId)))
        .write(SyncQueueCompanion(
          status: const Value('synced'),
          processedAt: Value(DateTime.now()),
        ));
  }

  Future<int> markFailed(String entryId, String error) async {
    final entry = await (select(syncQueue)
          ..where((s) => s.id.equals(entryId)))
        .getSingleOrNull();
    if (entry == null) return 0;
    return (update(syncQueue)..where((s) => s.id.equals(entryId)))
        .write(SyncQueueCompanion(
          status: const Value('failed'),
          retryCount: Value(entry.retryCount + 1),
          lastError: Value(error),
        ));
  }

  /// Clean up synced entries older than 7 days
  Future<int> cleanupSynced() {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return (delete(syncQueue)
          ..where((s) =>
              s.status.equals('synced') &
              s.processedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Stream<int> watchPendingCount() {
    return (selectOnly(syncQueue)
          ..addColumns([syncQueue.id.count()])
          ..where(
              syncQueue.status.equals('pending') | syncQueue.status.equals('failed')))
        .map((row) => row.read(syncQueue.id.count()) ?? 0)
        .watchSingle();
  }
}
