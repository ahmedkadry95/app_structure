import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../storage/secure_store.dart';

class TokenStore extends ChangeNotifier {
  static const _tokenKey = 'prism_token';
  static const _nonceKey = 'prism_nonce';

  final SecureStore _store;

  TokenStore(this._store);

  String? _token;
  String? _nonce;

  String? get token => _token;

  String? get nonce => _nonce;

  bool get isLoggedIn => _token != null;

  Future<void> restore() async {
    try {
      _token = await _store.read(_tokenKey);
      _nonce = await _store.read(_nonceKey);
    } catch (e, stackTrace) {
      appLog.error('فشل قراءة الجلسة من الـ secure storage', e, stackTrace);
      _token = null;
      _nonce = null;
    }
    notifyListeners();
  }

  Future<void> save({required String token, required String nonce}) async {
    await _store.write(_tokenKey, token);
    await _store.write(_nonceKey, nonce);
    _token = token;
    _nonce = nonce;
    notifyListeners();
  }

  Future<void> clear() async {
    if (_token == null && _nonce == null) return;
    await _store.delete(_tokenKey);
    await _store.delete(_nonceKey);
    _token = null;
    _nonce = null;
    notifyListeners();
  }
}
