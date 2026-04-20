import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/patient_summary_entity.dart';
import '../../domain/repositories/doctor_repository.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  final SupabaseClient _client;
  DoctorRepositoryImpl(this._client);

  @override
  Future<Either<Failure, List<PatientSummaryEntity>>> getPatientRoster(String doctorId) async {
    try {
      final data = await _client
          .from('doctor_patient_links')
          .select('patient:users(*), adherence_stats(*)')
          .eq('doctor_id', doctorId)
          .eq('is_active', true);
      // Map to PatientSummaryEntity...
      return Right([]);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, PatientSummaryEntity>> getPatientDetail(String patientId) async {
    try {
      final data = await _client.from('users').select().eq('id', patientId).single();
      return Right(PatientSummaryEntity(
        id: data['id'], name: data['name'] ?? 'Unknown',
        adherenceRate: 0.85, weeklyDots: List.filled(7, true),
        activePrescriptions: 3,
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, SyncSessionEntity>> createSyncSession(String doctorId) async {
    try {
      final code = (100000 + Random().nextInt(900000)).toString();
      final expiresAt = DateTime.now().add(const Duration(seconds: AppConstants.syncCodeValiditySecs));
      await _client.from('sync_sessions').insert({
        'code': code, 'doctor_id': doctorId,
        'expires_at': expiresAt.toIso8601String(),
        'is_connected': false,
      });
      return Right(SyncSessionEntity(code: code, expiresAt: expiresAt, doctorId: doctorId));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, SyncSessionEntity>> getSyncSession(String sessionCode) async {
    try {
      final data = await _client.from('sync_sessions').select().eq('code', sessionCode).single();
      return Right(SyncSessionEntity(
        code: data['code'], doctorId: data['doctor_id'],
        expiresAt: DateTime.parse(data['expires_at']),
        patientId: data['patient_id'], isConnected: data['is_connected'] ?? false,
      ));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Stream<SyncSessionEntity?> watchSyncSession(String sessionCode) =>
      _client.from('sync_sessions').stream(primaryKey: ['code'])
          .eq('code', sessionCode)
          .map((data) {
        if (data.isEmpty) return null;
        final row = data.first;
        return SyncSessionEntity(
          code: row['code'], doctorId: row['doctor_id'],
          expiresAt: DateTime.parse(row['expires_at']),
          patientId: row['patient_id'], isConnected: row['is_connected'] ?? false,
        );
      });

  @override
  Future<Either<Failure, Unit>> connectPatientToSync({required String sessionCode, required String patientId}) async {
    try {
      await _client.from('sync_sessions').update({
        'patient_id': patientId, 'is_connected': true,
        'connected_at': DateTime.now().toIso8601String(),
      }).eq('code', sessionCode);
      return const Right(unit);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}
