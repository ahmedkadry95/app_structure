import 'package:dio/dio.dart';

import '../dio_error_handler.dart';
import '../failures.dart';
import '../token_store.dart';

class SessionExpiredInterceptor extends Interceptor {
  final TokenStore tokenStore;

  SessionExpiredInterceptor(this.tokenStore);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (handleDioError(err) is UnauthorizedFailure) {
      tokenStore.clear();
    }
    handler.next(err);
  }
}
