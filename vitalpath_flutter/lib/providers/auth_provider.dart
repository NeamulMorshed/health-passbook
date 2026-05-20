import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/auth/auth_repository.dart';
import '../core/auth/firebase_auth_repository.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

// ── New repository layer (used by login_screen, splash_screen) ────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => FirebaseAuthRepository(),
);

final authUidProvider = StreamProvider<String?>(
  (ref) => ref.watch(authRepositoryProvider).uidStream,
);

// ── Firebase raw auth stream (router redirect guard) ─────────────────────

final firebaseAuthStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

// ── Resolved AppUser for the current session ──────────────────────────────
// StreamProvider<AppUser?> stays in loading until the Firebase auth stream
// emits the first value, preventing the perpetual-spinner bug where a
// FutureProvider would immediately return null (uid still null during stream
// startup) and screens would spin forever on the null-data branch.

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).uidStream.asyncMap((uid) async {
    if (uid == null) return null;
    final result = await ref.read(authRepositoryProvider).getUserState(uid);
    return switch (result) {
      AuthSuccess(:final user) => user,
      _ => null,
    };
  });
});

final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

// Bug 1 fix: declared with a placeholder factory; main.dart overrides this with
// the already-initialized instance via ProviderScope.overrides so the same
// object (with its initialized _local plugin and onMessage listener) is shared
// everywhere.
final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);

// true = granted/provisional, false = denied/not-yet-asked.
// Re-evaluated each time the provider is watched (i.e. on screen mount).
final notifPermGrantedProvider = FutureProvider<bool>((ref) {
  return ref.read(notificationServiceProvider).isPermissionGranted();
});

// Bug 2 fix: save the FCM device token to Firestore whenever the signed-in
// user changes, so Cloud Functions can address push notifications to this device.
final fcmTokenSyncProvider = Provider<void>((ref) {
  ref.listen(currentUserProvider, (_, next) {
    next.whenData((user) async {
      if (user == null) return;
      await ref.read(notificationServiceProvider).syncTokenForUser(
        user.uid,
        ref.read(firestoreServiceProvider),
      );
    });
  });
});
