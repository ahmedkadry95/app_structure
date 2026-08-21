import 'package:dio/dio.dart';

import 'failures.dart';
import 'network_info.dart';
import 'prism_error.dart';

Failure handleDioError(DioException e) {
  if (e.error is OfflineException) return const OfflineFailure();

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final error = PrismErrorEnvelope.tryParse(e.response?.data)?.first;

      if (error != null) {
        return switch (error.errorCode) {
          'Security.2' => const InvalidCredentialsFailure(),
          'Security.5' => const UnauthorizedFailure(),
          _ => ServerFailure(
            serverMessage: error.errorMsg,
            errorCode: error.errorCode,
            statusCode: statusCode,
          ),
        };
      }

      return switch (statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        _ => ServerFailure(statusCode: statusCode),
      };

    default:
      return const NetworkFailure();
  }
}
