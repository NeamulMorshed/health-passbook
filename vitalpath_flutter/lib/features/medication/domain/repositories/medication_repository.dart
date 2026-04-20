import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/medication_entity.dart';
import '../entities/medication_log_entity.dart';

abstract class MedicationRepository {
  /// Fetch today's medications for a patient
  Future<Either<Failure, List<MedicationEntity>>> getTodayMedications(String patientId);

  /// Fetch logs for a date range
  Future<Either<Failure, List<MedicationLogEntity>>> getLogs({
    required String patientId,
    required DateTime from,
    required DateTime to,
  });

  /// Log a dose (may return DuplicateDoseFailure if within 15-min window)
  Future<Either<Failure, MedicationLogEntity>> logDose({
    required String medicationId,
    required String patientId,
    required DateTime scheduledAt,
    String? source,
    bool forceLog = false,       // bypasses §5.2 guard
  });

  /// Undo the last log (within 30 seconds)
  Future<Either<Failure, Unit>> undoLastLog(String logId);

  /// Doctor: add prescription
  Future<Either<Failure, MedicationEntity>> addPrescription({
    required String patientId,
    required String name,
    required String dosage,
    required String frequency,
    required List<DateTime> scheduledTimes,
    String? instructions,
  });

  /// Doctor: delete verified prescription (§4.4 — requires confirmation)
  Future<Either<Failure, Unit>> deletePrescription(String medicationId);

  /// Real-time stream of today's logs
  Stream<List<MedicationLogEntity>> watchTodayLogs(String patientId);

  /// Fetch last log time for a specific medication
  Future<Either<Failure, DateTime?>> getLastLogTime(String medicationId);
}
