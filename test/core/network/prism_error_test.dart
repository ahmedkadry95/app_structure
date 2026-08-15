import 'dart:convert';

import 'package:app_structure/core/network/prism_error.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact double-encoded `errors` payload the live Prism backend returns
/// when an Auth-Session token is rejected (HTTP 403).
const String kSecurity5ErrorsString =
    '[{"date":"2026-07-22T12:58:58.767+03:00","class":"EPrismCoreException",'
    '"errorcode":"Security.5",'
    '"errormsg":"Authorization failed: Invalid Auth token.",'
    '"httpcode":403,"httpmessage":"403 - Forbidden",'
    '"functionname":"session","paramvalues":null}]';

/// The live payload for bad credentials on `/security/login` (HTTP 401).
const String kSecurity2ErrorsString =
    '[{"date":"2026-07-22T12:41:03.109+03:00","class":"EPrismCoreException",'
    '"errorcode":"Security.2",'
    '"errormsg":"Login failed: Invalid username or password.",'
    '"httpcode":401,"httpmessage":"401 - Unauthorized",'
    '"functionname":"login","paramvalues":null}]';

/// Two errors in one envelope — Prism does this when it stacks a cause.
const String kTwoErrorsString =
    '[{"date":"2026-07-22T12:58:58.767+03:00","class":"EPrismCoreException",'
    '"errorcode":"Security.5","errormsg":"Authorization failed: Invalid Auth token.",'
    '"httpcode":403,"httpmessage":"403 - Forbidden",'
    '"functionname":"session","paramvalues":null},'
    '{"date":"2026-07-22T12:58:58.900+03:00","class":"EPrismDataException",'
    '"errorcode":"Data.17","errormsg":"Session record not found.",'
    '"httpcode":404,"httpmessage":"404 - Not Found",'
    '"functionname":"session","paramvalues":null}]';

/// The Security.5 failure exactly as it arrives on the wire — written out by
/// hand rather than through [jsonEncode] so a wrong fixture cannot agree with
/// itself. `\\"` in this Dart literal is a single `\"` byte in the payload.
const String kRawWireErrorBody =
    '{"name":null,"metatype":null,"comment":null,"translationid":null,'
    '"errors":"[{\\"date\\":\\"2026-07-22T12:58:58.767+03:00\\",'
    '\\"class\\":\\"EPrismCoreException\\",\\"errorcode\\":\\"Security.5\\",'
    '\\"errormsg\\":\\"Authorization failed: Invalid Auth token.\\",'
    '\\"httpcode\\":403,\\"httpmessage\\":\\"403 - Forbidden\\",'
    '\\"functionname\\":\\"session\\",\\"paramvalues\\":null}]","data":[]}';

/// What nginx hands back when the Delphi backend is down.
const String kHtmlBody =
    '<html>\r\n<head><title>502 Bad Gateway</title></head>\r\n'
    '<body>\r\n<center><h1>502 Bad Gateway</h1></center>\r\n'
    '<hr><center>nginx/1.24.0</center>\r\n</body>\r\n</html>\r\n';

/// The full Prism failure envelope, with [errors] slotted in verbatim.
Map<String, dynamic> envelopeWith(Object? errors) => <String, dynamic>{
  'name': null,
  'metatype': null,
  'comment': null,
  'translationid': null,
  'errors': errors,
  'data': <dynamic>[],
};

