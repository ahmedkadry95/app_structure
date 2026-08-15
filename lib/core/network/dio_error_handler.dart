import 'package:dio/dio.dart';

import 'failures.dart';
import 'network_info.dart';
import 'prism_error.dart';

/// بيترجم DioException → Failure واضحة.
///
/// الـ mapping معمول على errorcode بتاع Prism نفسه مش الـ HTTP status بس،
/// لأن الكود أدق (Security.2 = بيانات غلط، Security.5 = توكن بايظ).
///
/// لاحظ إن الـ PrismError نفسه **مبيعديش** لبرّه — بناخد منه اللي نحتاجه
/// (الرسالة والكود) بس. كده الـ domain مايعرفش إن الباك اند اسمه Prism.
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
            serverMessage: error.errorMsg,
            errorCode: error.errorCode,
            statusCode: statusCode,
          ),
        };
      }

      // مفيش envelope نقرأه — ده بيحصل لما بروكسي أو WAF يرفض الريكوست
      // قبل ما يوصل لـ Prism ويرجّع HTML أو body فاضي. لازم نرجع للـ status
      // نفسه، وإلا التوكن الميت مش هيتمسح والتطبيق هيفضل يبعته.
      return switch (statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        _ => ServerFailure(statusCode: statusCode),
      };

    // cancel / badCertificate / transformTimeout / unknown
    default:
      return const NetworkFailure();
  }
}
