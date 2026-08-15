import 'dart:convert';

import 'package:app_structure/core/network/dio_error_handler.dart';
import 'package:app_structure/core/network/failures.dart';
import 'package:app_structure/core/network/network_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// ثابتة عشان كل الـ DioException تشترك في نفس الـ requestOptions.
final RequestOptions _requestOptions = RequestOptions(
  path: '/security/session',
);

/// بيبني الـ envelope الحقيقي بتاع Prism كـ String (زي ما بيوصل بالظبط):
/// المفتاح `errors` جواه **String** فيه JSON array (double-encoded).
String _prismEnvelopeJson({
  required String errorCode,
  required String errorMsg,
  required int httpCode,
  required String httpMessage,
  String functionName = 'session',
}) {
  final String innerErrors = jsonEncode(<Map<String, dynamic>>[
    <String, dynamic>{
      'date': '2026-07-22T12:58:58.767+03:00',
      'class': 'EPrismCoreException',
      'errorcode': errorCode,
      'errormsg': errorMsg,
      'httpcode': httpCode,
      'httpmessage': httpMessage,
      'functionname': functionName,
      'paramvalues': null,
    },
  ]);

  return jsonEncode(<String, dynamic>{
    'name': null,
    'metatype': null,
    'comment': null,
    'translationid': null,
    'errors': innerErrors,
    'data': <dynamic>[],
  });
}

/// نفس الـ envelope بس بعد ما Dio يعمله decode (الحالة الافتراضية).
Map<String, dynamic> _prismEnvelopeMap({
  required String errorCode,
  required String errorMsg,
  required int httpCode,
  required String httpMessage,
}) =>
    jsonDecode(
          _prismEnvelopeJson(
            errorCode: errorCode,
            errorMsg: errorMsg,
            httpCode: httpCode,
            httpMessage: httpMessage,
          ),
        )
        as Map<String, dynamic>;

DioException _badResponse({required int? statusCode, required dynamic data}) =>
    DioException(
      requestOptions: _requestOptions,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: _requestOptions,
        statusCode: statusCode,
        data: data,
      ),
    );

DioException _ofType(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: _requestOptions, type: type, error: error);

