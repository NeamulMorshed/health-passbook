import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_insight.dart';
import '../models/medicine.dart';
import '../models/meal.dart';
import '../models/activity_log.dart';
import '../models/patient.dart';
import '../services/ai_insights_service.dart';

final aiInsightsServiceProvider = Provider<AiInsightsService>((ref) {
  return AiInsightsService();
});

class InsightsNotifier extends StateNotifier<AsyncValue<List<HealthInsight>>> {
  InsightsNotifier(this._service) : super(const AsyncValue.data([]));

  final AiInsightsService _service;

  Future<void> generate({
    required List<Medicine> medicines,
    required List<MealLog> meals,
    required List<ActivityLog> activities,
    required PatientProfile? patient,
    required int pendingAppointments,
    required int medStreak,
    required int activityStreak,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final recentMeds = medicines.where((m) => m.isActive).toList();
      // I1: Count expected doses per medicine based on actual reminder times count.
      final totalDoses = recentMeds.fold<int>(0, (sum, m) => sum + m.reminderTimes.length * 7);
      final takenDoses = recentMeds.fold<int>(0, (sum, m) {
        return sum + m.loggedDoses.where((d) => d.isAfter(sevenDaysAgo)).length;
      });
      final adherence = totalDoses > 0 ? (takenDoses / totalDoses * 100) : 100.0;

      final recentMeals = meals;
      final avgCalories = recentMeals.isEmpty
          ? 0
          : recentMeals.fold<int>(0, (s, m) => s + (m.calories ?? 0)) ~/
              recentMeals.length;

      final recentActivity = activities.where((a) => a.loggedAt.isAfter(sevenDaysAgo)).toList();
      final totalSteps = recentActivity.fold<int>(0, (s, a) => s + (a.steps ?? 0));
      final activeDays = recentActivity.map((a) => '${a.loggedAt.year}-${a.loggedAt.month}-${a.loggedAt.day}').toSet().length;
      final avgSteps = activeDays > 0 ? totalSteps ~/ activeDays : 0;

      final insights = await _service.generateInsights(
        medAdherencePct: adherence,
        avgCalories: avgCalories,
        avgSteps: avgSteps,
        conditions: patient?.conditions ?? [],
        bloodType: patient?.bloodType,
        pendingAppointments: pendingAppointments,
        medStreak: medStreak,
        activityStreak: activityStreak,
      );
      state = AsyncValue.data(insights);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final insightsNotifierProvider =
    StateNotifierProvider.autoDispose<InsightsNotifier, AsyncValue<List<HealthInsight>>>((ref) {
  return InsightsNotifier(ref.watch(aiInsightsServiceProvider));
});
