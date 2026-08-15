import 'package:app_structure/core/network/token_store.dart';
import 'package:app_structure/core/storage/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The keys TokenStore persists under. They are private in production, so we
/// re-declare them here on purpose: renaming a key silently logs every user
/// out on the next app start, and these tests must fail if that ever happens.
const String _tokenKey = 'prism_token';
const String _nonceKey = 'prism_nonce';

const String _token = 'session-token-aaaa';
const String _nonce = 'session-nonce-bbbb';

/// SecureStore that records every call, so we can assert *which* keys were
/// touched and that a no-op path really is a no-op.
///
/// It can also be told to start failing mid-test ([failReads], [failWrites],
/// [failDeletes]). That is the realistic shape of a keychain outage: the store
/// worked when the user logged in and stops working later, so a test can build
/// a genuine session first and only then pull the disk out from under it.
class _RecordingSecureStore implements SecureStore {
  _RecordingSecureStore();

  final Map<String, String> data = <String, String>{};
  final List<String> reads = <String>[];
  final List<String> writes = <String>[];
  final List<String> deletes = <String>[];

  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  /// When set, only the write/delete of this key fails. Used to exercise the
  /// half-way failure: the first key lands on disk, the second one blows up.
  String? failOnlyKey;

  bool _shouldFail(bool flag, String key) =>
      flag && (failOnlyKey == null || failOnlyKey == key);

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (_shouldFail(failReads, key)) {
      throw Exception('keychain unavailable: $key');
    }
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes.add(key);
    if (_shouldFail(failWrites, key)) {
      throw Exception('keychain unavailable: $key');
    }
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    deletes.add(key);
    if (_shouldFail(failDeletes, key)) {
      throw Exception('keychain unavailable: $key');
    }
    data.remove(key);
  }
}

/// Simulates a keychain that is unavailable — the real-world case after an
/// app reinstall on iOS, or a locked device on a cold start.
class _ThrowingSecureStore implements SecureStore {
  const _ThrowingSecureStore();

  @override
  Future<String?> read(String key) async =>
      throw Exception('keychain unavailable: $key');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('keychain unavailable: $key');

  @override
  Future<void> delete(String key) async =>
      throw Exception('keychain unavailable: $key');
}

