import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../storage/secure_store.dart';

/// مخزن جلسة Prism.
///
/// التوكن محفوظ في الـ secure storage عشان يعيش بعد قفل التطبيق، ومتسحب
/// كمان في الذاكرة لأن الـ AuthInterceptor محتاج يقراه بشكل متزامن.
///
/// ChangeNotifier عشان الـ router يسمع للتغيير ويحوّل بين /login و /home
/// من غير ما حد ينادي عليه يدوي.
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

  /// بتتنادى مرة واحدة وقت بدء التطبيق قبل ما الـ UI يتبني.
  Future<void> restore() async {
    try {
      _token = await _store.read(_tokenKey);
      _nonce = await _store.read(_nonceKey);
    } catch (e, stackTrace) {
      // الـ keychain ممكن يفشل بعد إعادة تسطيب التطبيق — نعتبره مش مسجل دخول
      appLog.error('فشل قراءة الجلسة من الـ secure storage', e, stackTrace);
      _token = null;
      _nonce = null;
    }
    notifyListeners();
  }

  /// بنكتب على الديسك **الأول** وبعدين نعدّل الذاكرة ونـ notify.
  ///
  /// الترتيب ده مقصود: لو الكتابة فشلت، الـ router مايكونش وداه على /home
  /// وهو أصلاً مش هيلاقي جلسة لما التطبيق يفتح تاني.
  Future<void> save({required String token, required String nonce}) async {
    await _store.write(_tokenKey, token);
    await _store.write(_nonceKey, nonce);
    _token = token;
    _nonce = nonce;
    notifyListeners();
  }

  /// نفس المبدأ بالعكس: بنمسح من الديسك الأول.
  ///
  /// لو مسحنا من الذاكرة ونـ notify قبل ما نتأكد إن الديسك اتمسح، وحصل
  /// فشل في الـ keychain، المستخدم يبقى اترمى على شاشة اللوجين والتوكن
  /// اللي هو ملغيه لسه محفوظ — وأول ما يفتح التطبيق تاني يرجع بيه.
  Future<void> clear() async {
    if (_token == null && _nonce == null) return;
    await _store.delete(_tokenKey);
    await _store.delete(_nonceKey);
    _token = null;
    _nonce = null;
    notifyListeners();
  }
}
