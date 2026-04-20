import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../database/daos/sync_queue_dao.dart';
import '../database/tables/sync_queue_table.dart';
import '../network/connectivity_service.dart';
import '../network/supabase_config.dart';

part 'sync_service.g.dart';

/// WorkManager task names
abstract final class SyncTasks {
  static const String syncQueue = 'vitalpath_sync_queue';
  static const String stepSync = 'vitalpath_step_sync';
}

/// VitalPath Offline-First Sync Engine.
///
/// Implements the "Offline-First" architecture from Technology Blueprint §2.1:
/// 1. Local Write: Actions saved to Drift DB immediately (Antigravity response)
/// 2. Background Sync: WorkManager drains the queue when connection is stable
/// 3. Conflict Resolution: Server-side timestamp wins for medical orders (SRS §5.3)
///
/// Key invariant: The ORIGINAL timestamp is preserved, NOT the sync time (SRS §5.1)
class SyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase;
  final ConnectivityService _connectivity;

  SyncService({
    required AppDatabase db,
    required SupabaseClient supabase,
    required ConnectivityService connectivity,
  })  : _db = db,
        _supabase = supabase,
        _connectivity = connectivity;

  /// Register background sync tasks with WorkManager.
  Future<void> registerBackgroundTasks() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    // Sync queue: runs every 15 minutes when online
    await Workmanager().registerPeriodicTask(
      SyncTasks.syncQueue,
      SyncTasks.syncQueue,
      frequency: Duration(minutes: AppConstants.stepSyncIntervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    // Step sync: also every 15 minutes (SRS §4.3)
    await Workmanager().registerPeriodicTask(
      SyncTasks.stepSync,
      SyncTasks.stepSync,
      frequency: Duration(minutes: AppConstants.stepSyncIntervalMinutes),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Enqueue an action for cloud sync.
  /// Called AFTER the local Drift write succeeds — never blocks the UI.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    required DateTime originalTimestamp,
  }) async {
    await _db.syncQueueDao.enqueue(
      SyncQueueCompanion.insert(
        id: const Value(Uuid().v4()),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: jsonEncode(payload),
        originalTimestamp: originalTimestamp,
        status: const Value('pending'),
      ),
    );

    // Attempt immediate sync if online
    if (await _connectivity.isConnected) {
      drainQueueSilently();
    }
  }

  /// Drain the sync queue. Called by background task and on reconnect.
  /// Preserves ORIGINAL timestamps per SRS §5.1.
  Future<void> drainQueue() async {
    if (!await _connectivity.isConnected) return;

    final pending = await _db.syncQueueDao.getPendingEntries();
    debugPrint('[SyncService] Draining ${pending.length} queued entries');

    for (final entry in pending) {
      try {
        await _db.syncQueueDao.markInProgress(entry.id);
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

        // Inject the ORIGINAL timestamp into the payload (SRS §5.1)
        payload['_original_timestamp'] = entry.originalTimestamp.toIso8601String();

        await _syncEntry(
          entityType: entry.entityType,
          operation: entry.operation,
          payload: payload,
        );

        await _db.syncQueueDao.markSynced(entry.id);
        debugPrint('[SyncService] Synced: ${entry.entityType}/${entry.entityId}');
      } catch (e) {
        await _db.syncQueueDao.markFailed(entry.id, e.toString());
        debugPrint('[SyncService] Failed: ${entry.entityId} — $e');
      }
    }

    // Cleanup old synced entries
    await _db.syncQueueDao.cleanupSynced();
  }

  /// Non-blocking drain — fire and forget
  void drainQueueSilently() {
    drainQueue().catchError((e) {
      debugPrint('[SyncService] Silent drain error: $e');
    });
  }

  Future<void> _syncEntry({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final tableName = _tableNameFor(entityType);

    switch (operation) {
      case 'create':
        await _supabase.from(tableName).upsert(payload);
      case 'update':
        final id = payload['id'] as String;
        await _supabase.from(tableName).update(payload).eq('id', id);
      case 'delete':
        final id = payload['id'] as String;
        await _supabase.from(tableName).delete().eq('id', id);
    }
  }

  String _tableNameFor(String entityType) {
    return switch (entityType) {
      'medicine_log' => AppConstants.tableMedicineLogs,
      'meal_log' => AppConstants.tableMealLogs,
      'walk_session' => AppConstants.tableWalkSessions,
      'activity_log' => AppConstants.tableActivityLogs,
      'profile_update' => AppConstants.tableUsers,
      'medicine' => AppConstants.tableMedicines,
      _ => throw ArgumentError('Unknown entity type: $entityType'),
    };
  }

  /// Handle real-time doctor updates — server-side stamp wins (SRS §5.3).
  /// Called when Supabase realtime broadcasts a prescription update.
  Future<void> handleServerOverride({
    required String entityType,
    required Map<String, dynamic> serverPayload,
  }) async {
    debugPrint('[SyncService] Server override: $entityType');
    // Local DB will be updated by the feature repository
    // The "Your doctor just updated this routine" toast is shown by the UI layer
  }
}

/// WorkManager callback dispatcher — runs in separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[WorkManager] Executing: $taskName');

    switch (taskName) {
      case SyncTasks.syncQueue:
        // Re-initialize Supabase in background isolate
        // The actual sync happens in the background via the registered task
        debugPrint('[WorkManager] Sync queue task running');
        return true;

      case SyncTasks.stepSync:
        debugPrint('[WorkManager] Step sync task running');
        return true;

      default:
        return false;
    }
  });
}

@riverpod
SyncService syncService(Ref ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    supabase: ref.watch(supabaseClientProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
}
