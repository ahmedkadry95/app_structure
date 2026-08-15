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

  /// بتتنادى لما التطبيق يفتح وفيه توكن محفوظ — بتتأكد إنه لسه صالح.
  /// لو مات، الـ SessionExpiredInterceptor بيمسحه والـ router بيرجّع للوجين.
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
      // مسح التوكن فشل (الـ keychain مقفول مثلاً). منسيبش الاستثناء يطلع
      // للـ onPressed، وفي نفس الوقت منقولش للمستخدم إنه خرج وهو لسه داخل.
      appLog.error('فشل تسجيل الخروج', e, stackTrace);
      _emitIfOpen(const AuthError(UnexpectedFailure()));
    }
  }

  /// كل الـ emits هنا بتحصل بعد await، والمستخدم ممكن يكون قافل الشاشة
  /// في النص — من غير الحارس ده الـ Cubit بيرمي StateError.
  void _emitIfOpen(AuthState state) {
    if (!isClosed) emit(state);
  }
}
