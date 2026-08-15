import '../../../../core/network/result.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class GetSessionUseCase {
  final AuthRepository repository;
  GetSessionUseCase(this.repository);

  Future<Result<Session>> call() => repository.getSession();
}
