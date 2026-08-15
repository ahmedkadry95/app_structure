import 'dart:convert';

import 'package:app_structure/core/network/failures.dart';
import 'package:app_structure/core/network/network_info.dart';
import 'package:app_structure/core/network/result.dart';
import 'package:app_structure/core/network/result_extension.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// بيبني نفس الـ envelope اللي Prism بيرجعه فعلياً:
/// `errors` بتبقى **String جواها JSON array** (double-encoded).
Map<String, dynamic> prismErrorEnvelope({
  required String errorCode,
  required String errorMsg,
  required int httpCode,
  required String httpMessage,
}) {
  final String doubleEncodedErrors = jsonEncode(<Map<String, dynamic>>[
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
  ]);

  return <String, dynamic>{
    'name': null,
    'metatype': null,
    'comment': null,
    'translationid': null,
    'errors': doubleEncodedErrors,
    'data': <dynamic>[],
  };
}

DioException badResponseException({
  required Map<String, dynamic> body,
  required int statusCode,
  String path = '/security/login',
}) {
  final RequestOptions options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: body,
    ),
  );
}

/// بيرجّع الـ Type نفسه عشان نقارن runtimeType بدقة (مش بـ isA اللي بيقبل
/// الـ subtypes بسبب الـ covariance).
Type typeOf<T>() => T;

DioException offlineException() {
  final RequestOptions options = RequestOptions(path: '/security/session');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: const OfflineException(),
  );
}

