import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/health_connector_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'dashboard_provider.g.dart';

/// Today's date string "yyyy-MM-dd"
String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Watch today's activity log (steps) — reactive
@riverpod
Stream<ActivityLog?> todayActivity(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  final db = ref.watch(appDatabaseProvider);
  return db.activityDao.watchLogForDate(user.id, _todayKey());
}

/// Watch today's medicine logs
@riverpod
Stream<List<MedicineLog>> todayMedicineLogs(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.medicineDao.watchLogsForDate(user.id, DateTime.now());
}

/// Watch all active medicines — drives the dashboard timeline
@riverpod
Stream<List<Medicine>> activeMedicines(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.medicineDao.watchActiveMedicines(user.id);
}

/// Watch today's meal logs
@riverpod
Stream<List<MealLog>> todayMealLogs(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.mealRoutineDao.watchLogsForDate(user.id, DateTime.now());
}

/// Watch active meal routines
@riverpod
Stream<List<MealRoutine>> activeMealRoutines(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.mealRoutineDao.watchActiveRoutines(user.id);
}

/// Watch user profile
@riverpod
Stream<UserProfile?> userProfile(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  final db = ref.watch(appDatabaseProvider);
  return db.userProfileDao.watchProfile(user.id);
}

/// Fetch live step data from Health Connect
@riverpod
Future<StepData> liveStepData(Ref ref) {
  return ref.watch(healthConnectorServiceProvider).fetchTodaySteps();
}

/// Dashboard summary state — aggregates all data for the UI
class DashboardSummary {
  final int stepCount;
  final int stepGoal;
  final double distanceKm;
  final int totalMedicines;
  final int medicinesTaken;
  final int medicinesMissed;
  final int upcomingMedicines;
  final int totalMeals;
  final int mealsLogged;

  const DashboardSummary({
    required this.stepCount,
    required this.stepGoal,
    required this.distanceKm,
    required this.totalMedicines,
    required this.medicinesTaken,
    required this.medicinesMissed,
    required this.upcomingMedicines,
    required this.totalMeals,
    required this.mealsLogged,
  });

  double get stepProgress =>
      stepGoal > 0 ? (stepCount / stepGoal).clamp(0.0, 1.0) : 0.0;

  double get medicineAdherencePercent =>
      totalMedicines > 0 ? (medicinesTaken / totalMedicines) * 100 : 0;
}
