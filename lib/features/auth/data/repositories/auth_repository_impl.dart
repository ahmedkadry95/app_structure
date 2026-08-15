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
  }) => remote.login(username: username, password: password).then((session) {
    tokenStore.token = session.token;
    tokenStore.nonce = session.nonce;
    return session;
  }).toResult();

  @override
  Future<Result<Session>> getSession() => remote.getSession().toResult();

  @override
  void logout() => tokenStore.clear();
}
