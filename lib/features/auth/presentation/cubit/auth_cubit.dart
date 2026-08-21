import 'package:bloc/bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/failures.dart';
import '../../domain/usecases/get_session_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetSessionUseCase getSessionUseCase;

  AuthCubit({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getSessionUseCase,
  }) : super(const AuthInitial());

  Future<void> login({
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());
    final result = await loginUseCase(username: username, password: password);
    _emitIfOpen(result.when(success: AuthSuccess.new, failure: AuthError.new));
  }

  Future<void> loadSession() async {
    emit(const AuthLoading());
    final result = await getSessionUseCase();
    _emitIfOpen(result.when(success: AuthSuccess.new, failure: AuthError.new));
  }

  Future<void> logout() async {
    try {
      await logoutUseCase();
      _emitIfOpen(const AuthInitial());
    } catch (e, stackTrace) {
      appLog.error('فشل تسجيل الخروج', e, stackTrace);
      _emitIfOpen(const AuthError(UnexpectedFailure()));
    }
  }

  void _emitIfOpen(AuthState state) {
    if (!isClosed) emit(state);
  }
}
