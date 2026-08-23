import '../../../../core/network/result.dart';
import '../entities/session.dart';

abstract class AuthRepository {
  Future<Result<Session>> login({
    required String username,
    required String password,
  });

  Future<Result<Session>> getSession();

  Future<void> logout();
}
