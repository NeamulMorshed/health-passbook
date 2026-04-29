import '../../models/app_user.dart';

// ── Result type ────────────────────────────────────────────────────────────
// Every auth operation returns one of these sealed variants.  The UI pattern-
// matches on the result; raw exceptions never leak into widget code.

sealed class AuthResult {
  const AuthResult();
}

/// Sign-in succeeded and the user already has a Firestore profile.
final class AuthSuccess extends AuthResult {
  final AppUser user;
  const AuthSuccess(this.user);
}

/// Sign-in succeeded but no Firestore profile exists yet — the user must
/// choose a role (patient / doctor) and complete onboarding.
final class AuthNewUser extends AuthResult {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  const AuthNewUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}

/// The user explicitly dismissed the sign-in dialog — not an error.
final class AuthCancelled extends AuthResult {
  const AuthCancelled();
}

/// Something went wrong.  [message] is safe to show in the UI.
final class AuthFailure extends AuthResult {
  final String message;
  final Object? cause;
  const AuthFailure(this.message, {this.cause});
}

// ── Repository interface ──────────────────────────────────────────────────
// The UI and providers depend on this interface, never on a concrete class.
// To swap Firebase for any other backend (Supabase, custom API, mock) just
// implement this interface and re-bind [authRepositoryProvider].

abstract interface class AuthRepository {
  /// Emits the signed-in UID, or null when signed out.
  Stream<String?> get uidStream;

  /// The currently signed-in UID, synchronously available (null if none).
  String? get currentUid;

  /// Launches the Google sign-in sheet and returns an [AuthResult].
  Future<AuthResult> signInWithGoogle();

  /// Resolves the Firestore profile for [uid].
  /// Returns [AuthSuccess] if a profile exists, [AuthNewUser] if not.
  Future<AuthResult> getUserState(String uid);

  /// Writes a new user document and the role-specific sub-document.
  Future<void> createProfile(AppUser user);

  /// Marks onboarding as complete in Firestore and SharedPreferences.
  Future<void> markOnboardingComplete(String uid);

  /// Signs out of Firebase and Google Sign-In and clears local prefs.
  Future<void> signOut();

  /// Permanently deletes the Firebase Auth account and the Firestore user doc.
  Future<void> deleteAccount();
}
