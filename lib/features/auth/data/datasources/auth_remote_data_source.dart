import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../models/session_model.dart';

/// بينفذ الريكوستات وبيحول JSON → Model.
/// مفيش try/catch هنا عمداً — الـ exceptions بتتمسك في `.toResult()`.
class AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSource(this.dio);

  Future<SessionModel> login({
    required String username,
    required String password,
  }) async {
    final res = await dio.get<dynamic>(
      '/security/login',
      queryParameters: {
        'usr': username,
        'pwd': password,
        'ws': AppConfig.workstation,
      },
    );
    return SessionModel.fromResponse(res.data);
  }

  Future<SessionModel> getSession() async {
    final res = await dio.get<dynamic>('/security/session');
    return SessionModel.fromResponse(res.data);
  }
}
