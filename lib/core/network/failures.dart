import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

class OfflineFailure extends Failure {
  const OfflineFailure();
}

class NetworkFailure extends Failure {
  const NetworkFailure();
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure();
}

class ServerFailure extends Failure {
  final String? serverMessage;
  final String? errorCode;
  final int? statusCode;

  const ServerFailure({this.serverMessage, this.errorCode, this.statusCode});

  @override
  List<Object?> get props => [serverMessage, errorCode, statusCode];
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
