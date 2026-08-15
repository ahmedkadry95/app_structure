import 'dart:convert';

/// خطأ واحد جوه رد Prism.
///
/// السيرفر (Delphi) بيرجع الأخطاء بالشكل ده:
/// ```json
/// {
///   "errors": "[{\"class\":\"EPrismCoreException\",\"errorcode\":\"Security.5\",...}]",
///   "data": []
/// }
/// ```
/// لاحظ إن `errors` مش array — ده **String جواه JSON** (double-encoded).
class PrismError {
  final String errorCode; // "Security.5"
  final String errorMsg; // "Authorization failed: Invalid Auth token."
  final int? httpCode; // 403
  final String? httpMessage; // "403 - Forbidden"
  final String? functionName; // "session"
  final String? exceptionClass; // "EPrismCoreException"
  final DateTime? date;

  const PrismError({
    required this.errorCode,
    required this.errorMsg,
    this.httpCode,
    this.httpMessage,
    this.functionName,
    this.exceptionClass,
    this.date,
  });

  factory PrismError.fromJson(Map<String, dynamic> json) => PrismError(
        errorCode: json['errorcode'] as String? ?? '',
        errorMsg: json['errormsg'] as String? ?? 'حصل خطأ من السيرفر',
        httpCode: json['httpcode'] as int?,
        httpMessage: json['httpmessage'] as String?,
        functionName: json['functionname'] as String?,
        exceptionClass: json['class'] as String?,
        date: DateTime.tryParse(json['date'] as String? ?? ''),
      );

  @override
  String toString() => '[$errorCode] $errorMsg';
}

/// الـ envelope الكامل اللي Prism بيرجعه في حالة الفشل.
class PrismErrorEnvelope {
  final List<PrismError> errors;
  const PrismErrorEnvelope(this.errors);

  PrismError? get first => errors.isNotEmpty ? errors.first : null;

  /// بيتعامل مع كل الأشكال الممكنة:
  /// - body جاي Map جاهز أو String محتاج decode
  /// - errors جايه String (الوضع الحالي) أو List (لو اتصلحت يوم)
  /// - أي حاجة مش متوقعة → null بدل ما يرمي exception جوه معالج الأخطاء
  static PrismErrorEnvelope? tryParse(dynamic body) {
    try {
      final decoded = switch (body) {
        Map<String, dynamic>() => body,
        String() when body.isNotEmpty => jsonDecode(body),
        _ => null,
      };
      if (decoded is! Map<String, dynamic>) return null;

      final raw = decoded['errors'];
      final list = switch (raw) {
        String() when raw.isNotEmpty => jsonDecode(raw) as List,
        List() => raw,
        _ => const [],
      };

      return PrismErrorEnvelope(
        list.whereType<Map<String, dynamic>>().map(PrismError.fromJson).toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
