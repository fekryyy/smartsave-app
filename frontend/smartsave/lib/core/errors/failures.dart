class Failure {
  final String message;
  final int? statusCode;
  final dynamic errors;

  const Failure({required this.message, this.statusCode, this.errors});

  @override
  String toString() => 'Failure(message: $message, statusCode: $statusCode)';
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode, super.errors});
}

class ConnectionFailure extends Failure {
  const ConnectionFailure({super.message = 'No internet connection', super.statusCode});
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.errors, super.statusCode});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error', super.statusCode});
}

class ConflictFailure extends Failure {
  const ConflictFailure({required super.message, super.statusCode});
}
