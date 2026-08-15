import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/app_logger.dart';

/// علامة بنعلّم بيها الـ DioException اللي إحنا قطعناها قبل ما تطلع،
/// عشان `handleDioError` يفرّق بين "مفيش نت" و"السيرفر مش راد".
class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException';
}

/// بيقول التطبيق متصل بشبكة ولا لأ، وبيبث أي تغيير في الحالة.
///
/// تحذير مهم: `connectivity_plus` بيقيس **وجود واجهة شبكة** مش وصول
/// حقيقي للإنترنت. يعني واي فاي من غير نت هيتحسب "متصل". هو بيمنع
/// الحالة الشائعة (طيران / مفيش شبكة) بس مش بديل عن معالجة الـ timeout.
class NetworkInfo {
  final Connectivity _connectivity;
  NetworkInfo(this._connectivity);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> get isConnected async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (e, stackTrace) {
      // لو الفحص نفسه فشل، منمنعش الريكوست — نسيبه يجرب
      appLog.error('فشل فحص الاتصال', e, stackTrace);
      return true;
    }
  }

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();
}
