import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phone);
  Future<UserModel> verifyOtp({required String phone, required String otp});
  Future<void> signOut();
  Future<UserModel> getCurrentUser();
  Stream<UserModel?> get authStateChanges;
}

class SupabaseAuthDataSource implements AuthRemoteDataSource {
  final SupabaseClient _client;
  SupabaseAuthDataSource(this._client);

  @override
  Future<void> sendOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw AuthException(message: e.message);
    } catch (e) {
      throw AuthException(message: 'Failed to send OTP: $e');
    }
  }

  @override
  Future<UserModel> verifyOtp({required String phone, required String otp}) async {
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      if (response.user == null) throw const AuthException(message: 'Verification failed');

      // Upsert profile in public.users table
      final profile = await _upsertProfile(response.user!);
      return profile;
    } on AuthException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(message: e.message, statusCode: int.tryParse(e.code ?? ''));
    }
  }

  Future<UserModel> _upsertProfile(User user) async {
    final existing = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) return UserModel.fromJson(existing);

    final inserted = await _client.from('users').insert({
      'id':         user.id,
      'phone':      user.phone ?? '',
      'role':       'patient',
      'is_onboarded': false,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return UserModel.fromJson(inserted);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException(message: 'Not authenticated');

    final profile = await _client
        .from('users')
        .select()
        .eq('id', user.id)
        .single();

    return UserModel.fromJson(profile);
  }

  @override
  Stream<UserModel?> get authStateChanges =>
      _client.auth.onAuthStateChange.asyncMap((event) async {
        if (event.session == null) return null;
        try { return await getCurrentUser(); } catch (_) { return null; }
      });
}
