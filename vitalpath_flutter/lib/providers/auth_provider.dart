import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/auth/auth_repository.dart';
import '../core/auth/firebase_auth_repository.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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
// FutureProvider<AppUser?> — screens watch this with .when(data:loading:error:)

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final uid = ref.watch(authUidProvider).asData?.value;
  if (uid == null) return null;

  final result = await ref.read(authRepositoryProvider).getUserState(uid);
  return switch (result) {
    AuthSuccess(:final user) => user,
    _ => null,
  };
});

// ── Legacy service providers (used by existing screens — do not remove) ───
// Screens that call authServiceProvider.currentUser / getUserProfile / etc.
// continue to work unchanged through these providers.

final authServiceProvider = Provider<AuthService>(
  (_) => AuthService(),
);

final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);
