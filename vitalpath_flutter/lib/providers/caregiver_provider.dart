import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/caregiver_connection.dart';

const _uuid = Uuid();
final _db = FirebaseFirestore.instance;

// ── Stream: all connections for a patient ────────────────────────────────────
// Returns pending + connected (not removed) sorted newest-first.

final patientCaregiverConnectionsProvider =
    StreamProvider.family<List<CaregiverConnection>, String>((ref, patientId) {
  return _db
      .collection('caregiver_connections')
      .where('patientId', isEqualTo: patientId)
      .where('status', whereIn: ['pending', 'connected'])
      .orderBy('invitedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(CaregiverConnection.fromDoc).toList());
});

// ── Stream: all connected patients for a caregiver ───────────────────────────

final caregiverPatientsProvider =
    StreamProvider.family<List<CaregiverConnection>, String>(
        (ref, caregiverUid) {
  return _db
      .collection('caregiver_connections')
      .where('caregiverUid', isEqualTo: caregiverUid)
      .where('status', isEqualTo: 'connected')
      .orderBy('connectedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(CaregiverConnection.fromDoc).toList());
});

// ── Stream: pending invites for a caregiver by email ─────────────────────────
// Used on login/home to detect pending invites addressed to this user.

final pendingInvitesForEmailProvider =
    StreamProvider.family<List<CaregiverConnection>, String>((ref, email) {
  return _db
      .collection('caregiver_connections')
      .where('caregiverEmail', isEqualTo: email.toLowerCase())
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(CaregiverConnection.fromDoc).toList());
});

// ── Notifier: patient manages their caregiver connections ────────────────────

class CaregiverConnectionNotifier extends StateNotifier<AsyncValue<void>> {
  CaregiverConnectionNotifier() : super(const AsyncData(null));

  /// Patient sends an invite.
  Future<String?> invite({
    required String patientId,
    required String patientName,
    required String caregiverEmail,
    required String relationship,
    required CaregiverPermissions permissions,
    required CaregiverNotifSettings notifSettings,
    String? personalMessage,
  }) async {
    state = const AsyncLoading();
    try {
      final id = _uuid.v4();
      await _db.collection('caregiver_connections').doc(id).set(
            CaregiverConnection(
              id: id,
              patientId: patientId,
              patientName: patientName,
              caregiverEmail: caregiverEmail.trim().toLowerCase(),
              relationship: relationship,
              permissions: permissions,
              notifSettings: notifSettings,
              status: 'pending',
              invitedAt: DateTime.now(),
              personalMessage: personalMessage,
            ).toMap(),
          );
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Patient updates permissions for an existing connection.
  Future<void> updatePermissions(
      String connectionId, CaregiverPermissions permissions) async {
    await _db.collection('caregiver_connections').doc(connectionId).update(
        {'permissions': permissions.toMap()});
  }

  /// Patient updates notification settings for an existing connection.
  Future<void> updateNotifSettings(
      String connectionId, CaregiverNotifSettings settings) async {
    await _db.collection('caregiver_connections').doc(connectionId).update(
        {'notifSettings': settings.toMap()});
  }

  /// Patient removes a caregiver (soft-delete).
  Future<void> remove(String connectionId) async {
    await _db
        .collection('caregiver_connections')
        .doc(connectionId)
        .update({'status': 'removed'});
  }
}

final caregiverConnectionNotifierProvider =
    StateNotifierProvider<CaregiverConnectionNotifier, AsyncValue<void>>(
        (_) => CaregiverConnectionNotifier());

// ── Notifier: caregiver accepts or declines an invite ────────────────────────

class InviteResponseNotifier extends StateNotifier<AsyncValue<void>> {
  InviteResponseNotifier() : super(const AsyncData(null));

  Future<void> accept({
    required String connectionId,
    required String caregiverUid,
    required String caregiverName,
  }) async {
    state = const AsyncLoading();
    try {
      await _db.collection('caregiver_connections').doc(connectionId).update({
        'caregiverUid': caregiverUid,
        'caregiverName': caregiverName,
        'status': 'connected',
        'connectedAt': Timestamp.now(),
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> decline(String connectionId) async {
    await _db
        .collection('caregiver_connections')
        .doc(connectionId)
        .update({'status': 'removed'});
  }
}

final inviteResponseNotifierProvider =
    StateNotifierProvider<InviteResponseNotifier, AsyncValue<void>>(
        (_) => InviteResponseNotifier());
