import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../activity/domain/entities/activity_entity.dart';
import '../../../medication/domain/entities/medication_log_entity.dart';
import '../../../medication/data/repositories/medication_repository_impl.dart';

part 'dashboard_provider.g.dart';

// ── Step counter ──────────────────────────────────────────────────────────────

@riverpod
class StepCounter extends _$StepCounter {
  @override
  int build() => 6842;

  void add(int count) {
    state = state + count;
    // TODO: sync to Health platform via `health` package
  }
}

// ── Today's adherence summary ─────────────────────────────────────────────────

@riverpod
class TodayAdherence extends _$TodayAdherence {
  @override
  AsyncValue<({int total, int completed, double pct})> build() {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || !user.isLoggedIn) {
      return const AsyncData((total: 0, completed: 0, pct: 0));
    }

    final logsStream = ref.watch(todayLogsStreamProvider(user.id));
    return logsStream.when(
      data: (logs) {
        final total = logs.length;
        final done  = logs.where((l) => l.isCompleted).length;
        return AsyncData((total: total, completed: done, pct: total > 0 ? done / total : 0));
      },
      loading: () => const AsyncLoading(),
      error:   (e, s) => AsyncError(e, s),
    );
  }
}

// ── Today medication logs stream ──────────────────────────────────────────────

@riverpod
Stream<List<MedicationLogEntity>> todayLogsStream(TodayLogsStreamRef ref, String patientId) {
  final repo = MedicationRepositoryImpl(Supabase.instance.client);
  return repo.watchTodayLogs(patientId);
}

// ── Mock: 7-day activity data ─────────────────────────────────────────────────

@riverpod
List<ActivityEntity> weeklyActivity(WeeklyActivityRef ref) {
  final now = DateTime.now();
  const mockSteps = [7200, 9500, 6800, 10200, 8100, 4500, 6842];
  return List.generate(7, (i) => ActivityEntity(
    id: 'act_$i', patientId: 'current',
    date: now.subtract(Duration(days: 6 - i)),
    steps: mockSteps[i], stepGoal: AppConstants.defaultDailyStepGoal,
    heartRateBpm: 68 + i * 2,
    bloodGlucose: 5.2 + i * 0.1,
    bloodPressureSys: 118 + i,
    bloodPressureDia: 78 + i,
  ));
}
