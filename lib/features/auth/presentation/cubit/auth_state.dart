import '../../../../core/network/failures.dart';
import '../../domain/entities/session.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  String toString() => 'AuthInitial';
}

class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  String toString() => 'AuthLoading';
}

class AuthSuccess extends AuthState {
  final Session session;
  const AuthSuccess(this.session);

  @override
  String toString() =>
      'AuthSuccess(${session.username} — ${session.subsidiaryName}/${session.storeName})';
}

/// شايلة الـ Failure كاملة مش String بس —
/// عشان الـ UI يقدر يفرّق بين الأنواع (بيانات غلط ≠ جلسة خلصت ≠ نت واقع)
class AuthError extends AuthState {
  final Failure failure;
  const AuthError(this.failure);

  @override
  String toString() => 'AuthError(${failure.runtimeType}: ${failure.message})';
}
