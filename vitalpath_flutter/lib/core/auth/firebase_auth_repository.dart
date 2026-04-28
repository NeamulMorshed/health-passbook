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
        // firebase_auth emits FirebaseAuthException even on success in some
        // plugin versions; if currentUser is populated the sign-in worked.
        if (_auth.currentUser == null) rethrow;
        uid = _auth.currentUser!.uid;
      }

      return getUserState(uid);
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_codeToMessage(e.code), cause: e);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_failed') {
        final detail = e.message ?? '';
        if (detail.contains('ApiException: 7')) {
          return const AuthFailure(
            'Network error. Check your internet connection and try again.',
          );
        }
        if (detail.contains('ApiException: 10')) {
          return const AuthFailure(
            'Google Sign-In is not configured for this device. '
            'The app\'s SHA-1 fingerprint may not be registered in Firebase Console.',
          );
        }
      }
      return AuthFailure('Sign-in failed: ${e.message}', cause: e);
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
    } else {
      batch.set(
        _db.collection(AppConstants.colPatients).doc(user.uid),
        {
          'name': user.name,
          'phone': user.phone,
          'conditions': <String>[],
        },
      );
    }

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
