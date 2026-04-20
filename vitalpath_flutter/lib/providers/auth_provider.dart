import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// ─── Services ─────────────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

// ─── Firebase Auth State ───────────────────────────────────────────────────────
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ─── Current AppUser ──────────────────────────────────────────────────────────
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      return ref.watch(authServiceProvider).getUserProfile(user.uid);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ─── OTP State Notifier ───────────────────────────────────────────────────────
class OtpState {
  final String? verificationId;
  final bool isLoading;
  final String? error;
  final bool verified;

  const OtpState({this.verificationId, this.isLoading = false, this.error, this.verified = false});

  OtpState copyWith({String? verificationId, bool? isLoading, String? error, bool? verified}) {
    return OtpState(
      verificationId: verificationId ?? this.verificationId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      verified: verified ?? this.verified,
    );
  }
}

class OtpNotifier extends StateNotifier<OtpState> {
  final AuthService _auth;
  OtpNotifier(this._auth) : super(const OtpState());

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    await _auth.sendOtp(
      phone: phone,
      onAutoVerified: (credential) {
        state = state.copyWith(isLoading: false, verified: true);
      },
      onCodeSent: (verificationId, _) {
        state = state.copyWith(isLoading: false, verificationId: verificationId);
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.message ?? 'Failed to send OTP');
      },
    );
  }

  Future<bool> verifyOtp(String otp) async {
    if (state.verificationId == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _auth.verifyOtp(state.verificationId\!, otp);
      state = state.copyWith(isLoading: false, verified: true);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message ?? 'Invalid OTP');
      return false;
    }
  }

  void reset() => state = const OtpState();
}

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>((ref) {
  return OtpNotifier(ref.watch(authServiceProvider));
});
