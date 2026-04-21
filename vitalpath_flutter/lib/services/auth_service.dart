import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '768599207887-rq61f6d4p8ft9grjvto50fl0r284aicq.apps.googleusercontent.com',
  );

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Google Sign-In ───────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      final gAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      return _auth.signInWithCredential(credential);
    } catch (e) {
      // google_sign_in_android Pigeon type-cast bug: the sign-in succeeds
      // in Firebase Auth before the exception is thrown. If we already have
      // a current user, treat it as a successful sign-in.
      if (_auth.currentUser != null) return null;
      rethrow;
    }
  }

  // ─── User Profile ─────────────────────────────────────────────────────────

  Future<void> createUserProfile(AppUser user) async {
    await _db.collection(AppConstants.colUsers).doc(user.uid).set(user.toMap());
    // Create role-specific sub-document
    if (user.userType == UserType.doctor) {
      await _db.collection(AppConstants.colDoctors).doc(user.uid).set({
        'name': user.name,
        'phone': user.phone,
        'photoUrl': user.photoUrl,
        'patientIds': [],
        'isVerified': false,
        'rating': 0.0,
        'reviewCount': 0,
      });
    } else {
      await _db.collection(AppConstants.colPatients).doc(user.uid).set({
        'name': user.name,
        'phone': user.phone,
        'conditions': [],
      });
    }
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _db.collection(AppConstants.colUsers).doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update(data);
  }

  Future<void> markOnboardingComplete(String uid) async {
    await _db.collection(AppConstants.colUsers).doc(uid).update({'onboardingComplete': true});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefOnboardingDone, true);
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefUserType);
  }
}
