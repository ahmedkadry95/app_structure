import '../../../../core/network/result.dart';
import '../entities/session.dart';

/// العقد — الـ domain بيقول محتاج إيه من غير ما يعرف Dio ولا Prism.
abstract class AuthRepository {
  Future<Result<Session>> login({
    required String username,
    required String password,
  });

  Future<Result<Session>> getSession();

  Future<void> logout();
}
