/// مخزن التوكن — في الذاكرة مؤقتاً.
/// في الإنتاج استبدله بـ flutter_secure_storage عشان يعيش بعد قفل التطبيق.
class TokenStore {
  String? token;
  String? nonce;

  void clear() {
    token = null;
    nonce = null;
  }
}
