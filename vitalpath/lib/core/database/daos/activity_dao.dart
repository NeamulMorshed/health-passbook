import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/activity_table.dart';

part 'activity_dao.g.dart';

@DriftAccessor(tables: [ActivityLogs, WalkSessions])
class ActivityDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  // ── Activity Logs ─────────────────────────────────────────────

  Future<ActivityLog?> getLogForDate(String userId, String date) {
    return (select(activityLogs)
          ..where((a) => a.userId.equals(userId) & a.date.equals(date)))
        .getSingleOrNull();
  }

  Stream<ActivityLog?> watchLogForDate(String userId, String date) {
    return (select(activityLogs)
          ..where((a) => a.userId.equals(userId) & a.date.equals(date)))
        .watchSingleOrNull();
  }

  Future<void> upsertActivityLog(ActivityLogsCompanion log) {
    return into(activityLogs).insert(log, mode: InsertMode.insertOrReplace);
  }

  /// Get last N days of activity for history chart
  Future<List<ActivityLog>> getRecentActivity({
    required String userId,
    required int days,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    return (select(activityLogs)
          ..where(
              (a) => a.userId.equals(userId) & a.date.isBiggerOrEqualValue(cutoffStr))
          ..orderBy([(a) => OrderingTerm.desc(a.date)]))
        .get();
  }

  // ── Walk Sessions ─────────────────────────────────────────────

  Future<void> insertWalkSession(WalkSessionsCompanion session) {
    return into(walkSessions).insert(session, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updateWalkSession(WalkSessionsCompanion session) {
    return update(walkSessions).replace(session);
  }

  Stream<List<WalkSession>> watchRecentSessions(String userId, {int limit = 10}) {
    return (select(walkSessions)
          ..where((s) => s.userId.equals(userId))
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
          ..limit(limit))
        .watch();
  }

  Future<WalkSession?> getActiveSession(String userId) {
    return (select(walkSessions)
          ..where((s) => s.userId.equals(userId) & s.isCompleted.equals(false))
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)])
          ..limit(1))
        .getSingleOrNull();
  }
}
