import 'package:dio/dio.dart';

import '../network_info.dart';

class ConnectivityInterceptor extends Interceptor {
  final NetworkInfo networkInfo;

  ConnectivityInterceptor(this.networkInfo);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (await networkInfo.isConnected) {
      return handler.next(options);
    }

    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const OfflineException(),
      ),
      true,
    );
  }
}
