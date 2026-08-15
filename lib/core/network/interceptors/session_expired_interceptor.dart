import 'package:dio/dio.dart';

import '../dio_error_handler.dart';
import '../failures.dart';
import '../token_store.dart';

/// أول ما السيرفر يقول إن التوكن مات (Security.5)، بنمسحه فوراً.
///
/// من غير ده التطبيق يفضل ماسك توكن ميت ويبعته مع كل ريكوست جاي.
/// ولأن الـ TokenStore بيـ notify، الـ router بيرجّع المستخدم للوجين لوحده.
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
