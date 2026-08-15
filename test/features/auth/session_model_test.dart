import 'dart:convert';

import 'package:app_structure/features/auth/data/models/session_model.dart';
import 'package:app_structure/features/auth/domain/entities/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exact body Prism returns for `GET /security/login` on HTTP 200:
/// a top-level JSON **array** holding a single object with all-lowercase keys.
/// Values below are fabricated fixtures — no real credentials.
const String kPrismLoginBody = '''
[
  {
    "sid": "9f3c1a7e-0001",
    "username": "cashier01",
    "employeename": "Ahmed Kadry",
    "token": "tok_fixture_abc123",
    "nonce": "nonce_fixture_xyz789",
    "subsidiaryname": "Retail-Tec Egypt",
    "storename": "Cairo Festival City",
    "basecurrencycodealpha": "EGP"
  }
]
''';

/// The real Prism error envelope, verbatim: `errors` is a **double-encoded**
/// JSON string, and `data` is an empty array. This is what comes back on
/// HTTP 401 (`Security.2`) and HTTP 403 (`Security.5`).
const String kPrismErrorEnvelope =
    '{"name":null,"metatype":null,"comment":null,"translationid":null,'
    '"errors":"[{\\"date\\":\\"2026-07-22T12:58:58.767+03:00\\",'
    '\\"class\\":\\"EPrismCoreException\\",\\"errorcode\\":\\"Security.5\\",'
    '\\"errormsg\\":\\"Authorization failed: Invalid Auth token.\\",'
    '\\"httpcode\\":403,\\"httpmessage\\":\\"403 - Forbidden\\",'
    '\\"functionname\\":\\"session\\",\\"paramvalues\\":null}]",'
    '"data":[]}';

/// The same payload as a decoded map, for the object-shaped branch.
Map<String, dynamic> prismSessionMap() =>
    (jsonDecode(kPrismLoginBody) as List<dynamic>).first
        as Map<String, dynamic>;

SessionModel buildModel({
  String sid = 'sid-1',
  String username = 'cashier01',
  String employeeName = 'Ahmed Kadry',
  String token = 'tok_fixture_abc123',
  String nonce = 'nonce_fixture_xyz789',
  String subsidiaryName = 'Retail-Tec Egypt',
  String storeName = 'Cairo Festival City',
  String currency = 'EGP',
}) => SessionModel(
  sid: sid,
  username: username,
  employeeName: employeeName,
  token: token,
  nonce: nonce,
  subsidiaryName: subsidiaryName,
  storeName: storeName,
  currency: currency,
);

