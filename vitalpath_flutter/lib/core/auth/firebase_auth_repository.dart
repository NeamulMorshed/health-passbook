import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_user.dart';
import '../constants/app_constants.dart';
import 'auth_repository.dart';

/// Firebase implementation of [AuthRepository].
///
/// All Pigeon-layer calls to firebase_auth are confined here.  The v5
/// firebase_auth stack ships firebase_auth_platform_interface 8.x with
/// corrected Pigeon codec generation — no type-cast patches needed.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId:
                  '768599207887-rq61f6d4p8ft9grjvto50fl0r284aicq.apps.googleusercontent.com',
            );

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  // ── AuthRepository ───────────────────────────────────────────────────────

  @override
  Stream<String?> get uidStream =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Clear any stale GMS session so retries always start fresh.
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) return const AuthCancelled();

      final gAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      String uid;
      try {
        final uc = await _auth.signInWithCredential(credential);
        uid = uc.user!.uid;
      } on FirebaseAuthException {
        // Some plugin versions emit FirebaseAuthException even on success;
        // if currentUser is populated the sign-in worked.
        if (_auth.currentUser == null) rethrow;
        uid = _auth.currentUser!.uid;
      }

      return getUserState(uid);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_codeToMessage(e.code), cause: e);
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      final detail = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

      // User dismissed the account picker.
      if (code == 'sign_in_canceled' ||
          detail.contains('12501') ||
          detail.contains('sign_in_cancelled')) {
        return const AuthCancelled();
      }

      // ApiException: 7 = GMS cannot find a signed-in Google account on the
      // device. On an Android Studio emulator open the emulator's Settings →
      // Accounts → Add account → Google and sign in, then retry.
      if (detail.contains('apiexception: 7') ||
          detail.contains('network_error')) {
        return const AuthFailure(
          'No Google account found on this device.\n\n'
          'If you are using an Android emulator:\n'
          '1. Open the emulator Settings\n'
          '2. Go to Accounts → Add account → Google\n'
          '3. Sign in with your Gmail\n'
          '4. Return to VitalPath and try again.',
        );
      }

      // ApiException: 10 = SHA-1 fingerprint or package name mismatch.
      if (detail.contains('apiexception: 10') ||
          detail.contains('developer_error')) {
        return const AuthFailure(
          'Google Sign-In configuration error. '
          'Check that the app SHA-1 is registered in Firebase Console.',
        );
      }

      return const AuthFailure('Sign-in failed. Please try again.');
    } catch (e) {
      return AuthFailure('Sign-in failed. Please try again.', cause: e);
    }
  }

  @override
  Future<AuthResult> getUserState(String uid) async {
    try {
      final doc =
          await _db.collection(AppConstants.colUsers).doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        // No profile yet — caller must complete onboarding.
        final fbUser = _auth.currentUser;
        return AuthNewUser(
          uid: uid,
          email: fbUser?.email,
          displayName: fbUser?.displayName,
          photoUrl: fbUser?.photoURL,
        );
      }
      return AuthSuccess(AppUser.fromMap(doc.data()!, uid));
    } catch (e) {
      return AuthFailure('Could not load profile. Please try again.', cause: e);
    }
  }

  @override
  Future<void> createProfile(AppUser user) async {
    // Atomic batch: user doc + role-specific doc written together.
    final batch = _db.batch();

    batch.set(
      _db.collection(AppConstants.colUsers).doc(user.uid),
      user.toMap(),
    );

    if (user.userType == UserType.doctor) {
      batch.set(
        _db.collection(AppConstants.colDoctors).doc(user.uid),
        {
          'name': user.name,
          'phone': user.phone,
          'photoUrl': user.photoUrl,
          'isVerified': false,
          'rating': 0.0,
          'reviewCount': 0,
        },
      );
    } else if (user.userType == UserType.patient) {
      batch.set(
        _db.collection(AppConstants.colPatients).doc(user.uid),
        {
          'name': user.name,
          'phone': user.phone,
          'conditions': <String>[],
        },
      );
    }
    // caregiver: only the users/{uid} doc is created — no patients/ or doctors/ sub-doc

    await batch.commit();
  }

  @override
  Future<void> markOnboardingComplete(String uid) async {
    await _db
        .collection(AppConstants.colUsers)
        .doc(uid)
        .update({'onboardingComplete': true});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserType);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // Delete Firestore docs first while auth is still valid.
    await Future.wait([
      _db.collection(AppConstants.colUsers).doc(uid).delete(),
      _db.collection(AppConstants.colPatients).doc(uid).delete(),
    ]);

    // Delete the Firebase Auth account.
    await user.delete();

    // Clear local state.
    await _googleSignIn.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _codeToMessage(String code) => switch (code) {
        'account-exists-with-different-credential' =>
          'This email is linked to a different sign-in method.',
        'invalid-credential' =>
          'Sign-in credentials are invalid or expired.',
        'network-request-failed' =>
          'No internet connection. Please try again.',
        'user-disabled' =>
          'This account has been disabled. Contact support.',
        'cancelled-popup-request' ||
        'popup-closed-by-user' =>
          'Sign-in was cancelled.',
        _ => 'Sign-in failed ($code). Please try again.',
      };
}
