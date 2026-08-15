import 'package:dio/dio.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../app_logger.dart';
import '../log_redaction.dart';

/// لوج الشبكة، بس من غير ما يسرّب حاجة.
///
/// `talker_dio_logger` عنده `hiddenHeaders` وبيحل نص المشكلة (التوكن في
/// الهيدر). النص التاني — الباسورد في الـ query string — مش مغطى فيه،
/// عشان كده بنقسم الشغل:
///
/// - الريكوستات العادية → `TalkerDioLogger` عادي
/// - الريكوستات اللي فيها query حساس → بنستبعدها من اللوج التلقائي
///   ونسجّلها إحنا بنسخة منقّاة عن طريق [redactUri]
List<Interceptor> buildNetworkLoggers(AppLogger logger) => [
  _SensitiveRequestLogger(logger),
  TalkerDioLogger(
    talker: logger.talker,
    settings: TalkerDioLoggerSettings(
      printRequestHeaders: true,
      // رد الجلسة من Prism ~100KB — هيغرق الكونسول ويخبّي كل حاجة تانية
      printResponseData: false,
      hiddenHeaders: sensitiveHeaders,
      // أي ريكوست فيه سر في الـ URL بيتسجّل في الـ interceptor اللي فوق.
      // التلاتة لازم يتظبطوا: الـ response بيطبع الـ URI بتاع الريكوست
      // كمان، فلو فلترنا الريكوست بس الباسورد بيتسرّب من الرد.
      requestFilter: (options) => !hasSensitiveQuery(options.uri),
      responseFilter: (response) =>
          !hasSensitiveQuery(response.requestOptions.uri),
      errorFilter: (error) => !hasSensitiveQuery(error.requestOptions.uri),
    ),
  ),
];

/// بيسجّل الريكوستات الحساسة بنسخة آمنة بدل ما تختفي من اللوج تماماً.
class _SensitiveRequestLogger extends Interceptor {
  final AppLogger logger;
  _SensitiveRequestLogger(this.logger);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (hasSensitiveQuery(options.uri)) {
      logger.info('[${options.method}] ${redactUri(options.uri)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler h) {
    final options = response.requestOptions;
    if (hasSensitiveQuery(options.uri)) {
      logger.info(
        '[${options.method}] ${response.statusCode} ${redactUri(options.uri)}',
      );
    }
    h.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (hasSensitiveQuery(options.uri)) {
      logger.error(
        '[${options.method}] ${err.response?.statusCode} '
        '${redactUri(options.uri)}',
        err.error,
      );
    }
    handler.next(err);
  }
}