void main() {
  late InMemorySecureStore secureStore;
  late TokenStore tokenStore;
  late int notifications;

  /// Snapshot of `isLoggedIn` as seen *inside* each notification. go_router's
  /// refreshListenable re-evaluates redirects synchronously from the callback,
  /// so the state must already be correct when listeners run.
  late List<bool> loggedInAtNotify;

  /// Snapshot of `token`/`nonce` as seen inside each notification. The
  /// AuthInterceptor reads these synchronously off the back of a redirect, so
  /// notifying before the fields are assigned would ship an unauthenticated
  /// request. Recorded separately from [loggedInAtNotify] because `isLoggedIn`
  /// only looks at the token and would not catch a missing nonce.
  late List<String?> tokenAtNotify;
  late List<String?> nonceAtNotify;

  void attach(TokenStore store) {
    notifications = 0;
    loggedInAtNotify = <bool>[];
    tokenAtNotify = <String?>[];
    nonceAtNotify = <String?>[];
    store.addListener(() {
      notifications++;
      loggedInAtNotify.add(store.isLoggedIn);
      tokenAtNotify.add(store.token);
      nonceAtNotify.add(store.nonce);
    });
  }

  setUp(() {
    secureStore = InMemorySecureStore();
    tokenStore = TokenStore(secureStore);
    attach(tokenStore);
  });

  tearDown(() {
    tokenStore.dispose();
  });

  group('initial state', () {
    test('starts empty and logged out without touching storage', () {
      expect(tokenStore.token, isNull);
      expect(tokenStore.nonce, isNull);
      expect(tokenStore.isLoggedIn, isFalse);
      expect(notifications, 0);
    });
  });

  group('save', () {
    test(
      'sets token + nonce, flips isLoggedIn, notifies exactly once',
      () async {
        await tokenStore.save(token: _token, nonce: _nonce);

        expect(tokenStore.token, _token);
        expect(tokenStore.nonce, _nonce);
        expect(tokenStore.isLoggedIn, isTrue);
        expect(notifications, 1);
        // The router must see the logged-in state from inside the callback, and
        // the interceptor must be able to read both credentials there too.
        expect(loggedInAtNotify, <bool>[true]);
        expect(tokenAtNotify, <String?>[_token]);
        expect(nonceAtNotify, <String?>[_nonce]);
      },
    );

    test('persists both values under the expected keys', () async {
      final _RecordingSecureStore recording = _RecordingSecureStore();
      final TokenStore store = TokenStore(recording);
      addTearDown(store.dispose);

      await store.save(token: _token, nonce: _nonce);

      expect(recording.writes, <String>[_tokenKey, _nonceKey]);
      expect(recording.data[_tokenKey], _token);
      expect(recording.data[_nonceKey], _nonce);
    });

    test('a second save overwrites and notifies again', () async {
      await tokenStore.save(token: _token, nonce: _nonce);
      await tokenStore.save(token: 'token-2', nonce: 'nonce-2');

      expect(tokenStore.token, 'token-2');
      expect(tokenStore.nonce, 'nonce-2');
      expect(notifications, 2);
      expect(await secureStore.read(_tokenKey), 'token-2');
      expect(await secureStore.read(_nonceKey), 'nonce-2');
    });

    test('persists to storage BEFORE notifying listeners', () async {
      final _RecordingSecureStore recording = _RecordingSecureStore();
      final TokenStore store = TokenStore(recording);
      addTearDown(store.dispose);

      // What the disk looked like from *inside* the callback. The router
      // pushes /home off this notification, so both writes must already have
      // completed by the time anyone is told there is a session.
      final List<int> writesAtNotify = <int>[];
      final List<String?> tokenOnDiskAtNotify = <String?>[];
      store.addListener(() {
        writesAtNotify.add(recording.writes.length);
        tokenOnDiskAtNotify.add(recording.data[_tokenKey]);
      });

      await store.save(token: _token, nonce: _nonce);

      expect(writesAtNotify, <int>[2]);
      expect(tokenOnDiskAtNotify, <String?>[_token]);
    });

    test(
      'a throwing write rethrows, leaves memory untouched and never notifies',
      () async {
        final _RecordingSecureStore recording = _RecordingSecureStore()
          ..failWrites = true;
        final TokenStore store = TokenStore(recording);
        addTearDown(store.dispose);
        attach(store);

        // The failure must still reach the caller — a swallowed write error
        // would mean a session that silently never persists.
        await expectLater(
          store.save(token: _token, nonce: _nonce),
          throwsA(isA<Exception>()),
        );

        // Regression guard: memory must not run ahead of the disk. If save()
        // ever assigns/notifies before awaiting the write again, the router
        // sends the user to /home on a session that was never stored, and the
        // next cold start throws them straight back out.
        expect(store.token, isNull);
        expect(store.nonce, isNull);
        expect(store.isLoggedIn, isFalse);
        expect(notifications, 0);
        expect(recording.data, isEmpty);
      },
    );

    test(
      'a failed re-save keeps the previous session and stays silent',
      () async {
        final _RecordingSecureStore recording = _RecordingSecureStore();
        final TokenStore store = TokenStore(recording);
        addTearDown(store.dispose);
        attach(store);

        await store.save(token: _token, nonce: _nonce);
        recording.failWrites = true;

        await expectLater(
          store.save(token: 'token-2', nonce: 'nonce-2'),
          throwsA(isA<Exception>()),
        );

        // A refresh that could not be stored leaves the old, still-valid
        // credentials in place rather than half-swapping them.
        expect(store.token, _token);
        expect(store.nonce, _nonce);
        expect(store.isLoggedIn, isTrue);
        expect(notifications, 1, reason: 'only the successful save notified');
        expect(recording.data[_tokenKey], _token);
        expect(recording.data[_nonceKey], _nonce);
      },
    );

    test(
      'a failure on the nonce write leaves memory untouched and silent',
      () async {
        final _RecordingSecureStore recording = _RecordingSecureStore()
          ..failWrites = true
          ..failOnlyKey = _nonceKey;
        final TokenStore store = TokenStore(recording);
        addTearDown(store.dispose);
        attach(store);

        await expectLater(
          store.save(token: _token, nonce: _nonce),
          throwsA(isA<Exception>()),
        );

        // The token did land on disk, but a token with no nonce is not a usable
        // session: memory must not claim one and no listener may be woken.
        expect(recording.data[_tokenKey], _token);
        expect(recording.data.containsKey(_nonceKey), isFalse);
        expect(store.token, isNull);
        expect(store.nonce, isNull);
        expect(store.isLoggedIn, isFalse);
        expect(notifications, 0);
      },
    );
  });

  group('restore', () {
    test(
      'loads an existing session — app restarted, user still logged in',
      () async {
        // Storage was populated by a previous run of the app.
        await secureStore.write(_tokenKey, _token);
        await secureStore.write(_nonceKey, _nonce);

        final TokenStore fresh = TokenStore(secureStore);
        addTearDown(fresh.dispose);
        attach(fresh);

        expect(fresh.isLoggedIn, isFalse, reason: 'not restored yet');

        await fresh.restore();

        expect(fresh.token, _token);
        expect(fresh.nonce, _nonce);
        expect(fresh.isLoggedIn, isTrue);
        expect(notifications, 1);
        expect(loggedInAtNotify, <bool>[true]);
        expect(tokenAtNotify, <String?>[_token]);
        expect(nonceAtNotify, <String?>[_nonce]);
      },
    );

    test('reads exactly the two expected keys and writes nothing', () async {
      final _RecordingSecureStore recording = _RecordingSecureStore();
      final TokenStore store = TokenStore(recording);
      addTearDown(store.dispose);

      await store.restore();

      expect(recording.reads, <String>[_tokenKey, _nonceKey]);
      // A restore that writes back would rewrite the keychain on every cold
      // start — and would clobber storage with nulls when there is no session.
      expect(recording.writes, isEmpty);
      expect(recording.deletes, isEmpty);
    });

    test('leaves the store logged out when storage is empty', () async {
      await tokenStore.restore();

      expect(tokenStore.token, isNull);
      expect(tokenStore.nonce, isNull);
      expect(tokenStore.isLoggedIn, isFalse);
      // Still notifies: the router has to leave the splash/redirect gate even
      // when the answer is "no session".
      expect(notifications, 1);
      expect(loggedInAtNotify, <bool>[false]);
    });

    test(
      'reads the two keys independently — a half-written session is visible',
      () async {
        // save() writes the token and the nonce as two separate awaits, so a
        // crash between them can leave a token on disk with no nonce. This pins
        // what restore() actually reports in that case: the nonce really is
        // null, while isLoggedIn (which only inspects the token) still says
        // true. See the production note about validating the pair — if that is
        // ever fixed, this expectation is the one that must be updated.
        await secureStore.write(_tokenKey, _token);

        await tokenStore.restore();

        expect(tokenStore.token, _token);
        expect(tokenStore.nonce, isNull);
        expect(tokenStore.isLoggedIn, isTrue);
      },
    );

    test('swallows a throwing secure store and ends up logged out', () async {
      final TokenStore store = TokenStore(const _ThrowingSecureStore());
      addTearDown(store.dispose);
      attach(store);

      await expectLater(store.restore(), completes);

      expect(store.token, isNull);
      expect(store.nonce, isNull);
      expect(store.isLoggedIn, isFalse);
      expect(notifications, 1);
      expect(loggedInAtNotify, <bool>[false]);
    });

    test('a failed restore does not keep a previously held token', () async {
      final _RecordingSecureStore recording = _RecordingSecureStore();
      final TokenStore store = TokenStore(recording);
      addTearDown(store.dispose);
      attach(store);

      // The process really does hold a session: this save succeeded.
      await store.save(token: _token, nonce: _nonce);
      expect(store.isLoggedIn, isTrue);
      expect(store.token, _token);
      expect(notifications, 1);

      // Now the keychain goes away underneath us.
      recording.failReads = true;
      await store.restore();

      // restore() swallows the error and must wipe the stale in-memory copy,
      // not keep reporting a session it can no longer prove exists.
      expect(store.isLoggedIn, isFalse);
      expect(store.token, isNull);
      expect(store.nonce, isNull);
      expect(notifications, 2, reason: 'save + restore');
      expect(loggedInAtNotify, <bool>[true, false]);
    });
  });

  group('clear', () {
    test('empties memory and storage, notifies once, logs out', () async {
      await tokenStore.save(token: _token, nonce: _nonce);
      expect(notifications, 1);

      await tokenStore.clear();

      expect(tokenStore.token, isNull);
      expect(tokenStore.nonce, isNull);
      expect(tokenStore.isLoggedIn, isFalse);
      expect(notifications, 2, reason: 'save + clear');
      expect(loggedInAtNotify, <bool>[true, false]);
      expect(tokenAtNotify, <String?>[_token, null]);
      expect(nonceAtNotify, <String?>[_nonce, null]);
      expect(await secureStore.read(_tokenKey), isNull);
      expect(await secureStore.read(_nonceKey), isNull);
    });

    test(
      'does NOT notify when already empty — guards the redirect loop',
      () async {
        final _RecordingSecureStore recording = _RecordingSecureStore();
        final TokenStore store = TokenStore(recording);
        addTearDown(store.dispose);
        attach(store);

        await store.clear();
        await store.clear();

        expect(notifications, 0);
        expect(
          recording.deletes,
          isEmpty,
          reason: 'no-op must not hit storage',
        );
        expect(store.isLoggedIn, isFalse);
      },
    );

    test('a second clear after a real clear is also a silent no-op', () async {
      await tokenStore.save(token: _token, nonce: _nonce);
      await tokenStore.clear();
      expect(notifications, 2);

      await tokenStore.clear();

      expect(notifications, 2, reason: 'second clear must stay silent');
    });

    test('deletes exactly the two expected keys', () async {
      final _RecordingSecureStore recording = _RecordingSecureStore();
      final TokenStore store = TokenStore(recording);
      addTearDown(store.dispose);

      await store.save(token: _token, nonce: _nonce);
      await store.clear();

      expect(recording.deletes, <String>[_tokenKey, _nonceKey]);
      expect(recording.data, isEmpty);
    });
  });

  group('full lifecycle', () {
    test('login, restart, logout, restart again', () async {
      await tokenStore.save(token: _token, nonce: _nonce);

      // Restart #1 — session survives.
      final TokenStore afterFirstRestart = TokenStore(secureStore);
      addTearDown(afterFirstRestart.dispose);
      await afterFirstRestart.restore();
      expect(afterFirstRestart.isLoggedIn, isTrue);
      expect(afterFirstRestart.token, _token);

      await afterFirstRestart.clear();

      // Restart #2 — logout must survive too.
      final TokenStore afterLogout = TokenStore(secureStore);
      addTearDown(afterLogout.dispose);
      await afterLogout.restore();
      expect(afterLogout.isLoggedIn, isFalse);
      expect(afterLogout.token, isNull);
      expect(afterLogout.nonce, isNull);
    });
  });
}
