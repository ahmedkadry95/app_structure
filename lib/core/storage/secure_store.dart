import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// تجريد بسيط فوق التخزين الآمن.
///
/// موجود عشان الـ TokenStore مايبقاش مربوط بمكتبة بعينها — يعني نقدر
/// نختبره من غير plugin، ونبدّل المكتبة بعدين من مكان واحد.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  final FlutterSecureStorage _storage;
  const FlutterSecureStore(this._storage);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// للاختبارات وأي تشغيل من غير platform channels.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}
