import 'package:equatable/equatable.dart';

/// أنواع الفشل اللي التطبيق بيفهمها.
///
/// مهم: مفيش نص واجهة مستخدم هنا عمداً. الطبقة دي بترجّع **نوع** بس،
/// والترجمة بتحصل في الـ presentation (شوف `FailureL10n`). كده لو ضفنا
/// لغة تانية مش هنلمس طبقة الشبكة خالص.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// مفيش شبكة خالص — الريكوست اتقطع قبل ما يطلع
class OfflineFailure extends Failure {
  const OfflineFailure();
}

/// فيه شبكة بس السيرفر مش راد أو الاتصال قطع في النص
class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// التوكن بايظ أو الجلسة خلصت (Security.5) → رجّع المستخدم للوجين
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
}

/// اسم مستخدم أو باسورد غلط (Security.2)
class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure();
}

/// أي خطأ تاني من السيرفر.
///
/// `serverMessage` هو نص جاي من الـ backend نفسه — بنعرضه زي ما هو لأنه
/// بيوصف حالة مش عارفينها مسبقاً. لو فاضي، الـ presentation بتستخدم
/// رسالة عامة مترجمة.
class ServerFailure extends Failure {
  final String? serverMessage;
  final String? errorCode;
  final int? statusCode;

  const ServerFailure({this.serverMessage, this.errorCode, this.statusCode});

  @override
  List<Object?> get props => [serverMessage, errorCode, statusCode];
}

/// حاجة مكانتش في الحسبان (parsing فشل، bug في الكود)
class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
