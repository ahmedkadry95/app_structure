import 'package:dio/dio.dart';

import '../token_store.dart';

/// بيحقن هيدر `Auth-Session` (ده نظام Prism، مش Bearer) في كل ريكوست
/// ما عدا اللوجين نفسه — من غير ما أي data source يفتكر يعمله بنفسه.
class AuthInterceptor extends Interceptor {
  final TokenStore tokenStore;
  AuthInterceptor(this.tokenStore);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenStore.token;
    final isLogin = options.path.contains('/security/login');

    if (token != null && !isLogin) {
      options.headers['Auth-Session'] = token;
    }
    handler.next(options);
  }
}
