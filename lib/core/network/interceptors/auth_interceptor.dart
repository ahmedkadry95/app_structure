import 'package:dio/dio.dart';

import '../token_store.dart';

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
