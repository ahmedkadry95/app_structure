import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../app_logger.dart';
import '../log_redaction.dart';

class PrettyApiLogger extends Interceptor {
  final AppLogger logger;

  final bool showHeaders;

  final bool showResponseBody;

  final int bodyLimit;

  PrettyApiLogger(
    this.logger, {
    this.showHeaders = false,
    this.showResponseBody = false,
    this.bodyLimit = 500,
  });

  static const _startKey = '_log_started_at';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();

    final lines = <String>[_target(options)];
    if (options.uri.hasQuery) lines.add(_query(options.uri));
    if (showHeaders) lines.addAll(_headerLines(options.headers));
    final body = _body(options.data);
    if (body != null) lines.add(body);

    logger.talker.logCustom(
      _HttpLog(
        lines.join('\n'),
        title: 'request',
        logKey: 'http-request',
        color: AnsiPen()..cyan(),
      ),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;

    final lines = <String>[
      '${_target(options)}  ${response.statusCode}${_elapsed(options)}',
    ];
    if (showHeaders) lines.addAll(_headerLines(response.headers.map));
    if (showResponseBody) {
      final body = _body(response.data);
      if (body != null) lines.add(body);
    }

    logger.talker.logCustom(
      _HttpLog(
        lines.join('\n'),
        title: 'response',
        logKey: 'http-response',
        color: AnsiPen()..green(),
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final status = err.response?.statusCode;

    final lines = <String>[
      '${_target(options)}  ${status ?? err.type.name}${_elapsed(options)}',
      _reason(err),
    ];

    logger.talker.logCustom(
      _HttpLog(
        lines.join('\n'),
        title: 'failed',
        logKey: 'http-error',
        color: AnsiPen()..red(),
        level: LogLevel.error,
      ),
    );
    handler.next(err);
  }

  // ── التنسيق ────────────────────────────────────────────────

  String _target(RequestOptions options) {
    final path = options.uri.path.replaceFirst(
      Uri.parse(options.baseUrl).path,
      '',
    );
    return '${options.method.padRight(6)}${path.isEmpty ? '/' : path}';
  }

  String _query(Uri uri) {
    final redacted = redactUri(uri);
    final q = redacted.contains('?') ? redacted.split('?').last : '';
    return '?  ${q.replaceAll('&', '  ')}';
  }

  List<String> _headerLines(Map<String, dynamic> headers) {
    final safe = redactHeaders(headers);
    return [
      for (final e in safe.entries)
        if (e.value != null && '${e.value}'.isNotEmpty)
          '·  ${e.key}: ${e.value}',
    ];
  }

  String? _body(dynamic data) {
    if (data == null) return null;
    try {
      final text = data is String ? data : jsonEncode(data);
      if (text.isEmpty || text == '{}') return null;
      final clipped = text.length > bodyLimit
          ? '${text.substring(0, bodyLimit)}… (+${text.length - bodyLimit})'
          : text;
      return '»  $clipped';
    } catch (_) {
      return '»  ${data.runtimeType}';
    }
  }

  String _elapsed(RequestOptions options) {
    final started = options.extra[_startKey];
    if (started is! DateTime) return '';
    return '  ·  ${DateTime.now().difference(started).inMilliseconds}ms';
  }

  String _reason(DioException err) {
    final data = err.response?.data;
    if (data is Map || data is String) {
      final envelope = _prismErrorLine(data);
      if (envelope != null) return '✖  $envelope';
    }
    return '✖  ${err.type.name}';
  }

  String? _prismErrorLine(dynamic data) {
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (decoded is! Map) return null;
      final raw = decoded['errors'];
      final list = raw is String ? jsonDecode(raw) : raw;
      if (list is! List || list.isEmpty) return null;
      final first = list.first;
      if (first is! Map) return null;
      return '${first['errorcode']}  ${first['errormsg']}';
    } catch (_) {
      return null;
    }
  }
}

class _HttpLog extends TalkerLog {
  _HttpLog(
    super.message, {
    required String title,
    required String logKey,
    required AnsiPen color,
    LogLevel level = LogLevel.info,
  }) : super(title: title, key: logKey, pen: color, logLevel: level);
}
