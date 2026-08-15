import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_structure/core/network/dio_error_handler.dart';
import 'package:app_structure/core/network/failures.dart';
import 'package:app_structure/core/network/interceptors/auth_interceptor.dart';
import 'package:app_structure/core/network/interceptors/connectivity_interceptor.dart';
import 'package:app_structure/core/network/interceptors/session_expired_interceptor.dart';
import 'package:app_structure/core/network/network_info.dart';
import 'package:app_structure/core/network/token_store.dart';
import 'package:app_structure/core/storage/secure_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';

class _MockNetworkInfo extends Mock implements NetworkInfo {}

/// بيلف الـ DioAdapter عشان نعدّ كام مرة الـ transport اتنادى فعلاً.
///
/// ده اللي بيثبت إن الـ ConnectivityInterceptor قطع الريكوست قبل ما يطلع،
/// مش إنه بس رجّع error بعد ما الريكوست خرج.
class _SpyAdapter implements HttpClientAdapter {
  _SpyAdapter(this._inner);

  final HttpClientAdapter _inner;

  /// الـ RequestOptions اللي وصلت للـ transport فعلاً.
  final List<RequestOptions> calls = <RequestOptions>[];

  int get callCount => calls.length;

  RequestOptions get onlyCall {
    expect(calls, hasLength(1), reason: 'expected exactly one transport call');
    return calls.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

/// interceptor بيتحط **بعد** الـ ConnectivityInterceptor عشان نتأكد إن
/// السلسلة نفسها اتقطعت — مش بس الـ adapter.
class _DownstreamProbe extends Interceptor {
  int requestCount = 0;
  int errorCount = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestCount++;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    errorCount++;
    handler.next(err);
  }
}

class _Harness {
  _Harness() : dio = Dio(BaseOptions(baseUrl: _baseUrl)) {
    final DioAdapter mockAdapter = DioAdapter(dio: dio);
    adapter = mockAdapter;
    final _SpyAdapter spyAdapter = _SpyAdapter(mockAdapter);
    spy = spyAdapter;
    // الـ DioAdapter بيحط نفسه على الـ dio في الـ constructor، فبنستبدله بالـ spy.
    dio.httpClientAdapter = spyAdapter;
  }

  final Dio dio;
  late final DioAdapter adapter;
  late final _SpyAdapter spy;
}

const String _baseUrl = 'https://prism.invalid/api';
const String _loginPath = '/security/login';
const String _sessionPath = '/security/session';
const String _dataPath = '/company/list';

const String _fakeToken = 'fake-session-token-for-tests';
const String _fakeNonce = 'fake-nonce-for-tests';

/// نفس شكل الـ envelope اللي Prism بيرجعه: `errors` **String** جواه JSON.
Map<String, dynamic> _prismEnvelope({
  required String errorCode,
  required String errorMsg,
  required int httpCode,
  required String httpMessage,
}) => <String, dynamic>{
  'name': null,
  'metatype': null,
  'comment': null,
  'translationid': null,
  'errors': jsonEncode(<Map<String, dynamic>>[
    <String, dynamic>{
      'date': '2026-07-22T12:58:58.767+03:00',
      'class': 'EPrismCoreException',
      'errorcode': errorCode,
      'errormsg': errorMsg,
      'httpcode': httpCode,
      'httpmessage': httpMessage,
      'functionname': 'session',
      'paramvalues': null,
    },
  ]),
  'data': <dynamic>[],
};

Map<String, dynamic> get _invalidTokenEnvelope => _prismEnvelope(
  errorCode: 'Security.5',
  errorMsg: 'Authorization failed: Invalid Auth token.',
  httpCode: 403,
  httpMessage: '403 - Forbidden',
);

Map<String, dynamic> get _badCredentialsEnvelope => _prismEnvelope(
  errorCode: 'Security.2',
  errorMsg: 'Authorization failed: wrong user name or password.',
  httpCode: 401,
  httpMessage: '401 - Unauthorized',
);

Map<String, dynamic> get _serverErrorEnvelope => _prismEnvelope(
  errorCode: 'Prism.9',
  errorMsg: 'Internal server error.',
  httpCode: 500,
  httpMessage: '500 - Internal Server Error',
);

/// بينفّذ الريكوست ويرجّع الـ DioException بدل ما يرميها.
Future<DioException> _captureError(Future<void> Function() request) async {
  try {
    await request();
  } on DioException catch (e) {
    return e;
  }
  fail('expected the request to fail with a DioException, but it succeeded');
}

/// بيسيب الـ event loop يلف لحد ما مسح الجلسة يخلص.
///
/// الـ SessionExpiredInterceptor بينادي `clear()` من غير await (fire-and-forget
/// جوه onError)، والـ TokenStore بقى بيعمل الـ I/O على الـ secure store
/// **الأول** وبعدين يمسح الذاكرة ويـ notify. يعني الـ error بيوصل للكولر
/// قبل ما المسح يخلص بميكروتاسك أو اتنين — ده ترتيب مقصود مش سباق.
Future<void> _settleClear() => Future<void>.delayed(Duration.zero);

/// Secure store بنقدر نجمّد الـ delete بتاعه لحد ما نفتح البوابة بإيدينا.
///
/// موجود عشان نثبت **ترتيب** الـ clear(): الديسك الأول، وبعدين الذاكرة
/// والـ notify — من غير ما نعتمد على عدد الميكروتاسكس.
class _GatedSecureStore implements SecureStore {
  final Map<String, String> _data = <String, String>{};

