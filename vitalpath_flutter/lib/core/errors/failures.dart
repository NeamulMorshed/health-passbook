import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Failure hierarchy — used with dartz Either<Failure, T>
// ─────────────────────────────────────────────────────────────────────────────

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;
  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection', super.statusCode});
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

class OtpFailure extends Failure {
  const OtpFailure({required super.message, super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Local cache error', super.statusCode});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.statusCode});
}

/// §5.2 — Duplicate dose business rule failure
class DuplicateDoseFailure extends Failure {
  final DateTime lastLoggedAt;
  final int minutesAgo;
  const DuplicateDoseFailure({
    required this.lastLoggedAt,
    required this.minutesAgo,
    super.message = 'Duplicate dose detected',
  });

  @override
  List<Object?> get props => [message, lastLoggedAt, minutesAgo];
}

/// §5.4 — Timezone leap failure
class TimezoneLeapFailure extends Failure {
  final String fromTimezone;
  final String toTimezone;
  final int driftMinutes;
  const TimezoneLeapFailure({
    required this.fromTimezone,
    required this.toTimezone,
    required this.driftMinutes,
    super.message = 'Timezone change detected',
  });
}
