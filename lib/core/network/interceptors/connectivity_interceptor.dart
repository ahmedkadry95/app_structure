import 'package:dio/dio.dart';

import '../network_info.dart';

/// بيقطع الريكوست قبل ما يطلع أصلاً لو مفيش شبكة.
///
/// من غيره الريكوست بيفضل مستني لحد ما الـ timeout يخلص (20 ثانية)
/// وبعدين يفشل — يعني المستخدم بيبص على spinner 20 ثانية عشان يعرف
/// حاجة كنا عارفينها من أول لحظة.
///
/// لازم يكون **أول** interceptor في السلسلة عشان يوفّر شغل اللي بعده.
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
      // true → الـ error interceptors اللي بعده تشتغل عادي
      true,
    );
  }
}