  /// لو مش null، أي delete هيستنى عليه قبل ما ينفّذ.
  Completer<void>? gate;

  /// كام مرة اتنادى الـ delete فعلاً (يعني الـ clear() بدأ شغله).
  int deleteCount = 0;

  void openGate() {
    gate?.complete();
    gate = null;
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    final Completer<void>? pending = gate;
    if (pending != null) await pending.future;
    _data.remove(key);
  }
}

void main() {
  group('ConnectivityInterceptor', () {
    late _Harness harness;
    late _MockNetworkInfo networkInfo;
    late _DownstreamProbe downstream;

    setUp(() {
      harness = _Harness();
      networkInfo = _MockNetworkInfo();
      downstream = _DownstreamProbe();
      harness.dio.interceptors.add(ConnectivityInterceptor(networkInfo));
      harness.dio.interceptors.add(downstream);
    });

    void goOffline() =>
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

    void goOnline() =>
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);

    test('offline: the transport is never reached at all', () async {
      goOffline();
      // لو الريكوست خرج بجد كان هيرجع 200 — فأي error هنا معناه إننا قطعناه.
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await expectLater(
        harness.dio.get<dynamic>(_dataPath),
        throwsA(isA<DioException>()),
      );

      expect(
        harness.spy.callCount,
        0,
        reason:
            'offline request must be rejected before it hits the transport; '
            'the mocked route would have returned 200 if it had been sent',
      );
      expect(
        downstream.requestCount,
        0,
        reason: 'the interceptor chain must be short-circuited, not continued',
      );
      verify(() => networkInfo.isConnected).called(1);
    });

    test(
      'offline: rejection carries OfflineException and maps to OfflineFailure',
      () async {
        goOffline();
        harness.adapter.onGet(
          _dataPath,
          (server) => server.reply(200, <String, dynamic>{'ok': true}),
        );

        final DioException error = await _captureError(
          () => harness.dio.get<dynamic>(_dataPath),
        );

        expect(error.error, isA<OfflineException>());
        expect(error.type, DioExceptionType.connectionError);
        expect(error.response, isNull);
        expect(handleDioError(error), const OfflineFailure());
        expect(harness.spy.callCount, 0);
      },
    );

    test(
      'offline: rejects even when no route is mocked (nothing goes out)',
      () async {
        goOffline();
        // مفيش أي route متسجّل — لو الريكوست وصل للـ adapter كان هيرمي
        // AssertionError مش DioException.
        final DioException error = await _captureError(
          () => harness.dio.get<dynamic>('/anything/at/all'),
        );

        expect(error.error, isA<OfflineException>());
        expect(harness.spy.callCount, 0);
      },
    );

    test('offline: interceptors after it still see the error', () async {
      goOffline();
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await _captureError(() => harness.dio.get<dynamic>(_dataPath));

      expect(
        downstream.errorCount,
        1,
        reason:
            'the rejection passes callFollowingErrorInterceptor: true, so an '
            'interceptor registered after this one (SessionExpiredInterceptor '
            'in ApiClient) must still be given the chance to react',
      );
      expect(downstream.requestCount, 0);
    });

    test(
      'online: the request passes through and returns the mocked 200',
      () async {
        goOnline();
        harness.adapter.onGet(
          _dataPath,
          (server) =>
              server.reply(200, <String, dynamic>{'storename': 'Main Store'}),
        );

        final Response<dynamic> response = await harness.dio.get<dynamic>(
          _dataPath,
        );

        expect(response.statusCode, 200);
        expect(
          (response.data as Map<String, dynamic>)['storename'],
          'Main Store',
        );
        expect(harness.spy.callCount, 1);
        expect(downstream.requestCount, 1);
      },
    );

    test(
      'online: a real server error still surfaces (not masked as offline)',
      () async {
        goOnline();
        harness.adapter.onGet(
          _dataPath,
          (server) => server.reply(500, _serverErrorEnvelope),
        );

        final DioException error = await _captureError(
          () => harness.dio.get<dynamic>(_dataPath),
        );

        expect(error.error, isNot(isA<OfflineException>()));
        expect(
          handleDioError(error),
          const ServerFailure(
            serverMessage: 'Internal server error.',
            errorCode: 'Prism.9',
            statusCode: 500,
          ),
          reason:
              'an online 500 must keep its real Prism code, not collapse '
              'into OfflineFailure/NetworkFailure',
        );
        expect(harness.spy.callCount, 1);
      },
    );
  });

