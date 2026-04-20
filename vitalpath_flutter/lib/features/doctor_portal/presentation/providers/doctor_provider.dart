import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/patient_summary_entity.dart';
import '../../data/repositories/doctor_repository_impl.dart';

part 'doctor_provider.g.dart';

final doctorRepositoryProvider = Provider(
  (ref) => DoctorRepositoryImpl(Supabase.instance.client),
);

// ── Patient Roster ─────────────────────────────────────────────────────────────

@riverpod
class PatientRoster extends _$PatientRoster {
  @override
  Future<List<PatientSummaryEntity>> build() async {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null || !user.isDoctor) return _mockRoster();

    final result = await ref.watch(doctorRepositoryProvider).getPatientRoster(user.id);
    return result.fold((f) => throw Exception(f.message), (r) => r);
  }

  List<PatientSummaryEntity> _mockRoster() => [
    PatientSummaryEntity(
      id: 'p1', name: 'Sarah Johnson', primaryCondition: 'Type 2 Diabetes',
      adherenceRate: 0.85,
      weeklyDots: [true, true, true, false, true, true, true],
      activePrescriptions: 3, pendingPrescriptions: 1,
      riskLevel: 'low', isConnected: true,
      lastSyncAt: DateTime.now().subtract(const Duration(hours: 2)),
      dateOfBirth: DateTime(1988, 3, 15), gender: 'F',
    ),
    PatientSummaryEntity(
      id: 'p2', name: 'Marcus Chen', primaryCondition: 'Hypertension',
      adherenceRate: 0.62,
      weeklyDots: [true, false, true, false, false, true, false],
      activePrescriptions: 2, pendingPrescriptions: 0,
      riskLevel: 'medium',
      lastSyncAt: DateTime.now().subtract(const Duration(days: 1)),
      dateOfBirth: DateTime(1975, 8, 22), gender: 'M',
    ),
    PatientSummaryEntity(
      id: 'p3', name: 'Priya Sharma', primaryCondition: 'Asthma',
      adherenceRate: 0.94,
      weeklyDots: [true, true, true, true, true, true, true],
      activePrescriptions: 2, pendingPrescriptions: 0,
      riskLevel: 'low', isConnected: false,
      lastSyncAt: DateTime.now().subtract(const Duration(hours: 5)),
      dateOfBirth: DateTime(1995, 11, 8), gender: 'F',
    ),
    PatientSummaryEntity(
      id: 'p4', name: 'James Wright', primaryCondition: 'Heart Disease',
      adherenceRate: 0.48,
      weeklyDots: [false, true, false, false, true, false, false],
      activePrescriptions: 5, pendingPrescriptions: 2,
      riskLevel: 'high',
      lastSyncAt: DateTime.now().subtract(const Duration(days: 3)),
      dateOfBirth: DateTime(1960, 5, 30), gender: 'M',
    ),
  ];

  String _activeFilter = 'All';

  void filterBy(String filter) {
    _activeFilter = filter;
    ref.invalidateSelf();
  }
}

// ── Sync Session ───────────────────────────────────────────────────────────────

@riverpod
class SyncSession extends _$SyncSession {
  @override
  SyncSessionEntity build() {
    return _generateSession();
  }

  SyncSessionEntity _generateSession() {
    final code = (100000 + Random().nextInt(900000)).toString();
    return SyncSessionEntity(
      code: code,
      expiresAt: DateTime.now().add(const Duration(seconds: AppConstants.syncCodeValiditySecs)),
      doctorId: 'current_doctor',
    );
  }

  void regenerate() { state = _generateSession(); }

  void markConnected(String patientId) {
    state = SyncSessionEntity(
      code: state.code,
      expiresAt: state.expiresAt,
      doctorId: state.doctorId,
      patientId: patientId,
      isConnected: true,
    );
  }
}

// ── Selected patient ───────────────────────────────────────────────────────────

final selectedPatientProvider = StateProvider<PatientSummaryEntity?>((ref) => null);
