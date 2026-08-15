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

  /// نص جاي من السيرفر زي ما هو. ممكن يكون null — الرسالة العامة المترجمة
  /// مسؤولية الـ presentation مش الطبقة دي.
  final String? errorMsg; // "Authorization failed: Invalid Auth token."
  final int? httpCode; // 403
  final String? httpMessage; // "403 - Forbidden"
  final String? functionName; // "session"
  final String? exceptionClass; // "EPrismCoreException"
  final DateTime? date;

  const PrismError({
    required this.errorCode,
    this.errorMsg,
    this.httpCode,
    this.httpMessage,
    this.functionName,
    this.exceptionClass,
    this.date,
  });

  /// بنقرا بتسامح عن قصد.
  ///
  /// السيرفر Delphi، ونوع أي حقل ممكن يتغير من غير ما حد يقولنا (مثلاً
  /// `"httpcode": "403"` بدل `403`). لو استخدمنا cast صريح، أول حقل نوعه
  /// غلط كان هيرمي TypeError ويضيّع الـ envelope كله — وساعتها بنفقد
  /// الـ errorcode، والمستخدم يشوف "خطأ من السيرفر" بدل "الباسورد غلط".
  factory PrismError.fromJson(Map<String, dynamic> json) => PrismError(
    errorCode: _asString(json['errorcode']) ?? '',
    errorMsg: _asString(json['errormsg']),
    httpCode: _asInt(json['httpcode']),
    httpMessage: _asString(json['httpmessage']),
    functionName: _asString(json['functionname']),
    exceptionClass: _asString(json['class']),
    date: DateTime.tryParse(_asString(json['date']) ?? ''),
  );

  static String? _asString(dynamic v) => switch (v) {
    null => null,
    final String s => s,
    _ => v.toString(),
  };

  static int? _asInt(dynamic v) => switch (v) {
    final int i => i,
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

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
        // Map<Object?, Object?> مش Map<String, dynamic> عشان بعض مسارات Dio
        // (transformers مخصصة، أو body متخزن ومتقرا تاني) بترجّع الشكل ده،
        // والـ pattern الأضيق كان بيسيبها تعدي كأنها مش JSON أصلاً
        final Map<Object?, Object?> m => m,
        final String s when s.isNotEmpty => jsonDecode(s),
        _ => null,
      };
      if (decoded is! Map) return null;

      final raw = decoded['errors'];
      final List<dynamic> list = switch (raw) {
        final String s when s.isNotEmpty => jsonDecode(s) as List<dynamic>,
        final List<dynamic> l => l,
        _ => const <dynamic>[],
      };

      return PrismErrorEnvelope([
        for (final item in list)
          if (item is Map) PrismError.fromJson(item.cast<String, dynamic>()),
      ]);
    } catch (_) {
      return null;
    }
  }
}
