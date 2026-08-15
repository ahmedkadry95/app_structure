import '../../../../core/network/result.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  Future<Result<Session>> call({
    required String username,
    required String password,
  }) =>
      repository.login(username: username, password: password);
}
