import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_config.dart';
import '../../../../core/services/biometric_service.dart';

part 'auth_provider.g.dart';

/// Watches Supabase auth state — drives the router redirect logic.
@riverpod
Stream<User?> authState(Ref ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange
      .map((event) => event.session?.user);
}

/// Current authenticated user (non-null after login)
@riverpod
User? currentUser(Ref ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
}

/// OTP-based phone authentication flow state
enum OtpFlowStatus { idle, sendingOtp, otpSent, verifying, verified, error }

@riverpod
class PhoneAuthNotifier extends _$PhoneAuthNotifier {
  @override
  OtpFlowStatus build() => OtpFlowStatus.idle;

  Future<void> sendOtp(String phoneNumber) async {
    state = OtpFlowStatus.sendingOtp;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signInWithOtp(
        phone: phoneNumber,
      );
      state = OtpFlowStatus.otpSent;
    } catch (e) {
      state = OtpFlowStatus.error;
      rethrow;
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    state = OtpFlowStatus.verifying;
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.verifyOTP(
        phone: phoneNumber,
        token: otp,
        type: OtpType.sms,
      );
      state = OtpFlowStatus.verified;
    } catch (e) {
      state = OtpFlowStatus.error;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await ref.read(supabaseClientProvider).auth.signOut();
    state = OtpFlowStatus.idle;
  }
}

/// Biometric lock state — true = locked, false = unlocked
@riverpod
class BiometricLockNotifier extends _$BiometricLockNotifier {
  @override
  bool build() => false;

  Future<bool> unlock() async {
    final biometrics = ref.read(biometricServiceProvider);
    final success = await biometrics.authenticate(
      reason: 'Unlock VitalPath to access your health data',
    );
    state = !success;
    return success;
  }

  void lock() => state = true;
}
