import 'package:bloc/bloc.dart';

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
    result.when(
      success: (session) => emit(AuthSuccess(session)),
      error: (failure) => emit(AuthError(failure)),
    );
  }

  /// بتتنادى لما التطبيق يفتح وفيه توكن محفوظ — بتتأكد إنه لسه صالح.
  /// لو مات، الـ SessionExpiredInterceptor بيمسحه والـ router بيرجّع للوجين.
  Future<void> loadSession() async {
    emit(const AuthLoading());
    final result = await getSessionUseCase();
    result.when(
      success: (session) => emit(AuthSuccess(session)),
      error: (failure) => emit(AuthError(failure)),
    );
  }

  Future<void> logout() async {
    await logoutUseCase();
    emit(const AuthInitial());
  }
}
