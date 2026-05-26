import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/caregiver_connection.dart';

// ── Stream: caregiver mirror doc ─────────────────────────────────────────────
// Carries permissions + lastNudgeSentAt. Readable by patient and caregiver.
// Used to show the nudge follow-up indicator without querying patient
// notifications (which caregivers cannot read by rule).

typedef _MirrorKey = ({String patientId, String caregiverUid});

final caregiverMirrorProvider =
    StreamProvider.family<Map<String, dynamic>?, _MirrorKey>((ref, key) {
  return _db
      .collection('patients')
      .doc(key.patientId)
      .collection('caregivers')
      .doc(key.caregiverUid)
      .snapshots()
      .map((doc) => doc.data());
});

const _uuid = Uuid();
final _db = FirebaseFirestore.instance;

// ── Stream: patient's shareCircleWithDoctors flag (7b) ───────────────────────
// Default false when missing — doctors only see the family circle if the
// patient opts in. Mirrored in the Firestore rule on caregiver_connections.

final shareCircleWithDoctorsProvider =
    StreamProvider.family<bool, String>((ref, patientUid) {
  return _db
      .collection('users')
      .doc(patientUid)
      .snapshots()
      .map((doc) => (doc.data()?['shareCircleWithDoctors'] as bool?) ?? false);
});

Future<void> setShareCircleWithDoctors(String patientUid, bool value) {
  return _db
      .collection('users')
      .doc(patientUid)
      .update({'shareCircleWithDoctors': value});
}

// ── Stream: caregivers visible to doctor for a patient (7b) ──────────────────
// Returns connected family members for the given patient. Rule-enforced:
// only succeeds if patient.shareCircleWithDoctors == true AND the requesting
// doctor has an active connection to the patient.

final doctorVisibleCaregiversProvider =
    StreamProvider.family<List<CaregiverConnection>, String>(
        (ref, patientId) {
  return _db
      .collection('caregiver_connections')
      .where('patientId', isEqualTo: patientId)
      .where('status', isEqualTo: 'connected')
      .snapshots()
      .map((s) {
    final out = <CaregiverConnection>[];
    for (final d in s.docs) {
      try {
        out.add(CaregiverConnection.fromDoc(d));
      } catch (_) {
        // Defensive: skip malformed docs (ADR-003).
      }
    }
    return out;
  });
});

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
  if (email.isEmpty) return Stream.value([]);
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
  /// Atomically updates both the connection doc and the caregiver mirror doc
  /// so Firestore rules (caregiverCanRead) stay in sync with UI permissions.
  Future<void> updatePermissions({
    required String connectionId,
    required String patientId,
    required String? caregiverUid,
    required CaregiverPermissions permissions,
  }) async {
    state = const AsyncLoading();
    try {
      final batch = _db.batch();
      batch.update(
        _db.collection('caregiver_connections').doc(connectionId),
        {'permissions': permissions.toMap()},
      );
      // Mirror doc only exists once the caregiver has accepted.
      if (caregiverUid != null) {
        batch.update(
          _db
              .collection('patients')
              .doc(patientId)
              .collection('caregivers')
              .doc(caregiverUid),
          {'permissions': permissions.toMap()},
        );
      }
      await batch.commit();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Patient updates notification settings for an existing connection.
  // C2: Added try/catch — surfaces errors via AsyncError state.
  Future<void> updateNotifSettings(
      String connectionId, CaregiverNotifSettings settings) async {
    state = const AsyncLoading();
    try {
      await _db
          .collection('caregiver_connections')
          .doc(connectionId)
          .update({'notifSettings': settings.toMap()});
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Patient removes a caregiver (soft-delete).
  // C2: Added try/catch — surfaces errors via AsyncError state.
  Future<void> remove(String connectionId) async {
    state = const AsyncLoading();
    try {
      await _db
          .collection('caregiver_connections')
          .doc(connectionId)
          .update({'status': 'removed'});
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
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
    required String patientId,
    required String caregiverUid,
    required String caregiverName,
    required CaregiverPermissions permissions,
  }) async {
    state = const AsyncLoading();
    try {
      final batch = _db.batch();
      // Mark connection as connected
      batch.update(
        _db.collection('caregiver_connections').doc(connectionId),
        {
          'caregiverUid': caregiverUid,
          'caregiverName': caregiverName,
          'status': 'connected',
          'connectedAt': Timestamp.now(),
        },
      );
      // Write mirror doc so Firestore rules can verify caregiver access
      // via isCaregiverFor(patientId) without a collection query.
      // Permissions are included so caregiverCanRead() can gate per-section.
      batch.set(
        _db
            .collection('patients')
            .doc(patientId)
            .collection('caregivers')
            .doc(caregiverUid),
        {'connectedAt': Timestamp.now(), 'permissions': permissions.toMap()},
      );
      await batch.commit();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> decline(String connectionId) async {
    state = const AsyncLoading();
    try {
      await _db
          .collection('caregiver_connections')
          .doc(connectionId)
          .update({'status': 'declined'});
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final inviteResponseNotifierProvider =
    StateNotifierProvider<InviteResponseNotifier, AsyncValue<void>>(
        (_) => InviteResponseNotifier());