  group('AuthInterceptor', () {
    late _Harness harness;
    late TokenStore tokenStore;

    setUp(() {
      harness = _Harness();
      tokenStore = TokenStore(InMemorySecureStore());
      harness.dio.interceptors.add(AuthInterceptor(tokenStore));
    });

    tearDown(() => tokenStore.dispose());

    test('injects Auth-Session when a token exists', () async {
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await harness.dio.get<dynamic>(_dataPath);

      expect(harness.spy.onlyCall.headers['Auth-Session'], _fakeToken);
    });

    test('never injects Auth-Session on the login path', () async {
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
      // من غير ده الاختبار ممكن ينجح وهو فاضي لو الـ save اتكسر يوم.
      expect(tokenStore.token, _fakeToken);
      final Map<String, dynamic> body = <String, dynamic>{
        'username': 'someone',
        'workstation': 'webclient',
      };
      harness.adapter.onPost(
        _loginPath,
        (server) => server.reply(200, <Map<String, dynamic>>[
          <String, dynamic>{'token': 'new-token', 'nonce': 'new-nonce'},
        ]),
        data: body,
      );

      await harness.dio.post<dynamic>(_loginPath, data: body);

      expect(
        harness.spy.onlyCall.headers.containsKey('Auth-Session'),
        isFalse,
        reason: 'Prism rejects a login request that carries a stale session',
      );
    });

    test('injects nothing when the token is null', () async {
      expect(tokenStore.isLoggedIn, isFalse);
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await harness.dio.get<dynamic>(_dataPath);

      expect(harness.spy.onlyCall.headers.containsKey('Auth-Session'), isFalse);
    });

    test('only the login path is exempt, not every /security/ path', () async {
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
      harness.adapter.onGet(
        _sessionPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await harness.dio.get<dynamic>(_sessionPath);

      expect(harness.spy.onlyCall.headers['Auth-Session'], _fakeToken);
    });

    test('reads the token live: after clear() the header disappears', () async {
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      await harness.dio.get<dynamic>(_dataPath);
      await tokenStore.clear();
      await harness.dio.get<dynamic>(_dataPath);

      expect(harness.spy.calls, hasLength(2));
      expect(harness.spy.calls[0].headers['Auth-Session'], _fakeToken);
      expect(harness.spy.calls[1].headers.containsKey('Auth-Session'), isFalse);
    });
  });

  group('SessionExpiredInterceptor', () {
    late _Harness harness;
    late TokenStore tokenStore;
    late int notifyCount;

    void onChange() => notifyCount++;

    setUp(() async {
      harness = _Harness();
      tokenStore = TokenStore(InMemorySecureStore());
      harness.dio.interceptors.add(SessionExpiredInterceptor(tokenStore));
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
      notifyCount = 0;
      tokenStore.addListener(onChange);
    });

    tearDown(() {
      tokenStore.removeListener(onChange);
      tokenStore.dispose();
    });

    test('403 Security.5 clears the session and notifies listeners', () async {
      harness.adapter.onGet(
        _sessionPath,
        (server) => server.reply(403, _invalidTokenEnvelope),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_sessionPath),
      );

      expect(handleDioError(error), const UnauthorizedFailure());

      await _settleClear();
      expect(tokenStore.isLoggedIn, isFalse);
      expect(tokenStore.token, isNull);
      expect(tokenStore.nonce, isNull);
      expect(
        notifyCount,
        1,
        reason: 'the router listens to TokenStore to bounce back to /login',
      );
    });

    test('403 Security.5 also wipes the persisted token', () async {
      final InMemorySecureStore store = InMemorySecureStore();
      final TokenStore persisted = TokenStore(store);
      addTearDown(persisted.dispose);
      final _Harness local = _Harness();
      local.dio.interceptors.add(SessionExpiredInterceptor(persisted));
      await persisted.save(token: _fakeToken, nonce: _fakeNonce);
      expect(await store.read('prism_token'), _fakeToken);

      local.adapter.onGet(
        _sessionPath,
        (server) => server.reply(403, _invalidTokenEnvelope),
      );
      await _captureError(() => local.dio.get<dynamic>(_sessionPath));
      // clear() مش متعمّلها await جوه الـ interceptor، فبنسيب الـ event loop يلف.
      await Future<void>.delayed(Duration.zero);

      expect(
        await store.read('prism_token'),
        isNull,
        reason: 'a dead token must not survive an app restart',
      );
      expect(await store.read('prism_nonce'), isNull);
    });

    test('401 Security.2 does NOT clear the session', () async {
      harness.adapter.onPost(
        _loginPath,
        (server) => server.reply(401, _badCredentialsEnvelope),
      );

      final DioException error = await _captureError(
        () => harness.dio.post<dynamic>(_loginPath),
      );

      expect(handleDioError(error), const InvalidCredentialsFailure());
      expect(
        tokenStore.isLoggedIn,
        isTrue,
        reason: 'wrong credentials on one call must not kill a live session',
      );
      expect(tokenStore.token, _fakeToken);
      expect(notifyCount, 0);
    });

    test('500 does NOT clear the session', () async {
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(500, _serverErrorEnvelope),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_dataPath),
      );

      expect(
        handleDioError(error),
        const ServerFailure(
          serverMessage: 'Internal server error.',
          errorCode: 'Prism.9',
          statusCode: 500,
        ),
      );
      expect(tokenStore.isLoggedIn, isTrue);
      expect(tokenStore.token, _fakeToken);
      expect(notifyCount, 0);
    });

