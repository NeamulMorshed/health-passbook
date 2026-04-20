import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/medicines_table.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/medicine_entity.dart';

part 'medicine_provider.g.dart';

/// Watch active medicines stream
@riverpod
Stream<List<Medicine>> medicines(Ref ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(appDatabaseProvider).medicineDao.watchActiveMedicines(user.id);
}

/// Add or update a medicine
@riverpod
class MedicineFormNotifier extends _$MedicineFormNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> save({
    required String name,
    required double dosage,
    required String unit,
    required String frequency,
    required List<String> scheduledTimes,
    required DateTime startDate,
    DateTime? endDate,
    required int inventoryCount,
    int refillThreshold = AppConstants.refillThreshold,
    String? notes,
    String? imagePath,
    String colorHex = '#0B6E4F',
    String? existingId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(currentUserProvider)!;
      final db = ref.read(appDatabaseProvider);
      final id = existingId ?? const Uuid().v4();
      final now = DateTime.now();

      // SRS §4.1 Validation: end date must not be before start date
      if (endDate != null && endDate.isBefore(startDate)) {
        throw Exception('End date cannot be before start date.');
      }

      final companion = MedicinesCompanion.insert(
        id: id,
        userId: user.id,
        name: name,
        unit: unit,
        dosage: dosage,
        frequency: frequency,
        scheduledTimes: jsonEncode(scheduledTimes),
        startDate: startDate,
        endDate: Value(endDate),
        inventoryCount: Value(inventoryCount),
        refillThreshold: Value(refillThreshold),
        imagePath: Value(imagePath),
        notes: Value(notes),
        colorHex: Value(colorHex),
        updatedAt: Value(now),
      );

      await db.medicineDao.insertMedicine(companion);

      // Schedule notifications for each dose time
      final notifSvc = ref.read(notificationServiceProvider);
      for (var i = 0; i < scheduledTimes.length; i++) {
        final parts = scheduledTimes[i].split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 8;
          final minute = int.tryParse(parts[1]) ?? 0;
          final tz = _buildTZDateTime(hour, minute);
          await notifSvc.scheduleMedicineReminder(
            notificationId: id.hashCode.abs() % 8999 + i,
            medicineName: name,
            medicineId: id,
            dosage: dosage,
            unit: unit,
            scheduledTime: tz,
          );
        }
      }

      // Enqueue for cloud sync
      await ref.read(syncServiceProvider).enqueue(
        entityType: 'medicine',
        entityId: id,
        operation: existingId == null ? 'create' : 'update',
        payload: {
          'id': id,
          'user_id': user.id,
          'name': name,
          'unit': unit,
          'dosage': dosage,
          'frequency': frequency,
          'scheduled_times': jsonEncode(scheduledTimes),
          'start_date': startDate.toIso8601String(),
          'end_date': endDate?.toIso8601String(),
          'inventory_count': inventoryCount,
          'refill_threshold': refillThreshold,
          'notes': notes,
          'color_hex': colorHex,
        },
        originalTimestamp: now,
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> delete(String medicineId) async {
    final db = ref.read(appDatabaseProvider);
    await db.medicineDao.deactivateMedicine(medicineId);
  }
}

/// Log a medicine dose action (SRS §3.1, §5.2)
@riverpod
class MedicineLogNotifier extends _$MedicineLogNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> logDose({
    required String medicineId,
    required String medicineName,
    required String action, // 'taken' | 'skipped' | 'snoozed'
    required DateTime scheduledAt,
    String? notes,
  }) async {
    state = const AsyncValue.loading();

    try {
      final user = ref.read(currentUserProvider)!;
      final db = ref.read(appDatabaseProvider);
      final haptics = ref.read(hapticServiceProvider);
      final now = DateTime.now();

      // ── SRS §5.2 — Duplicate Log Detection ──────────────────
      if (action == 'taken') {
        final windowStart = now.subtract(
          Duration(minutes: AppConstants.duplicateLogWindowMinutes),
        );
        final recentLog = await db.medicineDao.findRecentLog(
          medicineId: medicineId,
          since: windowStart,
        );

        if (recentLog != null) {
          // Show overdose warning BEFORE logging
          await ref
              .read(notificationServiceProvider)
              .showDuplicateLogWarning(
                medicineName: medicineName,
                lastLoggedAt: recentLog.loggedAt,
              );
          state = const AsyncValue.data(null);
          return; // Abort logging
        }
      }

      // ── Haptic FIRST — before UI update (Antigravity — Tech Blueprint §3)
      await haptics.medicineImpact();

      // ── Local write (offline-first — SRS §5.1)
      final logId = const Uuid().v4();
      await db.medicineDao.insertMedicineLog(
        MedicineLogsCompanion.insert(
          id: logId,
          medicineId: medicineId,
          userId: user.id,
          action: action,
          scheduledAt: scheduledAt,
          loggedAt: now,
          notes: Value(notes),
          pendingSync: const Value(true),
        ),
      );

      // ── Decrement inventory if taken
      if (action == 'taken') {
        final newCount = await db.medicineDao.decrementInventory(medicineId);

        // ── Refill check (SRS §4.1)
        if (newCount <= AppConstants.refillThreshold) {
          await ref.read(notificationServiceProvider).showRefillReminder(
                medicineName: medicineName,
                medicineId: medicineId,
                remainingCount: newCount,
              );
        }
      }

      // ── Enqueue for cloud sync (preserves original timestamp)
      await ref.read(syncServiceProvider).enqueue(
        entityType: 'medicine_log',
        entityId: logId,
        operation: 'create',
        payload: {
          'id': logId,
          'medicine_id': medicineId,
          'user_id': user.id,
          'action': action,
          'scheduled_at': scheduledAt.toIso8601String(),
          'logged_at': now.toIso8601String(),
          'notes': notes,
        },
        originalTimestamp: now, // SRS §5.1 — original timestamp preserved
      );

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime _buildTZDateTime(int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local, now.year, now.month, now.day, hour, minute,
  );
  if (scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
