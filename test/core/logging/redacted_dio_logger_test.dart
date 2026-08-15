import 'package:app_structure/core/logging/app_logger.dart';
import 'package:app_structure/core/logging/interceptors/redacted_dio_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// اختبار end-to-end للوجر: بنشغّل ريكوست حقيقي على adapter وهمي،
/// وبنقرا **كل** اللي اتسجّل ونتأكد إن مفيش سر جواه.
void main() {
  const password = 'S3cr3t@Pass!';
  const token = 'C0A8C2695C034F05AD591FC0D6915E38';
  const loginPath = '/security/login';
  const productsPath = '/products';

  late Talker talker;
  late AppLogger logger;
  late Dio dio;
  late DioAdapter adapter;

  /// كل اللي اتسجّل كنص واحد — ده اللي هيوصل لكونسول المطور
  String allLogs() => talker.history.map((e) => e.generateTextMessage()).join();

  setUp(() {
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    logger = AppLogger(talker);
    dio = Dio(BaseOptions(baseUrl: 'https://qahwa-sofa.com/api'));
    adapter = DioAdapter(dio: dio);
    dio.interceptors.addAll(buildNetworkLoggers(logger));
  });

  test('الباسورد في الـ query string مبيوصلش اللوج', () async {
    adapter.onGet(
      loginPath,
      (server) => server.reply(200, [
        <String, dynamic>{'token': token},
      ]),
      queryParameters: <String, dynamic>{
        'usr': 'someone',
        'pwd': password,
        'ws': 'webclient',
      },
    );

    await dio.get<dynamic>(
      loginPath,
      queryParameters: <String, dynamic>{
        'usr': 'someone',
        'pwd': password,
        'ws': 'webclient',
      },
    );

    final logs = allLogs();
    expect(logs, isNotEmpty, reason: 'اللوجين لازم يتسجّل، بس بشكل آمن');
    expect(logs, isNot(contains(password)));
    expect(logs, isNot(contains('S3cr3t')));
    expect(logs, contains('***'));
  });

  test('الباسورد مبيتسربش حتى لما اللوجين يفشل', () async {
    adapter.onGet(
      loginPath,
      (server) => server.reply(401, <String, dynamic>{'errors': '[]'}),
      queryParameters: <String, dynamic>{'pwd': password},
    );

    await dio
        .get<dynamic>(
          loginPath,
          queryParameters: <String, dynamic>{'pwd': password},
        )
        .catchError(
          (Object _) => Response<dynamic>(requestOptions: RequestOptions()),
        );

    expect(allLogs(), isNot(contains(password)));
  });

  test('هيدر Auth-Session مبيتطبعش', () async {
    adapter.onGet(
      productsPath,
      (server) => server.reply(200, <String, dynamic>{'ok': true}),
    );

    await dio.get<dynamic>(
      productsPath,
      options: Options(headers: <String, dynamic>{'Auth-Session': token}),
    );

    final logs = allLogs();
    expect(logs, isNot(contains(token)));
    expect(logs, isNot(contains('C0A8C269')));
  });

  test('الريكوستات العادية بتتسجّل كاملة — اللوج لازم يفضل مفيد', () async {
    adapter.onGet(
      productsPath,
      (server) => server.reply(200, <String, dynamic>{'ok': true}),
      queryParameters: <String, dynamic>{'page': '2'},
    );

    await dio.get<dynamic>(
      productsPath,
      queryParameters: <String, dynamic>{'page': '2'},
    );

    final logs = allLogs();
    expect(logs, contains(productsPath));
    expect(logs, isNot(contains('***')));
  });
}
