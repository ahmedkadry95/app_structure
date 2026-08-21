import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_session_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../locale/locale_cubit.dart';
import '../logging/app_logger.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../network/token_store.dart';
import '../storage/secure_store.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final logger = AppLogger.create();
  appLog = logger;
  sl.registerSingleton(logger);

  // Core
  sl.registerLazySingleton<SecureStore>(
    () => const FlutterSecureStore(FlutterSecureStorage()),
  );
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton(() => NetworkInfo(sl()));

  sl.registerSingleton(await SharedPreferences.getInstance());
  sl.registerFactory(() => LocaleCubit(sl()));

  final tokenStore = TokenStore(sl());
  await tokenStore.restore();
  sl.registerSingleton(tokenStore);

  sl.registerLazySingleton(
    () => ApiClient(tokenStore: sl(), networkInfo: sl(), logger: sl()),
  );

  // Auth — Data
  sl.registerLazySingleton(() => AuthRemoteDataSource(sl<ApiClient>().dio));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );

  // Auth — Domain
  sl.registerFactory(() => LoginUseCase(sl()));
  sl.registerFactory(() => LogoutUseCase(sl()));
  sl.registerFactory(() => GetSessionUseCase(sl()));

  // Auth — Presentation
  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      logoutUseCase: sl(),
      getSessionUseCase: sl(),
    ),
  );
}
