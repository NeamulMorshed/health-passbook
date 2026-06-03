import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/patient_attention.dart';
import '../models/vital_reading.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';
import 'doctor_provider.dart';

// ── Doctor "Needs Attention" aggregator (ADR-014) ─────────────────────────────
// One-shot fetch (not a stream) so we don't open 2N concurrent subscriptions
// when a doctor has many connected patients. autoDispose clears the result when
// the dashboard unmounts; invalidate() on pull-to-refresh triggers a fresh load.

final patientsNeedingAttentionProvider =
    FutureProvider.autoDispose
        .family<List<PatientAttention>, String>((ref, doctorId) async {
  final patients =
      await ref.watch(doctorPatientsStreamProvider(doctorId).future);
  if (patients.isEmpty) return [];

  final db = ref.read(firestoreServiceProvider);
  final results = await Future.wait(
    patients.map((p) => _computeAttention(db, p)),
  );

  final flagged = results
      .whereType<PatientAttention>()
      .where((a) => a.needsAttention)
      .toList()
    ..sort((a, b) => a.compareTo(b));

  return flagged;
});

Future<PatientAttention?> _computeAttention(
    FirestoreService db, PatientProfile patient) async {
  try {
    final meds = await db.getMedicinesOnce(patient.uid);
    final vitals = await db.getVitalsLastNDays(patient.uid, days: 7);

    // ── Adherence ──────────────────────────────────────────────────────────
    double? adherencePct;
    final activeMedsWithReminders =
        meds.where((m) => m.isActive && m.reminderTimes.isNotEmpty).toList();

    if (activeMedsWithReminders.isNotEmpty) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final totalDoses = activeMedsWithReminders.fold<int>(
        0,
        (sum, m) => sum + m.reminderTimes.length * 7,
      );
      final takenDoses = activeMedsWithReminders.fold<int>(
        0,
        (sum, m) =>
            sum + m.loggedDoses.where((d) => d.isAfter(sevenDaysAgo)).length,
      );
      adherencePct =
          totalDoses > 0 ? (takenDoses / totalDoses * 100).clamp(0, 100) : null;
    }

    // ── Abnormal vitals ────────────────────────────────────────────────────
    final abnormal = vitals
        .where((v) => !VitalType.isNormal(v.type, v.value))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    String? mostRecentLabel;
    if (abnormal.isNotEmpty) {
      final r = abnormal.first;
      final val = r.value.truncateToDouble() == r.value
          ? r.value.toInt().toString()
          : r.value.toStringAsFixed(1);
      mostRecentLabel = '${VitalType.labelFor(r.type)} $val ${r.unit}';
    }

    return PatientAttention(
      patientId: patient.uid,
      patientName: patient.name,
      adherencePct: adherencePct,
      abnormalVitalsCount: abnormal.length,
      mostRecentAbnormalLabel: mostRecentLabel,
      mostRecentAbnormalAt:
          abnormal.isNotEmpty ? abnormal.first.recordedAt : null,
    );
  } catch (_) {
    return null;
  }
}