void main() {
  group('PrismError.fromJson', () {
    test('maps every lowercase Delphi key onto its typed field', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'date': '2026-07-22T12:58:58.767+03:00',
        'class': 'EPrismCoreException',
        'errorcode': 'Security.5',
        'errormsg': 'Authorization failed: Invalid Auth token.',
        'httpcode': 403,
        'httpmessage': '403 - Forbidden',
        'functionname': 'session',
        'paramvalues': null,
      };

      final PrismError error = PrismError.fromJson(json);

      expect(error.errorCode, 'Security.5');
      expect(error.errorMsg, 'Authorization failed: Invalid Auth token.');
      expect(error.httpCode, 403);
      expect(error.httpMessage, '403 - Forbidden');
      expect(error.functionName, 'session');
      expect(error.exceptionClass, 'EPrismCoreException');
      expect(
        error.date?.toUtc(),
        DateTime.utc(2026, 7, 22, 9, 58, 58, 767),
        reason: 'the +03:00 offset must be normalised to UTC, not dropped',
      );
    });

    test('falls back sensibly when every key is missing', () {
      final PrismError error = PrismError.fromJson(<String, dynamic>{});

      expect(error.errorCode, '');
      expect(
        error.errorMsg,
        isNull,
        reason:
            'no server message means null at this layer — the translated '
            'generic message is supplied by the presentation layer, not here',
      );
      expect(error.httpCode, isNull);
      expect(error.httpMessage, isNull);
      expect(error.functionName, isNull);
      expect(error.exceptionClass, isNull);
      expect(error.date, isNull);
    });

    test('falls back when keys are present but explicitly null', () {
      final PrismError error = PrismError.fromJson(<String, dynamic>{
        'date': null,
        'class': null,
        'errorcode': null,
        'errormsg': null,
        'httpcode': null,
        'httpmessage': null,
        'functionname': null,
      });

      expect(error.errorCode, '');
      expect(
        error.errorMsg,
        isNull,
        reason:
            'an explicit null errormsg stays null — it is not papered over '
            'with a hardcoded server-side message',
      );
      expect(error.httpCode, isNull);
      expect(error.date, isNull);
    });

    test('keeps a real errorCode even when the message is missing', () {
      final PrismError error = PrismError.fromJson(<String, dynamic>{
        'errorcode': 'Security.2',
      });

      expect(error.errorCode, 'Security.2');
      expect(error.errorMsg, isNull);
      expect(
        error.errorMsg,
        isNot('Security.2'),
        reason: 'the code must not leak into the message slot',
      );
    });

    test('an unparseable date string yields null, not a throw', () {
      final PrismError error = PrismError.fromJson(<String, dynamic>{
        'errorcode': 'Security.5',
        'errormsg': 'boom',
        'date': 'not-a-date',
      });

      expect(error.date, isNull);
      expect(error.errorCode, 'Security.5');
    });

    test('toString renders "[code] message"', () {
      const PrismError error = PrismError(
        errorCode: 'Security.5',
        errorMsg: 'Authorization failed: Invalid Auth token.',
      );

      expect(
        error.toString(),
        '[Security.5] Authorization failed: Invalid Auth token.',
      );
    });

    test('toString on a fully-defaulted error still has both brackets', () {
      final PrismError error = PrismError.fromJson(<String, dynamic>{});

      expect(error.toString(), startsWith('[] '));
      expect(
        error.toString(),
        '[] null',
        reason:
            'with no fallback message left in this layer, the absent '
            'message must surface as a visible null in diagnostics rather '
            'than as a fabricated Arabic sentence',
      );
    });
  });

  group('PrismErrorEnvelope.tryParse — real double-encoded errors string', () {
    test('parses the live Security.5 (403 invalid token) envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(kSecurity5ErrorsString),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));

      final PrismError error = envelope.first!;
      expect(error.errorCode, 'Security.5');
      expect(error.errorMsg, 'Authorization failed: Invalid Auth token.');
      expect(error.httpCode, 403);
      expect(error.httpMessage, '403 - Forbidden');
      expect(error.functionName, 'session');
      expect(error.exceptionClass, 'EPrismCoreException');
      expect(error.date?.toUtc(), DateTime.utc(2026, 7, 22, 9, 58, 58, 767));
    });

    test('parses the live Security.2 (401 bad credentials) envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(kSecurity2ErrorsString),
      );

      expect(envelope, isNotNull);
      final PrismError error = envelope!.first!;
      expect(error.errorCode, 'Security.2');
      expect(error.errorMsg, 'Login failed: Invalid username or password.');
      expect(error.httpCode, 401);
      expect(error.functionName, 'login');
      expect(error.exceptionClass, 'EPrismCoreException');
    });

    test('keeps every error and exposes the first one in order', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(kTwoErrorsString),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(2));
      expect(
        envelope.errors.map((PrismError e) => e.errorCode).toList(),
        <String>['Security.5', 'Data.17'],
      );
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.errors.last.httpCode, 404);
    });
  });

  group('PrismErrorEnvelope.tryParse — errors already a real List', () {
    test('handles a List<dynamic> of maps (future-proofing)', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<dynamic>[
          <String, dynamic>{
            'date': '2026-07-22T12:58:58.767+03:00',
            'class': 'EPrismCoreException',
            'errorcode': 'Security.5',
            'errormsg': 'Authorization failed: Invalid Auth token.',
            'httpcode': 403,
            'httpmessage': '403 - Forbidden',
            'functionname': 'session',
          },
        ]),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.httpCode, 403);
      expect(
        envelope.first!.date?.toUtc(),
        DateTime.utc(2026, 7, 22, 9, 58, 58, 767),
      );
    });

    test('handles a statically typed List<Map<String, dynamic>>', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<Map<String, dynamic>>[
          <String, dynamic>{'errorcode': 'Security.2', 'errormsg': 'nope'},
        ]),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, 'Security.2');
      expect(envelope.first!.errorMsg, 'nope');
    });

    test('silently drops non-map entries inside the list', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<dynamic>[
          'just a string',
          42,
          null,
          <String, dynamic>{'errorcode': 'Security.5', 'errormsg': 'kept'},
        ]),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));
      expect(envelope.first!.errorMsg, 'kept');
    });

    test('drops non-map entries that came from a decoded errors string', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith('["boom", 42, null]'),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });
  });

  group('PrismErrorEnvelope.tryParse — body as a raw JSON String', () {
    test('decodes an undecoded envelope string with double-encoded errors', () {
      final String rawBody = jsonEncode(envelopeWith(kSecurity5ErrorsString));

      // Sanity: the fixture really is double-encoded, not flattened.
      expect(rawBody, contains(r'\"errorcode\":\"Security.5\"'));

      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(rawBody);

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, 'Security.5');
      expect(envelope.first!.httpCode, 403);
      expect(envelope.first!.functionName, 'session');
    });

    test('decodes a raw String whose errors is a real JSON array', () {
      final String rawBody = jsonEncode(
        envelopeWith(<dynamic>[
          <String, dynamic>{'errorcode': 'Security.2', 'errormsg': 'bad creds'},
        ]),
      );

      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(rawBody);

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, 'Security.2');
      expect(envelope.first!.errorMsg, 'bad creds');
    });

    test('decodes the verbatim on-wire 403 body byte for byte', () {
      // Guards the fixture itself: this literal is what the socket delivers,
      // so it must round-trip to the same object the jsonEncode-built ones do.
      expect(
        kRawWireErrorBody,
        contains(r'"errors":"[{\"date\"'),
        reason: 'errors must stay a double-encoded String, not a real array',
      );

      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        kRawWireErrorBody,
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));

      final PrismError error = envelope.first!;
      expect(error.errorCode, 'Security.5');
      expect(error.errorMsg, 'Authorization failed: Invalid Auth token.');
      expect(error.httpCode, 403);
      expect(error.httpMessage, '403 - Forbidden');
      expect(error.functionName, 'session');
      expect(error.exceptionClass, 'EPrismCoreException');
      expect(error.date?.toUtc(), DateTime.utc(2026, 7, 22, 9, 58, 58, 767));
    });

    test('the hand-written wire body matches the jsonEncode-built fixture', () {
      final PrismError fromWire = PrismErrorEnvelope.tryParse(
        kRawWireErrorBody,
      )!.first!;
      final PrismError fromFixture = PrismErrorEnvelope.tryParse(
        jsonEncode(envelopeWith(kSecurity5ErrorsString)),
      )!.first!;

      expect(fromWire.toString(), fromFixture.toString());
      expect(fromWire.httpCode, fromFixture.httpCode);
      expect(fromWire.date, fromFixture.date);
    });

    test('a raw String with no errors key yields an empty envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        '{"data":[],"name":null}',
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });
  });

  group(
    'PrismErrorEnvelope.tryParse — hostile bodies return null, never throw',
    () {
      test('an nginx HTML error page returns null', () {
        expect(() => PrismErrorEnvelope.tryParse(kHtmlBody), returnsNormally);
        expect(PrismErrorEnvelope.tryParse(kHtmlBody), isNull);
      });

      test('a bare HTML fragment returns null', () {
        expect(
          PrismErrorEnvelope.tryParse('<h1>504 Gateway Time-out</h1>'),
          isNull,
        );
      });

      test('a null body returns null', () {
        expect(PrismErrorEnvelope.tryParse(null), isNull);
      });

      test('an empty string returns null', () {
        expect(PrismErrorEnvelope.tryParse(''), isNull);
      });

      test('a whitespace-only body returns null', () {
        expect(PrismErrorEnvelope.tryParse('   '), isNull);
      });

      test('an int body returns null', () {
        expect(PrismErrorEnvelope.tryParse(500), isNull);
      });

      test('a bool and a double body return null', () {
        expect(PrismErrorEnvelope.tryParse(true), isNull);
        expect(PrismErrorEnvelope.tryParse(1.5), isNull);
      });

      test(
        'a top-level List body returns null (that is the SUCCESS shape)',
        () {
          final List<dynamic> loginSuccessBody = <dynamic>[
            <String, dynamic>{
              'sid': '1',
              'username': 'someone',
              'employeename': 'Some One',
              'token': 'tok',
              'nonce': 'non',
              'subsidiaryname': 'HQ',
              'storename': 'Main',
              'basecurrencycodealpha': 'SAR',
            },
          ];

          expect(PrismErrorEnvelope.tryParse(loginSuccessBody), isNull);
        },
      );

      test('a raw String holding a top-level JSON array returns null', () {
        expect(PrismErrorEnvelope.tryParse('[{"token":"tok"}]'), isNull);
      });

      test('a JSON string scalar body returns null', () {
        expect(PrismErrorEnvelope.tryParse('"just a quoted string"'), isNull);
      });

      test('malformed inner JSON inside the errors string returns null', () {
        const String truncated = '[{"errorcode":"Security.5","errormsg":"boom"';

        expect(
          () => PrismErrorEnvelope.tryParse(envelopeWith(truncated)),
          returnsNormally,
        );
        expect(PrismErrorEnvelope.tryParse(envelopeWith(truncated)), isNull);
      });

      test('errors holding a JSON object instead of an array returns null', () {
        expect(
          PrismErrorEnvelope.tryParse(
            envelopeWith('{"errorcode":"Security.5","errormsg":"boom"}'),
          ),
          isNull,
        );
      });

      test('errors holding non-JSON prose returns null', () {
        expect(
          PrismErrorEnvelope.tryParse(envelopeWith('Authorization failed.')),
          isNull,
        );
      });
    },
  );

  group('PrismErrorEnvelope.tryParse — empty / absent errors', () {
    test(
      'errors as an empty string yields an empty envelope, first == null',
      () {
        final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
          envelopeWith(''),
        );

        expect(envelope, isNotNull);
        expect(envelope!.errors, isEmpty);
        expect(envelope.first, isNull);
      },
    );

    test('errors as an empty real List yields an empty envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<dynamic>[]),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });

    test('errors as the string "[]" yields an empty envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith('[]'),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });

    test('errors as null yields an empty envelope, not null', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(null),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });

    test('errors as an unexpected scalar yields an empty envelope', () {
      final PrismErrorEnvelope? fromInt = PrismErrorEnvelope.tryParse(
        envelopeWith(42),
      );
      final PrismErrorEnvelope? fromBool = PrismErrorEnvelope.tryParse(
        envelopeWith(true),
      );

      expect(
        fromInt,
        isNotNull,
        reason: 'a junk errors value must degrade to empty, not to null',
      );
      expect(fromInt!.errors, isEmpty);
      expect(fromBool, isNotNull);
      expect(fromBool!.errors, isEmpty);
    });

    test('an empty JSON object body yields an empty envelope', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        <String, dynamic>{},
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, isEmpty);
      expect(envelope.first, isNull);
    });
  });

  group('PrismErrorEnvelope.tryParse — degraded / partial error objects', () {
    test('an error object with no keys still produces one PrismError', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith('[{}]'),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));
      expect(envelope.first!.errorCode, '');
      expect(
        envelope.first!.errorMsg,
        isNull,
        reason:
            'an errormsg-less error degrades to a null message, not to a '
            'hardcoded one',
      );
      expect(envelope.first!.httpCode, isNull);
      expect(envelope.first!.date, isNull);
    });

    test('an error object with only errormsg keeps the message', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith('[{"errormsg":"Something broke server-side."}]'),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, '');
      expect(envelope.first!.errorMsg, 'Something broke server-side.');
    });

    test('a bad date on one error does not lose the rest of the error', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"date":"22/07/2026","errorcode":"Security.5","errormsg":"boom"}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.date, isNull);
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.errorMsg, 'boom');
    });

    test('extra unknown keys are ignored, not fatal', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"errorcode":"Security.5","errormsg":"boom",'
          '"paramvalues":{"a":1},"brandnewfield":["x"]}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, 'Security.5');
    });
  });

  group('PrismErrorEnvelope.tryParse — type tolerance (was: type fragility)', () {
    // These used to lock in the OLD behaviour: one wrongly-typed field threw
    // inside PrismError.fromJson, tryParse swallowed it, and the WHOLE
    // envelope was lost — so a Security.2 became a generic server error and
    // the user saw "server error" instead of "wrong password". Delphi can
    // change any field's type without telling us, so parsing is now tolerant
    // and each test below asserts the field survives (or degrades alone).

    test('httpcode arriving as a String is coerced, not fatal '
        '(was: discards the whole envelope)', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"errorcode":"Security.5","errormsg":"boom","httpcode":"403"}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));
      expect(
        envelope.first!.httpCode,
        403,
        reason: 'a stringy "403" must coerce to the int 403',
      );
      expect(envelope.first!.httpCode, isA<int>());
      expect(
        envelope.first!.errorCode,
        'Security.5',
        reason:
            'the errorcode is the field routing decides on — losing it to '
            'a sibling type change is the bug this guards',
      );
      expect(envelope.first!.errorMsg, 'boom');
    });

    test('httpcode arriving as a number still parses', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"errorcode":"Security.5","errormsg":"boom","httpcode":403}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.httpCode, 403);
      expect(envelope.first!.errorCode, 'Security.5');
    });

    test('a non-numeric httpcode degrades to null without losing the error', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"errorcode":"Security.5","errormsg":"boom","httpcode":"Forbidden"}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.httpCode, isNull);
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.errorMsg, 'boom');
    });

    test('date arriving as a number degrades to a null date and keeps the '
        'rest (was: discards the whole envelope)', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(
          '[{"errorcode":"Security.5","errormsg":"boom",'
          '"httpcode":403,"date":1753178338767}]',
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.errors, hasLength(1));
      expect(
        envelope.first!.date,
        isNull,
        reason:
            'an epoch-millis date is not an ISO string, so only the date '
            'field is sacrificed',
      );
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.errorMsg, 'boom');
      expect(envelope.first!.httpCode, 403);
    });

    test('an errorcode arriving as a number is coerced to its String form', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith('[{"errorcode":500,"errormsg":"boom"}]'),
      );

      expect(envelope, isNotNull);
      expect(envelope!.first!.errorCode, '500');
      expect(envelope.first!.errorMsg, 'boom');
    });

    test('a Map<Object?, Object?> body IS recognised as an envelope '
        '(was: not recognised)', () {
      final Map<Object?, Object?> looselyTyped = <Object?, Object?>{
        'errors': kSecurity5ErrorsString,
        'data': <dynamic>[],
      };

      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        looselyTyped,
      );

      expect(
        envelope,
        isNotNull,
        reason:
            'some Dio paths (custom transformers, a re-read cached body) '
            'hand back this looser map type and it is still valid JSON',
      );
      expect(envelope!.errors, hasLength(1));
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.httpCode, 403);
      expect(
        envelope.first!.errorMsg,
        'Authorization failed: Invalid Auth token.',
      );
      expect(
        envelope.first!.date?.toUtc(),
        DateTime.utc(2026, 7, 22, 9, 58, 58, 767),
      );
    });

    test(
      'a Map<Object?, Object?> body whose errors is a real List parses too',
      () {
        final Map<Object?, Object?> looselyTyped = <Object?, Object?>{
          'errors': <dynamic>[
            <Object?, Object?>{
              'errorcode': 'Security.2',
              'errormsg': 'bad creds',
            },
          ],
          'data': <dynamic>[],
        };

        final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
          looselyTyped,
        );

        expect(envelope, isNotNull);
        expect(envelope!.first!.errorCode, 'Security.2');
        expect(envelope.first!.errorMsg, 'bad creds');
      },
    );

    test('errors entries typed Map<Object?, Object?> are parsed, not silently '
        'dropped', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<dynamic>[
          <Object?, Object?>{
            'errorcode': 'Security.5',
            'errormsg': 'boom',
            'httpcode': 403,
          },
        ]),
      );

      expect(envelope, isNotNull);
      expect(
        envelope!.errors,
        hasLength(1),
        reason:
            'whereType<Map<String, dynamic>>() used to drop these on the '
            'floor; entries are cast now instead',
      );
      expect(envelope.first!.errorCode, 'Security.5');
      expect(envelope.first!.errorMsg, 'boom');
      expect(envelope.first!.httpCode, 403);
    });

    test('a mixed list of Map<String, dynamic> and Map<Object?, Object?> keeps '
        'both entries in order', () {
      final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
        envelopeWith(<dynamic>[
          <String, dynamic>{'errorcode': 'Security.5', 'errormsg': 'first'},
          <Object?, Object?>{'errorcode': 'Data.17', 'errormsg': 'second'},
        ]),
      );

      expect(envelope, isNotNull);
      expect(
        envelope!.errors.map((PrismError e) => e.errorCode).toList(),
        <String>['Security.5', 'Data.17'],
      );
    });

    test(
      'a wrongly-typed field never costs us the errorcode, whatever it is',
      () {
        // Regression net: every one of these bodies used to return null.
        const List<String> hostileButRecoverable = <String>[
          '[{"errorcode":"Security.2","httpcode":"401"}]',
          '[{"errorcode":"Security.2","httpmessage":401}]',
          '[{"errorcode":"Security.2","functionname":42}]',
          '[{"errorcode":"Security.2","class":7}]',
          '[{"errorcode":"Security.2","date":0}]',
          '[{"errorcode":"Security.2","errormsg":12345}]',
        ];

        for (final String errors in hostileButRecoverable) {
          final PrismErrorEnvelope? envelope = PrismErrorEnvelope.tryParse(
            envelopeWith(errors),
          );

          expect(envelope, isNotNull, reason: 'envelope lost for: $errors');
          expect(
            envelope!.first?.errorCode,
            'Security.2',
            reason: 'errorcode lost for: $errors',
          );
        }
      },
    );
  });

  group('PrismErrorEnvelope', () {
    test('first returns null on an empty list and the head otherwise', () {
      expect(const PrismErrorEnvelope(<PrismError>[]).first, isNull);

      const PrismError head = PrismError(errorCode: 'A.1', errorMsg: 'first');
      const PrismError tail = PrismError(errorCode: 'B.2', errorMsg: 'second');
      const PrismErrorEnvelope envelope = PrismErrorEnvelope(<PrismError>[
        head,
        tail,
      ]);

      expect(envelope.first, same(head));
      expect(envelope.errors, hasLength(2));
    });
  });
}
