import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../logging/app_logger.dart';

class OfflineException implements Exception {
  const OfflineException();

  @override
  String toString() => 'OfflineException';
}

class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo(this._connectivity);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> get isConnected async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (e, stackTrace) {
      appLog.error('فشل فحص الاتصال', e, stackTrace);
      return true;
    }
  }

  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();
}
