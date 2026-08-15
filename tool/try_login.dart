// تجربة السايكل كاملة من الترمينال — من غير Flutter UI:
//
//   dart run --define=PRISM_USER=xxx --define=PRISM_PWD=yyy tool/try_login.dart
//
// بيشغّل نفس الـ Cubit اللي هيشتغل في التطبيق وبيطبع الـ states.
// البيانات بتتقرا من الـ environment — متكتبش كريدنشيالز في الملف ده.
// ignore_for_file: avoid_print

import 'package:app_structure/core/network/api_client.dart';
import 'package:app_structure/core/network/token_store.dart';
import 'package:app_structure/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:app_structure/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:app_structure/features/auth/domain/repositories/auth_repository.dart';
import 'package:app_structure/features/auth/domain/usecases/login_usecase.dart';
import 'package:app_structure/features/auth/presentation/cubit/auth_cubit.dart';

const _username = String.fromEnvironment('PRISM_USER');
const _password = String.fromEnvironment('PRISM_PWD');

Future<void> main() async {
  if (_username.isEmpty || _password.isEmpty) {
    print('لازم تمرر البيانات في الـ environment:');
    print('  dart run --define=PRISM_USER=xxx --define=PRISM_PWD=yyy '
        'tool/try_login.dart');
    return;
  }

  // التركيب اليدوي — في التطبيق الحقيقي get_it بيعمل ده
  final tokenStore = TokenStore();
  final apiClient = ApiClient(tokenStore: tokenStore);
  final remote = AuthRemoteDataSource(apiClient.dio);
  final AuthRepository repository = AuthRepositoryImpl(remote, tokenStore);
  final cubit = AuthCubit(LoginUseCase(repository));

  final sub = cubit.stream.listen((state) => print('   STATE → $state'));

  print('=== 1) لوجين ببيانات صحيحة ===');
  await cubit.login(username: _username, password: _password);
  await _flush();
  print('   التوكن اتخزن: ${tokenStore.token != null}');

  print('\n=== 2) لوجين بيوزر مش موجود ===');
  await cubit.login(username: 'not_a_real_user', password: 'whatever');
  await _flush();

  print('\n=== 3) endpoint محمي بتوكن بايظ ===');
  tokenStore.token = 'INVALID_TOKEN_FOR_TESTING';
  final result = await repository.getSession();
  result.when(
    success: (s) => print('   Session شغالة لـ ${s.username}'),
    error: (f) => print('   ${f.runtimeType}: ${f.message}'),
  );

  print('\n=== 4) نت واقع (دومين مش موجود) ===');
  final offline = ApiClient(tokenStore: TokenStore());
  offline.dio.options.baseUrl = 'https://definitely-not-a-real-host-12345.com';
  final offlineRepo =
      AuthRepositoryImpl(AuthRemoteDataSource(offline.dio), TokenStore());
  final offlineResult =
      await offlineRepo.login(username: 'x', password: 'x');
  offlineResult.when(
    success: (_) => print('   نجح؟!'),
    error: (f) => print('   ${f.runtimeType}: ${f.message}'),
  );

  await sub.cancel();
  await cubit.close();
}

/// بيسيب الـ event loop يلحق يطبع آخر state قبل السطر الجاي
Future<void> _flush() => Future<void>.delayed(Duration.zero);