void main() {
  group('handleDioError — OfflineException', () {
    test('OfflineException in err.error maps to OfflineFailure', () {
      final Failure failure = handleDioError(
        _ofType(DioExceptionType.unknown, error: const OfflineException()),
      );

      expect(failure, isA<OfflineFailure>());
      expect(failure, const OfflineFailure());
    });

    test('OfflineException wins over every DioExceptionType', () {
      for (final DioExceptionType type in DioExceptionType.values) {
        expect(
          handleDioError(_ofType(type, error: const OfflineException())),
          isA<OfflineFailure>(),
          reason: 'type $type with OfflineException must be OfflineFailure',
        );
      }
    });

    test(
      'OfflineException wins even when a parseable 401 body is attached',
      () {
        final DioException e = DioException(
          requestOptions: _requestOptions,
          type: DioExceptionType.badResponse,
          error: const OfflineException(),
          response: Response<dynamic>(
            requestOptions: _requestOptions,
            statusCode: 401,
            data: _prismEnvelopeMap(
              errorCode: 'Security.2',
              errorMsg: 'Invalid username or password.',
              httpCode: 401,
              httpMessage: '401 - Unauthorized',
            ),
          ),
        );

        expect(handleDioError(e), isA<OfflineFailure>());
        expect(handleDioError(e), isNot(isA<InvalidCredentialsFailure>()));
      },
    );

    test('a plain SocketException-ish error is NOT treated as offline', () {
      final Failure failure = handleDioError(
        _ofType(DioExceptionType.connectionError, error: Exception('socket')),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure, isNot(isA<OfflineFailure>()));
    });
  });

  group('handleDioError — transport failures map to NetworkFailure', () {
    const List<DioExceptionType> networkTypes = <DioExceptionType>[
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.connectionError,
    ];

    for (final DioExceptionType type in networkTypes) {
      test('$type maps to NetworkFailure', () {
        final Failure failure = handleDioError(_ofType(type));

        expect(failure, isA<NetworkFailure>());
        expect(failure, const NetworkFailure());
        expect(failure, isNot(isA<ServerFailure>()));
        expect(failure, isNot(isA<OfflineFailure>()));
      });
    }
  });

  group('handleDioError — cancel / badCertificate / unknown', () {
    const List<DioExceptionType> fallbackTypes = <DioExceptionType>[
      DioExceptionType.cancel,
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
    ];

    for (final DioExceptionType type in fallbackTypes) {
      test('$type maps to NetworkFailure', () {
        expect(handleDioError(_ofType(type)), const NetworkFailure());
      });
    }

    test('every non-badResponse type resolves to NetworkFailure', () {
      final Iterable<DioExceptionType> nonBadResponse = DioExceptionType.values
          .where((DioExceptionType t) => t != DioExceptionType.badResponse);

      for (final DioExceptionType type in nonBadResponse) {
        expect(
          handleDioError(_ofType(type)),
          isA<NetworkFailure>(),
          reason: '$type should fall through to NetworkFailure',
        );
      }
    });
  });

  group('handleDioError — badResponse with a Prism error envelope', () {
    test('401 + Security.2 maps to InvalidCredentialsFailure', () {
      final Failure failure = handleDioError(
        _badResponse(
          statusCode: 401,
          data: _prismEnvelopeMap(
            errorCode: 'Security.2',
            errorMsg: 'Authorization failed: Invalid username or password.',
            httpCode: 401,
            httpMessage: '401 - Unauthorized',
          ),
        ),
      );

      expect(failure, isA<InvalidCredentialsFailure>());
      expect(failure, const InvalidCredentialsFailure());
      expect(failure, isNot(isA<ServerFailure>()));
    });

    test('403 + Security.5 maps to UnauthorizedFailure', () {
      final Failure failure = handleDioError(
        _badResponse(
          statusCode: 403,
          data: _prismEnvelopeMap(
            errorCode: 'Security.5',
            errorMsg: 'Authorization failed: Invalid Auth token.',
            httpCode: 403,
            httpMessage: '403 - Forbidden',
          ),
        ),
      );

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure, const UnauthorizedFailure());
    });

    test('body still parses when it arrives as a raw JSON String', () {
      final Failure failure = handleDioError(
        _badResponse(
          statusCode: 403,
          data: _prismEnvelopeJson(
            errorCode: 'Security.5',
            errorMsg: 'Authorization failed: Invalid Auth token.',
            httpCode: 403,
            httpMessage: '403 - Forbidden',
          ),
        ),
      );

      expect(failure, isA<UnauthorizedFailure>());
    });

    test('mapping keys off errorcode, not the HTTP status', () {
      // Security.2 served with a 500 → still bad credentials.
      expect(
        handleDioError(
          _badResponse(
            statusCode: 500,
            data: _prismEnvelopeMap(
              errorCode: 'Security.2',
              errorMsg: 'Invalid username or password.',
              httpCode: 500,
              httpMessage: '500 - Internal Server Error',
            ),
          ),
        ),
        isA<InvalidCredentialsFailure>(),
      );

      // A 403 that is not Security.5 → generic ServerFailure, not Unauthorized.
      final Failure failure = handleDioError(
        _badResponse(
          statusCode: 403,
          data: _prismEnvelopeMap(
            errorCode: 'Security.9',
            errorMsg: 'Store is not assigned to this user.',
            httpCode: 403,
            httpMessage: '403 - Forbidden',
          ),
        ),
      );

      expect(failure, isA<ServerFailure>());
      expect(failure, isNot(isA<UnauthorizedFailure>()));
      expect(
        failure,
        const ServerFailure(
          serverMessage: 'Store is not assigned to this user.',
          errorCode: 'Security.9',
          statusCode: 403,
        ),
      );
    });

    test('500 + unknown errorcode carries message, code and status', () {
      final Failure failure = handleDioError(
        _badResponse(
          statusCode: 500,
          data: _prismEnvelopeMap(
            errorCode: 'Sales.17',
            errorMsg: 'Document is locked by another user.',
            httpCode: 500,
            httpMessage: '500 - Internal Server Error',
          ),
        ),
      );

      expect(failure, isA<ServerFailure>());

      final ServerFailure server = failure as ServerFailure;
      expect(server.serverMessage, 'Document is locked by another user.');
      expect(server.errorCode, 'Sales.17');
      expect(server.statusCode, 500);

      // Equatable equality on all three fields.
      expect(
        server,
        const ServerFailure(
          serverMessage: 'Document is locked by another user.',
          errorCode: 'Sales.17',
          statusCode: 500,
        ),
      );
      expect(
        server,
        isNot(
          const ServerFailure(
            serverMessage: 'Document is locked by another user.',
            errorCode: 'Sales.17',
            statusCode: 503,
          ),
        ),
      );
    });

    test('only the first error in the envelope is used', () {
      final String body = jsonEncode(<String, dynamic>{
        'errors': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'errorcode': 'Sales.1',
            'errormsg': 'first',
            'httpcode': 500,
          },
          <String, dynamic>{
            'errorcode': 'Security.5',
            'errormsg': 'second',
            'httpcode': 403,
          },
        ]),
        'data': <dynamic>[],
      });

      final Failure failure = handleDioError(
        _badResponse(statusCode: 500, data: body),
      );

      expect(failure, isA<ServerFailure>());
      expect(
        failure,
        const ServerFailure(
          serverMessage: 'first',
          errorCode: 'Sales.1',
          statusCode: 500,
        ),
      );
    });

    test(
      'errors delivered as a real List (not double-encoded) still parse',
      () {
        final Map<String, dynamic> body = <String, dynamic>{
          'errors': <Map<String, dynamic>>[
            <String, dynamic>{
              'errorcode': 'Security.5',
              'errormsg': 'Authorization failed: Invalid Auth token.',
              'httpcode': 403,
            },
          ],
          'data': <dynamic>[],
        };

        expect(
          handleDioError(_badResponse(statusCode: 403, data: body)),
          isA<UnauthorizedFailure>(),
        );
      },
    );

    test('missing errormsg yields a null serverMessage instead of a canned '
        'message (the generic text belongs to l10n)', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'errors': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{'errorcode': 'Inventory.4'},
        ]),
        'data': <dynamic>[],
      };

      final Failure failure = handleDioError(
        _badResponse(statusCode: 500, data: body),
      );

      expect(failure, isA<ServerFailure>());

      final ServerFailure server = failure as ServerFailure;

      // The envelope WAS parsed — errorCode proves we came through the
      // envelope branch and not the bare HTTP-status fallback.
      expect(server.errorCode, 'Inventory.4');
      expect(server.statusCode, 500);

      // No hardcoded Arabic fallback may be manufactured down here: the
      // network layer stays language-free and the presentation layer
      // substitutes a translated generic message when this is null.
      expect(server.serverMessage, isNull);

      expect(
        server,
        const ServerFailure(errorCode: 'Inventory.4', statusCode: 500),
      );
    });

    test('stringy httpcode no longer costs us the errorcode mapping', () {
      // Delphi can flip a field's type without warning. A strict cast used to
      // throw inside tryParse, the whole envelope was lost, and Security.5
      // degraded into a ServerFailure — meaning the dead token was kept.
      final Map<String, dynamic> body = <String, dynamic>{
        'errors': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'errorcode': 'Security.5',
            'errormsg': 'Authorization failed: Invalid Auth token.',
            'httpcode': '403',
            'date': 20260722,
          },
        ]),
        'data': <dynamic>[],
      };

      final DioException e = _badResponse(statusCode: 403, data: body);

      expect(() => handleDioError(e), returnsNormally);
      expect(handleDioError(e), isA<UnauthorizedFailure>());
      expect(handleDioError(e), isNot(isA<ServerFailure>()));
    });

    test(
      'envelope typed Map<Object?, Object?> at both levels still parses',
      () {
        // Some Dio paths (custom transformers, a body stored then re-read) hand
        // back Object?-keyed maps. The narrower pattern used to skip them and
        // the errorcode was silently dropped.
        final Map<Object?, Object?> body = <Object?, Object?>{
          'errors': <Object?>[
            <Object?, Object?>{
              'errorcode': 'Sales.17',
              'errormsg': 'Document is locked by another user.',
              'httpcode': 500,
            },
          ],
          'data': <Object?>[],
        };

        expect(
          handleDioError(_badResponse(statusCode: 500, data: body)),
          const ServerFailure(
            serverMessage: 'Document is locked by another user.',
            errorCode: 'Sales.17',
            statusCode: 500,
          ),
        );
      },
    );

    test('non-map entries are skipped and the first real error wins', () {
      final Map<String, dynamic> body = <String, dynamic>{
        'errors': jsonEncode(<dynamic>[
          'boom',
          <String, dynamic>{
            'errorcode': 'Security.5',
            'errormsg': 'Authorization failed: Invalid Auth token.',
            'httpcode': 403,
          },
        ]),
        'data': <dynamic>[],
      };

      expect(
        handleDioError(_badResponse(statusCode: 403, data: body)),
        isA<UnauthorizedFailure>(),
      );
    });
  });

  group('handleDioError — badResponse with an unusable body', () {
    test(
      'HTML body yields ServerFailure with null message but real status',
      () {
        const String html =
            '<html><head><title>502 Bad Gateway</title></head>'
            '<body><h1>502 Bad Gateway</h1></body></html>';

        final Failure failure = handleDioError(
          _badResponse(statusCode: 502, data: html),
        );

        expect(failure, isA<ServerFailure>());

        final ServerFailure server = failure as ServerFailure;
        expect(server.serverMessage, isNull);
        expect(server.errorCode, isNull);
        expect(server.statusCode, 502);
        expect(server, const ServerFailure(statusCode: 502));
      },
    );

    test('null body yields ServerFailure with only the status code', () {
      final Failure failure = handleDioError(
        _badResponse(statusCode: 404, data: null),
      );

      expect(failure, const ServerFailure(statusCode: 404));
    });

    test(
      'empty errors array yields ServerFailure with only the status code',
      () {
        final Map<String, dynamic> body = <String, dynamic>{
          'errors': '[]',
          'data': <dynamic>[],
        };

        expect(
          handleDioError(_badResponse(statusCode: 500, data: body)),
          const ServerFailure(statusCode: 500),
        );
      },
    );

    test('envelope without an errors key yields ServerFailure', () {
      final Map<String, dynamic> body = <String, dynamic>{'data': <dynamic>[]};

      expect(
        handleDioError(_badResponse(statusCode: 500, data: body)),
        const ServerFailure(statusCode: 500),
      );
    });

    test('missing status code yields ServerFailure with a null statusCode', () {
      final Failure failure = handleDioError(
        _badResponse(statusCode: null, data: 'not json'),
      );

      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, isNull);
      expect(failure, const ServerFailure());
    });

    test('badResponse with no response object at all yields ServerFailure', () {
      final Failure failure = handleDioError(
        _ofType(DioExceptionType.badResponse),
      );

      expect(failure, isA<ServerFailure>());
      expect(failure, const ServerFailure());
    });

    test(
      'errors holding a JSON object instead of an array degrades safely',
      () {
        // Decodes fine, but it is a Map — the `as List` cast blows up inside
        // tryParse. The handler must swallow that, not rethrow, and must not
        // pick up the Security.5 hiding in the malformed payload.
        final Map<String, dynamic> body = <String, dynamic>{
          'errors': jsonEncode(<String, dynamic>{
            'errorcode': 'Security.5',
            'errormsg': 'Authorization failed: Invalid Auth token.',
          }),
          'data': <dynamic>[],
        };

        final DioException e = _badResponse(statusCode: 500, data: body);

        expect(() => handleDioError(e), returnsNormally);
        expect(handleDioError(e), const ServerFailure(statusCode: 500));
        expect(handleDioError(e), isNot(isA<UnauthorizedFailure>()));
      },
    );

    test(
      'errors holding malformed JSON degrades to the HTTP-status fallback',
      () {
        final Map<String, dynamic> body = <String, dynamic>{
          'errors': '[{"errorcode": "Security.2", ',
          'data': <dynamic>[],
        };

        // 401: nothing parseable, so the status decides — and a 401 must end
        // the session rather than surface as a generic server error.
        final DioException unauthorized = _badResponse(
          statusCode: 401,
          data: body,
        );

        expect(() => handleDioError(unauthorized), returnsNormally);
        expect(handleDioError(unauthorized), const UnauthorizedFailure());

        // The Security.2 buried in the truncated payload must never be read.
        expect(
          handleDioError(unauthorized),
          isNot(isA<InvalidCredentialsFailure>()),
        );

        // Same unusable body on a non-auth status stays a ServerFailure that
        // leaks no message or code from the broken payload.
        final Failure serverSide = handleDioError(
          _badResponse(statusCode: 500, data: body),
        );

        expect(serverSide, const ServerFailure(statusCode: 500));
        expect((serverSide as ServerFailure).serverMessage, isNull);
      },
    );

    test(
      'a top-level JSON array body yields ServerFailure, leaking nothing',
      () {
        // This is the shape Prism uses for login SUCCESS. If it ever arrives on
        // an error status it is not an envelope, so no session data may leak
        // into the Failure.
        final List<dynamic> body = <dynamic>[
          <String, dynamic>{
            'sid': 'sid-value',
            'username': 'someone',
            'token': 'token-value',
            'nonce': 'nonce-value',
          },
        ];

        final Failure failure = handleDioError(
          _badResponse(statusCode: 500, data: body),
        );

        expect(failure, const ServerFailure(statusCode: 500));

        final ServerFailure server = failure as ServerFailure;
        expect(server.serverMessage, isNull);
        expect(server.errorCode, isNull);
      },
    );
  });
}
