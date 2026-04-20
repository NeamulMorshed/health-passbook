import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medication_entity.dart';
import '../../domain/entities/medication_log_entity.dart';
import '../../domain/usecases/log_medication_usecase.dart';
import '../../data/repositories/medication_repository_impl.dart';

part 'medication_provider.g.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final medicationRepositoryProvider = Provider(
  (ref) => MedicationRepositoryImpl(Supabase.instance.client),
);

final logMedicationUseCaseProvider = Provider(
  (ref) => LogMedicationUseCase(ref.watch(medicationRepositoryProvider)),
);

// ── Today's medications ───────────────────────────────────────────────────────

@riverpod
class TodayMedications extends _$TodayMedications {
  @override
  Future<List<MedicationEntity>> build() async {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || !user.isLoggedIn) return [];

    final result = await ref
        .watch(medicationRepositoryProvider)
        .getTodayMedications(user.id);

    return result.fold(
      (f) => throw Exception(f.message),
      (meds) => meds,
    );
  }
}

// ── Log state per medication ──────────────────────────────────────────────────

@riverpod
class MedicationLogState extends _$MedicationLogState {
  MedicationLogEntity? _lastUndoLog;

  @override
  Map<String, String> build() => {};   // medicationId → status

  Future<LogResult> logDose({
    required String medicationId,
    required DateTime scheduledAt,
    bool forceLog = false,
  }) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return LogResult.error('Not authenticated');

    final result = await ref.read(logMedicationUseCaseProvider)(
      medicationId: medicationId,
      patientId:    user.id,
      scheduledAt:  scheduledAt,
      forceLog:     forceLog,
    );

    return result.fold(
      (failure) {
        if (failure is DuplicateDoseFailure) {
          return LogResult.duplicate(
            lastLoggedAt: failure.lastLoggedAt,
            minutesAgo:   failure.minutesAgo,
          );
        }
        return LogResult.error(failure.message);
      },
      (log) {
        _lastUndoLog = log;
        state = { ...state, medicationId: 'completed' };
        return LogResult.success(log);
      },
    );
  }

  Future<void> undoLastLog() async {
    if (_lastUndoLog == null) return;
    final log = _lastUndoLog!;
    await ref.read(medicationRepositoryProvider).undoLastLog(log.id);
    final newState = Map<String, String>.from(state);
    newState.remove(log.medicationId);
    state = newState;
    _lastUndoLog = null;
  }
}

class LogResult {
  final LogResultType type;
  final MedicationLogEntity? log;
  final String? error;
  final DateTime? lastLoggedAt;
  final int? minutesAgo;

  const LogResult._({required this.type, this.log, this.error, this.lastLoggedAt, this.minutesAgo});

  factory LogResult.success(MedicationLogEntity log) => LogResult._(type: LogResultType.success, log: log);
  factory LogResult.duplicate({required DateTime lastLoggedAt, required int minutesAgo}) =>
      LogResult._(type: LogResultType.duplicate, lastLoggedAt: lastLoggedAt, minutesAgo: minutesAgo);
  factory LogResult.error(String msg) => LogResult._(type: LogResultType.error, error: msg);

  bool get isSuccess   => type == LogResultType.success;
  bool get isDuplicate => type == LogResultType.duplicate;
  bool get isError     => type == LogResultType.error;
}

enum LogResultType { success, duplicate, error }
