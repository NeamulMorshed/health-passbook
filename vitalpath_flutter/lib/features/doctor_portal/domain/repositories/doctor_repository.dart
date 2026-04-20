import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/patient_summary_entity.dart';

abstract class DoctorRepository {
  Future<Either<Failure, List<PatientSummaryEntity>>> getPatientRoster(String doctorId);
  Future<Either<Failure, PatientSummaryEntity>> getPatientDetail(String patientId);
  Future<Either<Failure, SyncSessionEntity>> createSyncSession(String doctorId);
  Future<Either<Failure, SyncSessionEntity>> getSyncSession(String sessionCode);
  Stream<SyncSessionEntity?> watchSyncSession(String sessionCode);
  Future<Either<Failure, Unit>> connectPatientToSync({required String sessionCode, required String patientId});
}
