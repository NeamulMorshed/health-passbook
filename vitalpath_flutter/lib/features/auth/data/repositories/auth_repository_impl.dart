import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  const AuthRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, Unit>> sendOtp(String phone) async {
    try {
      await _remote.sendOtp(phone);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOtp({required String phone, required String otp}) async {
    try {
      final user = await _remote.verifyOtp(phone: phone, otp: otp);
      return Right(user);
    } on AuthException catch (e) {
      return Left(OtpFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try { await _remote.signOut(); return const Right(unit); }
    catch (e) { return Left(ServerFailure(message: e.toString())); }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _remote.getCurrentUser();
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges => _remote.authStateChanges;
}
