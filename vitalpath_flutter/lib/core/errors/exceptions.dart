class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException({required this.message, this.statusCode});
  @override
  String toString() => 'ServerException($statusCode): $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException({this.message = 'Cache error'});
}

class NetworkException implements Exception {
  const NetworkException();
}

class AuthException implements Exception {
  final String message;
  const AuthException({required this.message});
}
