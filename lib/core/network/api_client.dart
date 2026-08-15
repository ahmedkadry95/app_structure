import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'token_store.dart';

/// الـ Dio الوحيد في المشروع — كل الإعدادات والـ interceptors في مكان واحد.
class ApiClient {
  final Dio dio;

  ApiClient({required TokenStore tokenStore, bool enableLogs = false})
      : dio = Dio(BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            // version=2 مطلوبة من Prism API
            'Accept': 'application/json, text/plain, version=2',
            'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
          },
        )) {
    dio.interceptors.add(AuthInterceptor(tokenStore));

    if (enableLogs) {
      // responseBody متقفل عمداً — رد الجلسة من Prism حجمه ~100KB
      dio.interceptors.add(LogInterceptor(responseBody: false));
    }
  }
}
