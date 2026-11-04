import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;

  const Failure(this.message, {this.code, this.details});

  @override
  List<Object?> get props => [message, code, details];
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    String message = 'Network connection failed. Please check your connectivity.',
    String? code,
  }) : super(message, code: code);
}

class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required String message,
    this.statusCode,
    String? code,
    Map<String, dynamic>? details,
  }) : super(message, code: code, details: details);
}

class AuthFailure extends Failure {
  const AuthFailure({
    String message = 'Authentication failed. Please sign in again.',
    String? code,
  }) : super(message, code: code);
}

class ValidationFailure extends Failure {
  final Map<String, String> fieldErrors;

  const ValidationFailure({
    String message = 'Input validation failed.',
    required this.fieldErrors,
    String? code,
  }) : super(message, code: code, details: fieldErrors);

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    String message = 'Operation timed out. The robot did not respond in time.',
    String? code,
  }) : super(message, code: code);
}

class CacheFailure extends Failure {
  const CacheFailure({
    String message = 'Failed to load cached data.',
    String? code,
  }) : super(message, code: code);
}
