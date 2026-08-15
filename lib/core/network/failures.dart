import 'prism_error.dart';

sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('في مشكلة في الاتصال بالإنترنت');
}

/// التوكن بايظ أو الجلسة خلصت (Security.5) → رجّع المستخدم للوجين
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('انتهت الجلسة، سجّل دخول تاني');
}

/// اسم مستخدم أو باسورد غلط (Security.2)
class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure()
      : super('اسم المستخدم أو كلمة المرور غير صحيحة');
}

/// أي خطأ تاني من السيرفر — شايل الـ PrismError الكامل لو اتقرا
class ServerFailure extends Failure {
  final int? statusCode;
  final PrismError? error;
  const ServerFailure(super.message, {this.statusCode, this.error});
}
