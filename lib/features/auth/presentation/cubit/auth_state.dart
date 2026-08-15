import 'package:equatable/equatable.dart';

import '../../../../core/network/failures.dart';
import '../../domain/entities/session.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSuccess extends AuthState {
  final Session session;
  const AuthSuccess(this.session);

  @override
  List<Object?> get props => [session];
}

/// شايلة الـ Failure كاملة مش String —
/// عشان الـ UI يقدر يفرّق بين الأنواع ويترجمها بنفسه
class AuthError extends AuthState {
  final Failure failure;
  const AuthError(this.failure);

  @override
  List<Object?> get props => [failure];
}
