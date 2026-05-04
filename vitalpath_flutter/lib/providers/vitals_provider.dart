import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/vital_reading.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

const _uuid = Uuid();

// ─── Vitals Stream ────────────────────────────────────────────────────────────
final vitalsProvider =
    StreamProvider.family<List<VitalReading>, String>((ref, patientId) {
  return ref.watch(firestoreServiceProvider).watchVitals(patientId);
});

// ─── Vitals Notifier ──────────────────────────────────────────────────────────
class VitalsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirestoreService _db;
  VitalsNotifier(this._db) : super(const AsyncValue.data(null));

  Future<void> add({
    required String patientId,
    required String type,
    required double value,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final reading = VitalReading(
        id: _uuid.v4(),
        patientId: patientId,
        type: type,
        value: value,
        unit: VitalType.unitFor(type),
        recordedAt: DateTime.now(),
        note: note?.isEmpty == true ? null : note,
      );
      await _db.addVitalReading(reading);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> delete(String readingId) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteVitalReading(readingId);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final vitalsNotifierProvider =
    StateNotifierProvider<VitalsNotifier, AsyncValue<void>>((ref) {
  return VitalsNotifier(ref.watch(firestoreServiceProvider));
});