void main() {
  group('SessionModel.fromJson', () {
    test('maps every lowercase Prism key onto the right entity field', () {
      final SessionModel model = SessionModel.fromJson(prismSessionMap());

      expect(model.sid, '9f3c1a7e-0001');
      expect(model.username, 'cashier01');
      expect(model.employeeName, 'Ahmed Kadry');
      expect(model.token, 'tok_fixture_abc123');
      expect(model.nonce, 'nonce_fixture_xyz789');
      expect(model.subsidiaryName, 'Retail-Tec Egypt');
      expect(model.storeName, 'Cairo Festival City');
      expect(model.currency, 'EGP');
    });

    test('reads basecurrencycodealpha (not a camelCase "currency" key) '
        'into currency', () {
      // If the mapping ever regresses to json['currency'], this fails.
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'basecurrencycodealpha': 'SAR',
        'currency': 'WRONG',
      });

      expect(model.currency, 'SAR');
    });

    test('reads employeename (not a camelCase "employeeName" key) '
        'into employeeName', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'employeename': 'Correct Name',
        'employeeName': 'WRONG',
      });

      expect(model.employeeName, 'Correct Name');
    });

    test('reads subsidiaryname and storename into their camelCase fields', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'subsidiaryname': 'Retail-Tec KSA',
        'storename': 'Riyadh Park',
        'subsidiaryName': 'WRONG',
        'storeName': 'WRONG',
      });

      expect(model.subsidiaryName, 'Retail-Tec KSA');
      expect(model.storeName, 'Riyadh Park');
    });

    test('falls back to empty strings when every key is missing', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{});

      expect(model.sid, '');
      expect(model.username, '');
      expect(model.employeeName, '');
      expect(model.token, '');
      expect(model.nonce, '');
      expect(model.subsidiaryName, '');
      expect(model.storeName, '');
      expect(model.currency, '');
    });

    test('falls back to empty strings when keys are present but null', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'sid': null,
        'username': null,
        'employeename': null,
        'token': null,
        'nonce': null,
        'subsidiaryname': null,
        'storename': null,
        'basecurrencycodealpha': null,
      });

      expect(
        model,
        buildModel(
          sid: '',
          username: '',
          employeeName: '',
          token: '',
          nonce: '',
          subsidiaryName: '',
          storeName: '',
          currency: '',
        ),
      );
    });

    test('keeps present values while defaulting only the absent ones', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'token': 'tok_partial',
        'nonce': 'nonce_partial',
      });

      expect(model.token, 'tok_partial');
      expect(model.nonce, 'nonce_partial');
      expect(model.sid, '');
      expect(model.username, '');
      expect(model.currency, '');
    });

    test('coerces a numeric sid/token to its string form '
        '(regression: a numeric field used to throw TypeError)', () {
      // Delphi/Prism happily emits `"sid": 12345` for the same field it
      // usually sends as text. An explicit `as String` cast used to blow up
      // the whole login on one stray field.
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'sid': 12345,
        'token': 987654321,
        'username': 'cashier01',
      });

      expect(model.sid, '12345');
      expect(model.token, '987654321');
      expect(model.username, 'cashier01');
    });

    test('coerces every non-string scalar type Prism can emit', () {
      final SessionModel model = SessionModel.fromJson(<String, dynamic>{
        'sid': 42,
        'username': true,
        'employeename': 3.5,
        'token': 0,
        'nonce': false,
        'subsidiaryname': -7,
        'storename': 1.0,
        'basecurrencycodealpha': 818,
      });

      expect(
        model,
        buildModel(
          sid: '42',
          username: 'true',
          employeeName: '3.5',
          token: '0',
          nonce: 'false',
          subsidiaryName: '-7',
          storeName: '1.0',
          currency: '818',
        ),
      );
    });

    test('ignores unknown extra keys Prism sends alongside the session', () {
      final Map<String, dynamic> json = prismSessionMap()
        ..addAll(<String, dynamic>{
          'someUnmappedFlag': true,
          'roles': <dynamic>['cashier', 'supervisor'],
        });

      final SessionModel model = SessionModel.fromJson(json);

      // Full equality: the extra keys must not leak into or displace any
      // mapped field, so the result is identical to the clean payload.
      expect(model, SessionModel.fromJson(prismSessionMap()));
    });
  });

  group('SessionModel.fromResponse', () {
    test('unwraps the real Prism login shape (single-element List)', () {
      final dynamic decoded = jsonDecode(kPrismLoginBody);

      final SessionModel model = SessionModel.fromResponse(decoded);

      expect(model.sid, '9f3c1a7e-0001');
      expect(model.token, 'tok_fixture_abc123');
      expect(model.nonce, 'nonce_fixture_xyz789');
      expect(model.currency, 'EGP');
      expect(model.employeeName, 'Ahmed Kadry');
    });

    test('takes the first element when the List has more than one', () {
      final SessionModel model = SessionModel.fromResponse(<dynamic>[
        <String, dynamic>{'username': 'first', 'token': 'tok_first'},
        <String, dynamic>{'username': 'second', 'token': 'tok_second'},
      ]);

      expect(model.username, 'first');
      expect(model.token, 'tok_first');
    });

    test('accepts a plain Map (non-array endpoints)', () {
      final SessionModel model = SessionModel.fromResponse(prismSessionMap());

      expect(model, SessionModel.fromJson(prismSessionMap()));
      expect(model.storeName, 'Cairo Festival City');
    });

    test('throws FormatException on an empty List', () {
      expect(
        () => SessionModel.fromResponse(<dynamic>[]),
        throwsFormatException,
      );
    });

    test('throws FormatException on a String body', () {
      // e.g. the raw Prism error envelope arriving as an undecoded string.
      expect(
        () => SessionModel.fromResponse('not a session'),
        throwsFormatException,
      );
    });

    test('throws FormatException on an int body', () {
      expect(() => SessionModel.fromResponse(403), throwsFormatException);
    });

    test('throws FormatException on null', () {
      expect(() => SessionModel.fromResponse(null), throwsFormatException);
    });

    test('type tolerance did not widen the accepted shapes: every '
        'non-Map body still throws FormatException', () {
      // Regression guard for the Map<Object?, Object?> loosening — it must
      // accept differently-typed *maps*, never non-map payloads.
      for (final Object? body in <Object?>[
        <dynamic>[],
        'not a session',
        403,
        null,
        1.5,
        true,
        <dynamic>['oops'],
        <dynamic>[<dynamic>[]],
      ]) {
        expect(
          () => SessionModel.fromResponse(body),
          throwsFormatException,
          reason: 'body $body must be rejected',
        );
      }
    });

    test('maps the real Prism error envelope to an all-empty session', () {
      final Map<String, dynamic> envelope =
          jsonDecode(kPrismErrorEnvelope) as Map<String, dynamic>;

      // Guard the fixture itself: `errors` really is a double-encoded string
      // carrying the Security.5 code, not an already-decoded list.
      expect(envelope['errors'], isA<String>());
      final List<dynamic> decodedErrors =
          jsonDecode(envelope['errors'] as String) as List<dynamic>;
      expect(
        decodedErrors.first as Map<String, dynamic>,
        containsPair('errorcode', 'Security.5'),
      );

      final SessionModel model = SessionModel.fromResponse(envelope);

      // BUG (documented, not fixed): the envelope is a Map, so it satisfies
      // the Map branch and every key falls back to ''. A caller that trusts
      // fromResponse gets a token-less session rather than a throw. Asserting
      // all eight fields, so this fails loudly the moment parsing rejects a
      // payload with no token.
      expect(
        model,
        buildModel(
          sid: '',
          username: '',
          employeeName: '',
          token: '',
          nonce: '',
          subsidiaryName: '',
          storeName: '',
          currency: '',
        ),
      );
    });

    test('throws FormatException on a List whose first element is not a '
        'session object', () {
      // Must not fabricate a bogus session; the throw is caught by
      // ResultX.toResult() and surfaces as a failure.
      expect(
        () => SessionModel.fromResponse(<dynamic>['oops']),
        throwsFormatException,
      );
      expect(
        () => SessionModel.fromResponse(<dynamic>[403]),
        throwsFormatException,
      );
      expect(
        () => SessionModel.fromResponse(<dynamic>[null]),
        throwsFormatException,
      );
    });

    test('coerces non-string field values instead of throwing on them', () {
      // Previously pinned as a throw; the parser is now type-tolerant, so a
      // numeric field inside the Prism array must parse, not kill the login.
      final SessionModel model = SessionModel.fromResponse(<dynamic>[
        <String, dynamic>{'sid': 12345, 'username': 'cashier01'},
      ]);

      expect(model.sid, '12345');
      expect(model.username, 'cashier01');
      // Untouched fields still default rather than picking up junk.
      expect(model.token, '');
      expect(model.nonce, '');
    });

    test('accepts a Map that is not typed Map<String, dynamic>', () {
      // Previously pinned as a rejection. jsonDecode inside an isolate/codec
      // can hand back Map<Object?, Object?>, which used to be thrown away.
      final Map<dynamic, dynamic> loose = <dynamic, dynamic>{
        'sid': 'x',
        'token': 'tok_x',
      };

      final SessionModel model = SessionModel.fromResponse(loose);

      expect(model.sid, 'x');
      expect(model.token, 'tok_x');
    });

    test('a Map<Object?, Object?> parses identically to a '
        'Map<String, dynamic>', () {
      final Map<String, dynamic> typed = prismSessionMap();
      final Map<Object?, Object?> loose = <Object?, Object?>{...typed};

      expect(
        SessionModel.fromResponse(loose),
        equals(SessionModel.fromResponse(typed)),
      );
      expect(SessionModel.fromResponse(loose).token, 'tok_fixture_abc123');
    });

    test('a List holding a Map<Object?, Object?> parses identically to a '
        'List holding a Map<String, dynamic>', () {
      final Map<String, dynamic> typed = prismSessionMap();

      expect(
        SessionModel.fromResponse(<dynamic>[
          <Object?, Object?>{...typed},
        ]),
        equals(SessionModel.fromResponse(<dynamic>[typed])),
      );
    });
  });

  group('SessionModel identity', () {
    test('is a Session', () {
      expect(buildModel(), isA<Session>());
      expect(
        SessionModel.fromResponse(jsonDecode(kPrismLoginBody)),
        isA<Session>(),
      );
    });

    test('two identical instances are equal and share a hashCode', () {
      final SessionModel a = buildModel();
      final SessionModel b = buildModel();

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(identical(a, b), isFalse);
    });

    test('two models parsed from the same payload are equal', () {
      final SessionModel a = SessionModel.fromResponse(
        jsonDecode(kPrismLoginBody),
      );
      final SessionModel b = SessionModel.fromJson(prismSessionMap());

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('a difference in any single field breaks equality', () {
      final SessionModel base = buildModel();

      expect(base, isNot(equals(buildModel(sid: 'other'))));
      expect(base, isNot(equals(buildModel(username: 'other'))));
      expect(base, isNot(equals(buildModel(employeeName: 'other'))));
      expect(base, isNot(equals(buildModel(token: 'other'))));
      expect(base, isNot(equals(buildModel(nonce: 'other'))));
      expect(base, isNot(equals(buildModel(subsidiaryName: 'other'))));
      expect(base, isNot(equals(buildModel(storeName: 'other'))));
      expect(base, isNot(equals(buildModel(currency: 'other'))));
    });

    test('Equatable compares runtimeType: SessionModel != plain Session', () {
      // Documented gotcha — anything comparing a SessionModel against a
      // hand-built Session (e.g. in a bloc_test `expect`) will not match.
      const Session plain = Session(
        sid: 'sid-1',
        username: 'cashier01',
        employeeName: 'Ahmed Kadry',
        token: 'tok_fixture_abc123',
        nonce: 'nonce_fixture_xyz789',
        subsidiaryName: 'Retail-Tec Egypt',
        storeName: 'Cairo Festival City',
        currency: 'EGP',
      );

      expect(buildModel().props, plain.props);
      expect(buildModel(), isNot(equals(plain)));
    });
  });
}