void main() {
  group('Result construction and accessors', () {
    test('Success carries its data and reports isSuccess', () {
      const Result<String> result = Success<String>('prism');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 'prism');
      expect(result.failureOrNull, isNull);
      expect((result as Success<String>).data, 'prism');
    });

    test('Failed carries its failure and is not successful', () {
      const Result<String> result = Failed<String>(OfflineFailure());

      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, const OfflineFailure());
      expect((result as Failed<String>).failure, const OfflineFailure());
    });

    test(
      'failureOrNull keeps the exact failure subtype, not just any Failure',
      () {
        const Result<int> result = Failed<int>(
          ServerFailure(
            serverMessage: 'Authorization failed: Invalid Auth token.',
            errorCode: 'Security.9',
            statusCode: 500,
          ),
        );

        final Failure? failure = result.failureOrNull;
        expect(failure, isA<ServerFailure>());
        expect((failure! as ServerFailure).errorCode, 'Security.9');
        expect((failure as ServerFailure).statusCode, 500);
        // Equatable لازم يفرّق بين نوعين فشل حتى لو الاتنين props فاضية
        expect(const OfflineFailure() == const NetworkFailure(), isFalse);
      },
    );

    test(
      'Success holding null is still a success (dataOrNull is ambiguous)',
      () {
        const Result<String?> result = Success<String?>(null);

        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull, isNull);
        expect(result.failureOrNull, isNull);
      },
    );
  });

  group('Result.when', () {
    test('routes to the success branch and returns its value', () {
      const Result<int> result = Success<int>(41);

      final String mapped = result.when<String>(
        success: (int data) => 'ok:${data + 1}',
        failure: (Failure f) => 'fail:$f',
      );

      expect(mapped, 'ok:42');
    });

    test('routes to the failure branch and returns its value', () {
      const Result<int> result = Failed<int>(InvalidCredentialsFailure());

      final String mapped = result.when<String>(
        success: (int data) => 'ok:$data',
        failure: (Failure f) => 'fail:${f.runtimeType}',
      );

      expect(mapped, 'fail:InvalidCredentialsFailure');
    });

    test('hands the failure branch the exact same Failure instance', () {
      // مش const عن قصد: الـ const بيتكانن (canonicalized) فـ identical كان
      // هينجح حتى لو الكود بنى Failure تانية بنفس القيم.
      final ServerFailure original = ServerFailure(
        serverMessage: 'Item not found in price list.',
        errorCode: 'Sales.17',
        statusCode: int.parse('500'),
      );
      final Result<int> result = Failed<int>(original);

      Failure? received;
      result.when<void>(
        success: (int _) {},
        failure: (Failure f) => received = f,
      );

      expect(identical(received, original), isTrue);
    });

    test('does not swallow an exception thrown inside a branch', () {
      const Result<int> result = Success<int>(1);

      expect(
        () => result.when<int>(
          success: (int _) => throw const FormatException('boom'),
          failure: (Failure _) => 0,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('invokes exactly one branch', () {
      int successCalls = 0;
      int failureCalls = 0;

      const Result<int> success = Success<int>(1);
      success.when<void>(
        success: (int _) => successCalls++,
        failure: (Failure _) => failureCalls++,
      );

      expect(successCalls, 1);
      expect(failureCalls, 0);

      const Result<int> failed = Failed<int>(NetworkFailure());
      failed.when<void>(
        success: (int _) => successCalls++,
        failure: (Failure _) => failureCalls++,
      );

      expect(successCalls, 1);
      expect(failureCalls, 1);
    });

    test('passes the real payload to the success branch', () {
      const Result<List<String>> result = Success<List<String>>(<String>[
        'sid',
        'token',
        'nonce',
      ]);

      final int length = result.when<int>(
        success: (List<String> data) => data.length,
        failure: (Failure _) => -1,
      );

      expect(length, 3);
    });
  });

  group('toResult() on a completing future', () {
    test('wraps the value in Success', () async {
      final Result<String> result = await Future<String>.value(
        'session-ok',
      ).toResult();

      expect(result, isA<Success<String>>());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 'session-ok');
      expect(result.failureOrNull, isNull);
    });

    test('does not swallow the value of an async computation', () async {
      Future<int> compute() async {
        await Future<void>.delayed(Duration.zero);
        return 7;
      }

      final Result<int> result = await compute().toResult();

      expect(result.dataOrNull, 7);
    });

    test('a future completing with null is a Success, not a failure', () async {
      final Result<String?> result = await Future<String?>.value().toResult();

      expect(result.isSuccess, isTrue);
      expect(result, isA<Success<String?>>());
      expect(result.dataOrNull, isNull);
      expect(result.failureOrNull, isNull);
    });
  });

  group('toResult() on DioException', () {
    test(
      'badResponse with Security.2 envelope maps to InvalidCredentialsFailure',
      () async {
        final DioException exception = badResponseException(
          body: prismErrorEnvelope(
            errorCode: 'Security.2',
            errorMsg: 'Authorization failed: Invalid user or password.',
            httpCode: 401,
            httpMessage: '401 - Unauthorized',
          ),
          statusCode: 401,
        );

        final Result<String> result = await Future<String>.error(
          exception,
        ).toResult();

        expect(result.isSuccess, isFalse);
        expect(result.dataOrNull, isNull);
        expect(result.failureOrNull, const InvalidCredentialsFailure());
        expect(result.failureOrNull, isNot(isA<ServerFailure>()));
        expect(result.failureOrNull, isNot(isA<UnexpectedFailure>()));
      },
    );

    test(
      'badResponse with Security.5 envelope maps to UnauthorizedFailure',
      () async {
        final DioException exception = badResponseException(
          body: prismErrorEnvelope(
            errorCode: 'Security.5',
            errorMsg: 'Authorization failed: Invalid Auth token.',
            httpCode: 403,
            httpMessage: '403 - Forbidden',
          ),
          statusCode: 403,
          path: '/security/session',
        );

        final Result<String> result = await Future<String>.error(
          exception,
        ).toResult();

        expect(result.failureOrNull, const UnauthorizedFailure());
      },
    );

    test(
      'badResponse with an unknown error code carries the server details',
      () async {
        final DioException exception = badResponseException(
          body: prismErrorEnvelope(
            errorCode: 'Sales.17',
            errorMsg: 'Item not found in price list.',
            httpCode: 500,
            httpMessage: '500 - Internal Server Error',
          ),
          statusCode: 500,
          path: '/sales/order',
        );

        final Result<String> result = await Future<String>.error(
          exception,
        ).toResult();

        expect(
          result.failureOrNull,
          const ServerFailure(
            serverMessage: 'Item not found in price list.',
            errorCode: 'Sales.17',
            statusCode: 500,
          ),
        );
      },
    );

    test(
      'OfflineException marker maps to OfflineFailure, not NetworkFailure',
      () async {
        final Result<String> result = await Future<String>.error(
          offlineException(),
        ).toResult();

        expect(result.failureOrNull, const OfflineFailure());
        expect(result.failureOrNull, isNot(const NetworkFailure()));
      },
    );

    test('timeouts map to NetworkFailure', () async {
      final RequestOptions options = RequestOptions(path: '/security/session');
      final Result<String> result = await Future<String>.error(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      ).toResult();

      expect(result.failureOrNull, const NetworkFailure());
    });
  });

  group('toResult() on non-Dio errors', () {
    test('FormatException maps to UnexpectedFailure', () async {
      final Result<String> result = await Future<String>.error(
        const FormatException('unexpected session payload'),
      ).toResult();

      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull, const UnexpectedFailure());
    });

    test('StateError maps to UnexpectedFailure', () async {
      final Result<int> result = await Future<int>.error(
        StateError('no element'),
      ).toResult();

      expect(result.failureOrNull, const UnexpectedFailure());
    });

    test(
      'an error thrown synchronously inside an async body is caught',
      () async {
        Future<int> boom() async {
          await Future<void>.delayed(Duration.zero);
          throw const FormatException('bad json');
        }

        final Result<int> result = await boom().toResult();

        expect(result.failureOrNull, const UnexpectedFailure());
      },
    );
  });

  group('toResult() preserves generics', () {
    test('Future<int> becomes Result<int>', () async {
      final Result<int> result = await Future<int>.value(5).toResult();

      expect(result, isA<Success<int>>());
      expect(result, isNot(isA<Success<String>>()));
      final int? data = result.dataOrNull;
      expect(data, 5);
    });

    test('Future<List<String>> becomes Result<List<String>>', () async {
      final Result<List<String>> result = await Future<List<String>>.value(
        <String>['a', 'b'],
      ).toResult();

      expect(result, isA<Success<List<String>>>());
      expect(result, isNot(isA<Success<List<int>>>()));
      final List<String>? data = result.dataOrNull;
      expect(data, <String>['a', 'b']);
    });

    test('Future<void> becomes Result<void> on success', () async {
      final Result<void> result = await Future<void>.value().toResult();

      expect(result.isSuccess, isTrue);
      expect(result.failureOrNull, isNull);
    });

    test('Future<void> becomes a Failed<void> on error', () async {
      final Result<void> result = await Future<void>.error(
        offlineException(),
      ).toResult();

      expect(result.isSuccess, isFalse);
      expect(result.failureOrNull, const OfflineFailure());
    });

    test('the Dio failure path keeps the exact source type argument', () async {
      final Result<int> result = await Future<int>.error(
        offlineException(),
      ).toResult();

      expect(result.runtimeType, typeOf<Failed<int>>());
    });

    test('the unexpected-error path collapses to Failed<Never> '
        '(const literal cannot carry T)', () async {
      final Result<int> result = await Future<int>.error(
        StateError('boom'),
      ).toResult();

      // Documents current behaviour: `return const Failed(UnexpectedFailure())`
      // in result_extension.dart cannot use the type variable T inside a const
      // expression, so the type argument degrades to Never. It stays
      // assignable to Result<int> because Failed is covariant, but the runtime
      // type argument is lost compared with the Dio path above.
      expect(
        result.runtimeType,
        typeOf<Failed<Never>>(),
        reason:
            'لو الاختبار ده فشل يبقى غالباً حد صلّح result_extension.dart '
            'وخلاها Failed<T>(const UnexpectedFailure()) — ده الإصلاح '
            'المطلوب، فعدّل التوقع هنا لـ typeOf<Failed<int>>() بدل ما '
            'ترجّع الكود.',
      );
      expect(result, isA<Failed<int>>());
      expect(result.failureOrNull, const UnexpectedFailure());
    });
  });
}
