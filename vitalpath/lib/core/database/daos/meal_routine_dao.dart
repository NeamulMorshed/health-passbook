import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meal_routines_table.dart';

part 'meal_routine_dao.g.dart';

@DriftAccessor(tables: [MealRoutines, MealLogs])
class MealRoutineDao extends DatabaseAccessor<AppDatabase>
    with _$MealRoutineDaoMixin {
  MealRoutineDao(super.db);

  Stream<List<MealRoutine>> watchActiveRoutines(String userId) {
    return (select(mealRoutines)
          ..where((m) => m.userId.equals(userId) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.windowStart)]))
        .watch();
  }

  Future<void> insertRoutine(MealRoutinesCompanion routine) {
    return into(mealRoutines).insert(routine, mode: InsertMode.insertOrReplace);
  }

  Future<bool> updateRoutine(MealRoutinesCompanion routine) {
    return update(mealRoutines).replace(routine);
  }

  Future<int> deactivateRoutine(String id) {
    return (update(mealRoutines)..where((m) => m.id.equals(id)))
        .write(MealRoutinesCompanion(isActive: const Value(false)));
  }

  Future<void> insertMealLog(MealLogsCompanion log) {
    return into(mealLogs).insert(log);
  }

  Stream<List<MealLog>> watchLogsForDate(String userId, DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(mealLogs)
          ..where((l) =>
              l.userId.equals(userId) &
              l.scheduledAt.isBiggerOrEqualValue(dayStart) &
              l.scheduledAt.isSmallerThanValue(dayEnd)))
        .watch();
  }

  Future<List<MealLog>> getPendingSyncLogs() {
    return (select(mealLogs)..where((l) => l.pendingSync.equals(true))).get();
  }

  Future<int> markLogSynced(String logId) {
    return (update(mealLogs)..where((l) => l.id.equals(logId)))
        .write(const MealLogsCompanion(pendingSync: Value(false)));
  }
}
