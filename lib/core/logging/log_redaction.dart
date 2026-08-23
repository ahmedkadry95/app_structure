/// إخفاء البيانات الحساسة قبل ما توصل لأي لوج.
///
/// ده مش رفاهية في المشروع ده: Prism بياخد الباسورد في الـ **query string**
/// (`/security/login?usr=...&pwd=...`)، وأي logger افتراضياً بيطبع الـ URI
/// كامل. يعني من غير الملف ده، أول لوجين في الـ debug بيكتب الباسورد
/// في الكونسول — واللي بيتنسخ في تقارير الباجات وبيتصوّر في مشاركة الشاشة.
library;

const String redactedMark = '***';

const Set<String> sensitiveHeaders = {
  'auth-session',
  'auth-session-v9',
  'authorization',
  'auth-nonce',
  'auth-nonce-response',
  'cookie',
  'set-cookie',
  'proxy-authorization',
};

/// مفاتيح query مبنعرضش قيمتها أبداً
const Set<String> sensitiveQueryKeys = {
  'pwd',
  'password',
  'passwd',
  'usr',
  'username',
  'token',
  'nonce',
  'api_key',
  'apikey',
  'secret',
  'access_token',
  'refresh_token',
};

bool isSensitiveHeader(String name) =>
    sensitiveHeaders.contains(name.toLowerCase());

bool isSensitiveQueryKey(String key) =>
    sensitiveQueryKeys.contains(key.toLowerCase());

/// بيرجّع الـ URI بنفس شكله بالظبط، بس القيم الحساسة متبدلة بـ `***`.
///
/// بنسيب أسماء المفاتيح ظاهرة عن قصد — عشان تعرف إن فيه `pwd` اتبعت
/// من غير ما تعرف قيمته.
String redactUri(Uri uri) {
  if (uri.queryParameters.isEmpty) return uri.toString();

  final full = uri.toString();
  final base = full.substring(0, full.indexOf('?'));

  // بنبني الـ query بإيدينا مش بـ Uri.replace، لأن ده بيعمل percent-encode
  // للـ *** وتطلع %2A%2A%2A — اللوج يبقى صح بس مش مقروء
  final query = uri.queryParameters.entries
      .map(
        (e) => isSensitiveQueryKey(e.key)
            ? '${e.key}=$redactedMark'
            : '${e.key}=${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  return '$base?$query';
}

/// نسخة آمنة من الهيدرز للعرض في اللوج.
Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) => {
  for (final entry in headers.entries)
    entry.key: isSensitiveHeader(entry.key) ? redactedMark : entry.value,
};

/// هل الريكوست ده فيه أي حاجة حساسة في الـ query؟
bool hasSensitiveQuery(Uri uri) =>
    uri.queryParameters.keys.any(isSensitiveQueryKey);
