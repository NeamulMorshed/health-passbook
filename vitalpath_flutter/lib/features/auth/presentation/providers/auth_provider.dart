import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/supabase_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

part 'auth_provider.g.dart';

// ── Infrastructure providers ──────────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => SupabaseAuthDataSource(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authDataSourceProvider)),
);

// ── Auth state stream ─────────────────────────────────────────────────────────

@riverpod
Stream<UserEntity?> authStateStream(AuthStateStreamRef ref) =>
    ref.watch(authRepositoryProvider).authStateChanges;

@riverpod
class AuthState extends _$AuthState {
  @override
  AsyncValue<UserEntity> build() {
    final stream = ref.watch(authStateStreamProvider);
    return stream.when(
      data:    (u) => u != null ? AsyncData(u) : AsyncData(UserEntity.empty()),
      loading: () => const AsyncLoading(),
      error:   (e, s) => AsyncError(e, s),
    );
  }

  bool get isLoggedIn => state.valueOrNull?.isLoggedIn ?? false;

  Future<void> sendOtp(String phone) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).sendOtp(phone);
    state = result.fold(
      (f) => AsyncError(f.message, StackTrace.current),
      (_) => AsyncData(UserEntity.empty()),
    );
  }

  Future<String?> verifyOtp({required String phone, required String otp}) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).verifyOtp(phone: phone, otp: otp);
    return result.fold(
      (f) { state = AsyncError(f.message, StackTrace.current); return f.message; },
      (user) { state = AsyncData(user); return null; },
    );
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = AsyncData(UserEntity.empty());
  }
}

// Convenience alias matching router reference
final authStateProvider = authStateProvider$;
