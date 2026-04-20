import 'package:dartz/dartz.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../entities/medication_log_entity.dart';
import '../repositories/medication_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LogMedicationUseCase — §5.2 Duplicate Detection built in
// ─────────────────────────────────────────────────────────────────────────────

class LogMedicationUseCase {
  final MedicationRepository _repo;
  const LogMedicationUseCase(this._repo);

  Future<Either<Failure, MedicationLogEntity>> call({
    required String medicationId,
    required String patientId,
    required DateTime scheduledAt,
    bool forceLog = false,
  }) async {
    // Check last log time before attempting
    if (\!forceLog) {
      final lastLogResult = await _repo.getLastLogTime(medicationId);
      final maybeFailure = lastLogResult.fold(
        (f) => null,  // ignore cache miss
        (lastTime) {
          if (lastTime == null) return null;
          final minsAgo = DateTime.now().difference(lastTime).inMinutes;
          if (minsAgo < AppConstants.duplicateDoseWindowMins) {
            return DuplicateDoseFailure(
              lastLoggedAt: lastTime,
              minutesAgo: minsAgo,
            );
          }
          return null;
        },
      );
      if (maybeFailure \!= null) return Left(maybeFailure);
    }

    return _repo.logDose(
      medicationId: medicationId,
      patientId: patientId,
      scheduledAt: scheduledAt,
      source: forceLog ? LogEntrySource.force : LogEntrySource.manual,
      forceLog: forceLog,
    );
  }
}