    test('the error keeps propagating to the caller after clearing', () async {
      harness.adapter.onGet(
        _sessionPath,
        (server) => server.reply(403, _invalidTokenEnvelope),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_sessionPath),
      );

      expect(error.response?.statusCode, 403);

      await _settleClear();
      expect(tokenStore.isLoggedIn, isFalse);
    });

    // الحالة دي هي الثغرة اللي اتقفلت: بروكسي أو WAF بيرفض التوكن الميت قبل
    // ما يوصل لـ Prism أصلاً، فبيرجّع HTML مش envelope. قبل الإصلاح كان ده
    // بيبقى ServerFailure والتوكن الميت يفضل متخزّن والتطبيق يفضل يبعته.
    test(
      'bare 403 with an HTML body (no Prism envelope) still clears',
      () async {
        harness.adapter.onGet(
          _sessionPath,
          (server) => server.reply(403, '<html><body>Forbidden</body></html>'),
        );

        final DioException error = await _captureError(
          () => harness.dio.get<dynamic>(_sessionPath),
        );

        expect(handleDioError(error), const UnauthorizedFailure());

        await _settleClear();
        expect(tokenStore.isLoggedIn, isFalse);
        expect(notifyCount, 1);
      },
    );

    test('bare 401 with an empty body also clears the session', () async {
      harness.adapter.onGet(_sessionPath, (server) => server.reply(401, null));

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_sessionPath),
      );

      expect(handleDioError(error), const UnauthorizedFailure());

      await _settleClear();
      expect(tokenStore.isLoggedIn, isFalse);
    });

    test('bare 500 with an HTML body does NOT clear the session', () async {
      harness.adapter.onGet(
        _sessionPath,
        (server) => server.reply(500, '<html><body>Server Error</body></html>'),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_sessionPath),
      );

      expect(handleDioError(error), isA<ServerFailure>());

      await _settleClear();
      expect(
        tokenStore.isLoggedIn,
        isTrue,
        reason: 'a broken server is not a revoked session',
      );
      expect(notifyCount, 0);
    });

    test(
      'clear() writes to disk BEFORE it wipes memory and notifies',
      () async {
        final gated = _GatedSecureStore();
        final gatedStore = TokenStore(gated);
        await gatedStore.save(token: _fakeToken, nonce: _fakeNonce);

        var notified = 0;
        gatedStore.addListener(() => notified++);
        addTearDown(gatedStore.dispose);

        gated.gate = Completer<void>();
        final Future<void> clearing = gatedStore.clear();
        await _settleClear();

        // الـ delete بدأ، لكن لسه متعلّق على البوابة
        expect(gated.deleteCount, greaterThan(0));
        expect(
          gatedStore.isLoggedIn,
          isTrue,
          reason: 'memory must survive until the disk write actually lands',
        );
        expect(notified, 0, reason: 'the router must not redirect prematurely');

        gated.openGate();
        await clearing;

        expect(gatedStore.isLoggedIn, isFalse);
        expect(notified, 1);
      },
    );
  });

  group('the three interceptors chained the way ApiClient wires them', () {
    late _Harness harness;
    late _MockNetworkInfo networkInfo;
    late TokenStore tokenStore;

    setUp(() async {
      harness = _Harness();
      networkInfo = _MockNetworkInfo();
      tokenStore = TokenStore(InMemorySecureStore());
      harness.dio.interceptors.add(ConnectivityInterceptor(networkInfo));
      harness.dio.interceptors.add(AuthInterceptor(tokenStore));
      harness.dio.interceptors.add(SessionExpiredInterceptor(tokenStore));
      await tokenStore.save(token: _fakeToken, nonce: _fakeNonce);
    });

    tearDown(() => tokenStore.dispose());

    test('offline does not log the user out', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      harness.adapter.onGet(
        _dataPath,
        (server) => server.reply(200, <String, dynamic>{'ok': true}),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_dataPath),
      );

      expect(handleDioError(error), const OfflineFailure());
      expect(harness.spy.callCount, 0);
      expect(
        tokenStore.isLoggedIn,
        isTrue,
        reason: 'losing signal is not the same as losing the session',
      );
    });

    test('online 403 Security.5 sends the token then clears it', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      harness.adapter.onGet(
        _sessionPath,
        (server) => server.reply(403, _invalidTokenEnvelope),
      );

      final DioException error = await _captureError(
        () => harness.dio.get<dynamic>(_sessionPath),
      );

      expect(harness.spy.onlyCall.headers['Auth-Session'], _fakeToken);
      expect(handleDioError(error), const UnauthorizedFailure());

      await _settleClear();
      expect(tokenStore.isLoggedIn, isFalse);
    });
  });
}
