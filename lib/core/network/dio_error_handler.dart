import 'package:dio/dio.dart';

import 'failures.dart';
import 'network_info.dart';
import 'prism_error.dart';

/// بيترجم DioException → Failure واضحة.
/// الـ mapping معمول على errorcode بتاع Prism نفسه مش الـ HTTP status بس،
/// لأن الكود أدق (Security.2 = بيانات غلط، Security.5 = توكن بايظ).
Failure handleDioError(DioException e) {
  // إحنا اللي قطعنا الريكوست في الـ ConnectivityInterceptor — مطلعش أصلاً
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
              error.errorMsg,
              statusCode: statusCode,
              error: error,
            ),
        };
      }
      return ServerFailure('حصل خطأ من السيرفر', statusCode: statusCode);

    default:
      return const NetworkFailure();
  }
}
