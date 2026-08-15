import '../../../../core/network/result.dart';
import '../../../../core/network/result_extension.dart';
import '../../../../core/network/token_store.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remote;
  final TokenStore tokenStore;

  AuthRepositoryImpl(this.remote, this.tokenStore);

  @override
  Future<Result<Session>> login({
    required String username,
    required String password,
  }) => remote.login(username: username, password: password).then((
    session,
  ) async {
    // نجاح اللوجين → نحفظ التوكن، والـ AuthInterceptor هيحقنه في كل
    // الريكوستات الجاية تلقائي
    await tokenStore.save(token: session.token, nonce: session.nonce);
    return session;
  }).toResult();

  @override
  Future<Result<Session>> getSession() => remote.getSession().toResult();

  @override
  Future<void> logout() => tokenStore.clear();
}
