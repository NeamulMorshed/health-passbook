import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, Unit>> sendOtp(String phone);
  Future<Either<Failure, UserEntity>> verifyOtp({required String phone, required String otp});
  Future<Either<Failure, Unit>> signOut();
  Future<Either<Failure, UserEntity>> getCurrentUser();
  Stream<UserEntity?> get authStateChanges;
}
