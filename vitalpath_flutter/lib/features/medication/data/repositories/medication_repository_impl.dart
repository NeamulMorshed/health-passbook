import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/medication_entity.dart';
import '../../domain/entities/medication_log_entity.dart';
import '../../domain/repositories/medication_repository.dart';
import '../models/medication_model.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  final SupabaseClient _client;
  MedicationRepositoryImpl(this._client);

  @override
  Future<Either<Failure, List<MedicationEntity>>> getTodayMedications(String patientId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await _client
          .from('medications')
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true)
          .order('created_at');

      return Right(data.map((j) => MedicationModel.fromJson(j as Map<String, dynamic>)).toList());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<MedicationLogEntity>>> getLogs({
    required String patientId, required DateTime from, required DateTime to,
  }) async {
    try {
      final data = await _client
          .from('medication_logs')
          .select()
          .eq('patient_id', patientId)
          .gte('scheduled_at', from.toIso8601String())
          .lte('scheduled_at', to.toIso8601String())
          .order('scheduled_at');
      return Right(data.map((j) => MedicationLogModel.fromJson(j as Map<String, dynamic>)).toList());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, MedicationLogEntity>> logDose({
    required String medicationId, required String patientId,
    required DateTime scheduledAt, String? source, bool forceLog = false,
  }) async {
    try {
      // Call Supabase Edge Function for server-side duplicate check + audit
      final resp = await _client.functions.invoke('log-dose', body: {
        'medication_id': medicationId,
        'patient_id':    patientId,
        'scheduled_at':  scheduledAt.toIso8601String(),
        'source':        source ?? LogEntrySource.manual,
        'force_log':     forceLog,
      });

      if (resp.status \!= 200) {
        final body = resp.data as Map<String, dynamic>?;
        if (body?['code'] == 'DUPLICATE_DOSE') {
          final lastTime = DateTime.parse(body\!['last_logged_at'] as String);
          return Left(DuplicateDoseFailure(
            lastLoggedAt: lastTime,
            minutesAgo: DateTime.now().difference(lastTime).inMinutes,
          ));
        }
        return Left(ServerFailure(message: body?['error'] as String? ?? 'Log failed'));
      }

      return Right(MedicationLogModel.fromJson(resp.data as Map<String, dynamic>));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> undoLastLog(String logId) async {
    try {
      await _client.from('medication_logs').update({'status': 'undone'}).eq('id', logId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, MedicationEntity>> addPrescription({
    required String patientId, required String name, required String dosage,
    required String frequency, required List<DateTime> scheduledTimes, String? instructions,
  }) async {
    try {
      final inserted = await _client.from('medications').insert({
        'patient_id':      patientId,
        'name':            name,
        'dosage':          dosage,
        'frequency':       frequency,
        'scheduled_times': scheduledTimes.map((t) => t.toIso8601String()).toList(),
        if (instructions \!= null) 'instructions': instructions,
        'is_verified':   true,
        'is_active':     true,
        'created_at':    DateTime.now().toIso8601String(),
      }).select().single();
      return Right(MedicationModel.fromJson(inserted as Map<String, dynamic>));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePrescription(String medicationId) async {
    try {
      await _client.from('medications')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', medicationId);
      return const Right(unit);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }

  @override
  Stream<List<MedicationLogEntity>> watchTodayLogs(String patientId) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end   = DateTime(today.year, today.month, today.day + 1).toIso8601String();
    return _client
        .from('medication_logs')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .map((data) => data
            .where((r) => r['scheduled_at'] >= start && r['scheduled_at'] < end)
            .map((j) => MedicationLogModel.fromJson(j as Map<String, dynamic>))
            .toList());
  }

  @override
  Future<Either<Failure, DateTime?>> getLastLogTime(String medicationId) async {
    try {
      final data = await _client
          .from('medication_logs')
          .select('logged_at')
          .eq('medication_id', medicationId)
          .eq('status', 'completed')
          .order('logged_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null || data['logged_at'] == null) return const Right(null);
      return Right(DateTime.parse(data['logged_at'] as String));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    }
  }
}
