import 'dart:convert';

class PrismError {
  final String errorCode; // "Security.5"
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

class PrismErrorEnvelope {
  final List<PrismError> errors;

  const PrismErrorEnvelope(this.errors);

  PrismError? get first => errors.isNotEmpty ? errors.first : null;

  static PrismErrorEnvelope? tryParse(dynamic body) {
    try {
      final decoded = switch (body) {
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
