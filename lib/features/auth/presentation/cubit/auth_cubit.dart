import 'package:bloc/bloc.dart';

import '../../domain/usecases/login_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final LoginUseCase loginUseCase;
  AuthCubit(this.loginUseCase) : super(const AuthInitial());

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
}
