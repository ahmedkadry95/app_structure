import 'dart:async';

import 'package:app_structure/core/network/failures.dart';
import 'package:app_structure/core/network/result.dart';
import 'package:app_structure/features/auth/data/models/session_model.dart';
import 'package:app_structure/features/auth/domain/entities/session.dart';
import 'package:app_structure/features/auth/domain/usecases/get_session_usecase.dart';
import 'package:app_structure/features/auth/domain/usecases/login_usecase.dart';
import 'package:app_structure/features/auth/domain/usecases/logout_usecase.dart';
import 'package:app_structure/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:app_structure/features/auth/presentation/cubit/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockGetSessionUseCase extends Mock implements GetSessionUseCase {}

/// نفس شكل رد اللوجين الحقيقي من Prism: Array فيه Object واحد،
/// وكل المفاتيح lowercase.
const List<Map<String, dynamic>> kLoginResponseBody = <Map<String, dynamic>>[
  <String, dynamic>{
    'sid': 'SID-0001-FAKE',
    'username': 'placeholder.user',
    'employeename': 'Placeholder Employee',
    'token': 'placeholder-token-not-a-real-credential',
    'nonce': 'placeholder-nonce',
    'subsidiaryname': 'Main Subsidiary',
    'storename': 'Store 01',
    'basecurrencycodealpha': 'SAR',
  },
];

/// بيانات دخول وهمية — مفيش أي كريدنشيال حقيقي في التستات.
const String kUsername = 'placeholder.user';
const String kPassword = 'placeholder-password';

