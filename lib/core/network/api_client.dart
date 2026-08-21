import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../logging/interceptors/redacted_dio_logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/connectivity_interceptor.dart';
import 'interceptors/session_expired_interceptor.dart';
import 'network_info.dart';
import 'token_store.dart';

/// الـ Dio الوحيد في المشروع — كل الإعدادات والـ interceptors في مكان واحد.
class ApiClient {
  final Dio dio;

  ApiClient({
    required TokenStore tokenStore,
    required NetworkInfo networkInfo,
    required AppLogger logger,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: AppConfig.baseUrl,
           connectTimeout: const Duration(seconds: 20),
           receiveTimeout: const Duration(seconds: 20),
           headers: {
             'Accept': 'application/json, text/plain, version=2',
             'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
           },
         ),
       ) {
    dio.interceptors.add(ConnectivityInterceptor(networkInfo));
    dio.interceptors.add(AuthInterceptor(tokenStore));
    dio.interceptors.add(SessionExpiredInterceptor(tokenStore));
    dio.interceptors.addAll(buildNetworkLoggers(logger));
  }
}