void main() {
  late MockLoginUseCase loginUseCase;
  late MockLogoutUseCase logoutUseCase;
  late MockGetSessionUseCase getSessionUseCase;
  late SessionModel session;

  AuthCubit buildCubit() => AuthCubit(
    loginUseCase: loginUseCase,
    logoutUseCase: logoutUseCase,
    getSessionUseCase: getSessionUseCase,
  );

  void stubLogin(Result<Session> result) {
    when(
      () => loginUseCase(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubGetSession(Result<Session> result) {
    when(getSessionUseCase.call).thenAnswer((_) async => result);
  }

  setUp(() {
    loginUseCase = MockLoginUseCase();
    logoutUseCase = MockLogoutUseCase();
    getSessionUseCase = MockGetSessionUseCase();
    session = SessionModel.fromResponse(kLoginResponseBody);
    when(logoutUseCase.call).thenAnswer((_) async {});
  });

  group('AuthCubit', () {
    test('initial state is AuthInitial', () {
      final AuthCubit cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state, const AuthInitial());
      expect(cubit.state, isA<AuthInitial>());
    });

    // كل التستات اللي تحت بتعتمد على إن الحالات دي بتتقارن بالقيمة.
    // لو حد فضّى `props` في `AuthState` أو `Failure`، التستات دي هتقع
    // بدل ما التستات التانية تعدي وهي مش بتفحص حاجة.
    test('states and failures compare by value, not just by type', () {
      expect(const AuthInitial(), isNot(const AuthLoading()));
      expect(
        const AuthError(OfflineFailure()),
        isNot(const AuthError(NetworkFailure())),
      );
      expect(
        const AuthError(
          ServerFailure(errorCode: 'Security.5', statusCode: 403),
        ),
        isNot(
          const AuthError(
            ServerFailure(errorCode: 'Security.2', statusCode: 401),
          ),
        ),
      );
      expect(
        AuthSuccess(session),
        isNot(AuthSuccess(SessionModel.fromJson(const <String, dynamic>{}))),
      );
    });

    group('login', () {
      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthSuccess] with the returned session '
        'when the use case succeeds',
        setUp: () => stubLogin(Success<Session>(session)),
        build: buildCubit,
        act: (AuthCubit cubit) =>
            cubit.login(username: kUsername, password: kPassword),
        expect: () => <AuthState>[const AuthLoading(), AuthSuccess(session)],
        verify: (AuthCubit cubit) {
          final AuthState state = cubit.state;
          expect(state, isA<AuthSuccess>());
          // الجلسة اللي وصلت للـ UI هي بالظبط اللي رجعت من الـ use case،
          // بكل حقولها — مش نسخة ناقصة.
          expect(
            (state as AuthSuccess).session.token,
            'placeholder-token-not-a-real-credential',
          );
          expect(state.session.username, 'placeholder.user');
          expect(state.session.employeeName, 'Placeholder Employee');
          expect(state.session.currency, 'SAR');
          expect(state.session.sid, 'SID-0001-FAKE');
          expect(state.session.nonce, 'placeholder-nonce');
          expect(state.session.subsidiaryName, 'Main Subsidiary');
          expect(state.session.storeName, 'Store 01');
        },
      );

      test(
        'forwards the exact username and password to LoginUseCase',
        () async {
          stubLogin(Success<Session>(session));
          final AuthCubit cubit = buildCubit();
          addTearDown(cubit.close);

          await cubit.login(username: kUsername, password: kPassword);

          verify(
            () => loginUseCase(username: kUsername, password: kPassword),
          ).called(1);
          verifyNever(getSessionUseCase.call);
          verifyNever(logoutUseCase.call);
        },
      );

      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthError(InvalidCredentialsFailure)] '
        'on bad credentials (Security.2 / HTTP 401)',
        setUp: () =>
            stubLogin(const Failed<Session>(InvalidCredentialsFailure())),
        build: buildCubit,
        act: (AuthCubit cubit) =>
            cubit.login(username: kUsername, password: kPassword),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(InvalidCredentialsFailure()),
        ],
        verify: (AuthCubit cubit) {
          expect(cubit.state, isA<AuthError>());
          expect(
            (cubit.state as AuthError).failure,
            isA<InvalidCredentialsFailure>(),
          );
        },
      );

      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthError(OfflineFailure)] when offline',
        setUp: () => stubLogin(const Failed<Session>(OfflineFailure())),
        build: buildCubit,
        act: (AuthCubit cubit) =>
            cubit.login(username: kUsername, password: kPassword),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(OfflineFailure()),
        ],
        verify: (AuthCubit cubit) {
          expect((cubit.state as AuthError).failure, isA<OfflineFailure>());
        },
      );

      blocTest<AuthCubit, AuthState>(
        'passes ServerFailure through untouched, keeping errorCode '
        'and statusCode for the UI',
        setUp: () => stubLogin(
          const Failed<Session>(
            ServerFailure(
              serverMessage: 'Authorization failed: Invalid Auth token.',
              errorCode: 'Security.5',
              statusCode: 403,
            ),
          ),
        ),
        build: buildCubit,
        act: (AuthCubit cubit) =>
            cubit.login(username: kUsername, password: kPassword),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(
            ServerFailure(
              serverMessage: 'Authorization failed: Invalid Auth token.',
              errorCode: 'Security.5',
              statusCode: 403,
            ),
          ),
        ],
        // بنفحص الحقول واحد واحد كمان، مش بس المساواة: لو `props` اتفضت
        // في `ServerFailure` أو `AuthError` المساواة هتعدي غلط.
        verify: (AuthCubit cubit) {
          final Failure failure = (cubit.state as AuthError).failure;
          expect(failure, isA<ServerFailure>());
          final ServerFailure serverFailure = failure as ServerFailure;
          expect(
            serverFailure.serverMessage,
            'Authorization failed: Invalid Auth token.',
          );
          expect(serverFailure.errorCode, 'Security.5');
          expect(serverFailure.statusCode, 403);
        },
      );

      blocTest<AuthCubit, AuthState>(
        'a failed login after a successful one still emits '
        '[AuthLoading, AuthError] and drops the old session',
        setUp: () => stubLogin(const Failed<Session>(NetworkFailure())),
        build: buildCubit,
        seed: () => AuthSuccess(session),
        act: (AuthCubit cubit) =>
            cubit.login(username: kUsername, password: kPassword),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(NetworkFailure()),
        ],
      );

      test('sits in AuthLoading while the request is still in flight, so the '
          'spinner is on screen for the whole call', () async {
        // Completer = الريكوست معلّق تحت أمرنا، فنقدر نبص على الحالة
        // في نص الرحلة. لو الـ cubit عمل emit(AuthLoading) بعد الـ await
        // التست ده هيقع.
        final Completer<Result<Session>> pendingLogin =
            Completer<Result<Session>>();
        when(
          () => loginUseCase(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => pendingLogin.future);

        final AuthCubit cubit = buildCubit();
        addTearDown(cubit.close);

        final Future<void> loginCall = cubit.login(
          username: kUsername,
          password: kPassword,
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, const AuthLoading());

        pendingLogin.complete(Success<Session>(session));
        await loginCall;

        expect(cubit.state, AuthSuccess(session));
      });

      blocTest<AuthCubit, AuthState>(
        'a second login re-runs the full cycle, emitting four states',
        setUp: () => stubLogin(Success<Session>(session)),
        build: buildCubit,
        act: (AuthCubit cubit) async {
          await cubit.login(username: kUsername, password: kPassword);
          await cubit.login(username: 'other.user', password: kPassword);
        },
        expect: () => <AuthState>[
          const AuthLoading(),
          AuthSuccess(session),
          const AuthLoading(),
          AuthSuccess(session),
        ],
        verify: (_) {
          verify(
            () => loginUseCase(
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          ).called(2);
        },
      );
    });

    group('loadSession', () {
      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthSuccess] when the stored token is valid',
        setUp: () => stubGetSession(Success<Session>(session)),
        build: buildCubit,
        act: (AuthCubit cubit) => cubit.loadSession(),
        expect: () => <AuthState>[const AuthLoading(), AuthSuccess(session)],
        verify: (_) {
          verify(getSessionUseCase.call).called(1);
          verifyNever(
            () => loginUseCase(
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          );
        },
      );

      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthError(UnauthorizedFailure)] when the token '
        'is dead (Security.5 / HTTP 403)',
        setUp: () =>
            stubGetSession(const Failed<Session>(UnauthorizedFailure())),
        build: buildCubit,
        act: (AuthCubit cubit) => cubit.loadSession(),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(UnauthorizedFailure()),
        ],
        verify: (AuthCubit cubit) {
          expect(
            (cubit.state as AuthError).failure,
            isA<UnauthorizedFailure>(),
          );
          // مسح التوكن شغل SessionExpiredInterceptor مش الـ cubit.
          verifyNever(logoutUseCase.call);
        },
      );

      blocTest<AuthCubit, AuthState>(
        'emits [AuthLoading, AuthError(OfflineFailure)] when there is '
        'no connection at startup',
        setUp: () => stubGetSession(const Failed<Session>(OfflineFailure())),
        build: buildCubit,
        act: (AuthCubit cubit) => cubit.loadSession(),
        expect: () => <AuthState>[
          const AuthLoading(),
          const AuthError(OfflineFailure()),
        ],
      );
    });

    group('logout', () {
      blocTest<AuthCubit, AuthState>(
        'calls LogoutUseCase exactly once and emits [AuthInitial]',
        build: buildCubit,
        seed: () => AuthSuccess(session),
        act: (AuthCubit cubit) => cubit.logout(),
        expect: () => <AuthState>[const AuthInitial()],
        verify: (AuthCubit cubit) {
          verify(logoutUseCase.call).called(1);
          verifyNever(
            () => loginUseCase(
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          );
          expect(cubit.state, const AuthInitial());
        },
      );

      blocTest<AuthCubit, AuthState>(
        'resets to AuthInitial even when the previous state was AuthError',
        build: buildCubit,
        seed: () => const AuthError(UnauthorizedFailure()),
        act: (AuthCubit cubit) => cubit.logout(),
        expect: () => <AuthState>[const AuthInitial()],
      );

      test('stays in AuthSuccess until the token is actually cleared, then '
          'emits AuthInitial exactly once', () async {
        // الترتيب هنا مهم أمنياً: لو الـ cubit عمل emit(AuthInitial) الأول
        // وبعدين استنى مسح التوكن، الـ router هيروح للوجين والتوكن لسه
        // موجود. الـ Completer بيمسك الـ logout معلّق عشان نتأكد.
        final Completer<void> pendingLogout = Completer<void>();
        stubLogin(Success<Session>(session));
        when(logoutUseCase.call).thenAnswer((_) => pendingLogout.future);

        final AuthCubit cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.login(username: kUsername, password: kPassword);
        expect(cubit.state, AuthSuccess(session));

        final List<AuthState> emitted = <AuthState>[];
        final StreamSubscription<AuthState> sub = cubit.stream.listen(
          emitted.add,
        );
        addTearDown(sub.cancel);

        final Future<void> logoutCall = cubit.logout();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, AuthSuccess(session));
        expect(emitted, isEmpty);

        pendingLogout.complete();
        await logoutCall;
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, const AuthInitial());
        expect(emitted, <AuthState>[const AuthInitial()]);
      });

      test('emits AuthError(UnexpectedFailure) instead of rethrowing when '
          'LogoutUseCase fails (keychain locked)', () async {
        // لو الاستثناء طلع من `logout()` هيوصل للـ onPressed ويولّع
        // الشاشة. ولو الـ cubit راح لـ AuthInitial هنقول للمستخدم إنه خرج
        // والتوكن لسه على الديسك — الاتنين غلط.
        when(
          logoutUseCase.call,
        ).thenAnswer((_) => Future<void>.error(Exception('keychain locked')));

        final AuthCubit cubit = buildCubit();
        addTearDown(cubit.close);

        final List<AuthState> emitted = <AuthState>[];
        final StreamSubscription<AuthState> sub = cubit.stream.listen(
          emitted.add,
        );
        addTearDown(sub.cancel);

        await expectLater(cubit.logout(), completes);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, const AuthError(UnexpectedFailure()));
        expect(cubit.state, isNot(const AuthInitial()));
        expect(emitted, <AuthState>[const AuthError(UnexpectedFailure())]);
        verify(logoutUseCase.call).called(1);
      });

      test('catches a synchronous throw from LogoutUseCase too, not just a '
          'rejected Future', () async {
        when(logoutUseCase.call).thenThrow(Exception('boom'));

        final AuthCubit cubit = buildCubit();
        addTearDown(cubit.close);

        await expectLater(cubit.logout(), completes);

        expect(cubit.state, const AuthError(UnexpectedFailure()));
      });
    });

    // الحارس `_emitIfOpen`: كل الـ emits بتحصل بعد await، والمستخدم ممكن
    // يقفل الشاشة والريكوست لسه في الهوا. من غير الحارس الـ Cubit بيرمي
    // StateError('Cannot emit new states after calling close') جوه زون
    // مالهاش هاندلر.
    group('emitting after close', () {
      test('a login that lands after the cubit closed neither throws '
          'StateError nor emits AuthSuccess', () async {
        final Completer<Result<Session>> pendingLogin =
            Completer<Result<Session>>();
        when(
          () => loginUseCase(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) => pendingLogin.future);

        final AuthCubit cubit = buildCubit();
        final List<AuthState> emitted = <AuthState>[];
        final StreamSubscription<AuthState> sub = cubit.stream.listen(
          emitted.add,
        );
        addTearDown(sub.cancel);

        final Future<void> loginCall = cubit.login(
          username: kUsername,
          password: kPassword,
        );
        await Future<void>.delayed(Duration.zero);
        expect(emitted, <AuthState>[const AuthLoading()]);

        await cubit.close();
        pendingLogin.complete(Success<Session>(session));

        await expectLater(loginCall, completes);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.isClosed, isTrue);
        expect(emitted, <AuthState>[const AuthLoading()]);
        expect(cubit.state, const AuthLoading());
      });

      test(
        'a login that FAILS after the cubit closed does not throw StateError '
        'either',
        () async {
          final Completer<Result<Session>> pendingLogin =
              Completer<Result<Session>>();
          when(
            () => loginUseCase(
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          ).thenAnswer((_) => pendingLogin.future);

          final AuthCubit cubit = buildCubit();
          final Future<void> loginCall = cubit.login(
            username: kUsername,
            password: kPassword,
          );
          await Future<void>.delayed(Duration.zero);

          await cubit.close();
          pendingLogin.complete(const Failed<Session>(NetworkFailure()));

          await expectLater(loginCall, completes);

          expect(cubit.state, const AuthLoading());
        },
      );

      test('a loadSession that lands after the cubit closed does not throw '
          'StateError', () async {
        final Completer<Result<Session>> pendingSession =
            Completer<Result<Session>>();
        when(getSessionUseCase.call).thenAnswer((_) => pendingSession.future);

        final AuthCubit cubit = buildCubit();
        final Future<void> loadCall = cubit.loadSession();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state, const AuthLoading());

        await cubit.close();
        pendingSession.complete(Success<Session>(session));

        await expectLater(loadCall, completes);

        expect(cubit.isClosed, isTrue);
        expect(cubit.state, const AuthLoading());
      });

      test('a logout that lands after the cubit closed does not throw '
          'StateError, on either the success or the failure path', () async {
        final Completer<void> pendingLogout = Completer<void>();
        when(logoutUseCase.call).thenAnswer((_) => pendingLogout.future);

        final AuthCubit okCubit = buildCubit();
        final Future<void> okLogout = okCubit.logout();
        await Future<void>.delayed(Duration.zero);
        await okCubit.close();
        pendingLogout.complete();
        await expectLater(okLogout, completes);
        expect(okCubit.state, const AuthInitial());

        final Completer<void> failingLogout = Completer<void>();
        when(logoutUseCase.call).thenAnswer((_) => failingLogout.future);

        final AuthCubit errCubit = buildCubit();
        final Future<void> errLogout = errCubit.logout();
        await Future<void>.delayed(Duration.zero);
        await errCubit.close();
        failingLogout.completeError(Exception('keychain locked'));
        await expectLater(errLogout, completes);
        expect(errCubit.state, const AuthInitial());
      });
    });
  });
}
