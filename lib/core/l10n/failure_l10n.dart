import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../network/failures.dart';

/// بيحوّل نوع الـ Failure لنص مترجم.
///
/// ده المكان الوحيد اللي بيربط بين طبقة الشبكة والنص اللي المستخدم بيقراه.
extension FailureL10n on Failure {
  String localize(BuildContext context) {
    final l = AppL10n.of(context);
    return switch (this) {
      OfflineFailure() => l.errorOffline,
      NetworkFailure() => l.errorNetwork,
      UnauthorizedFailure() => l.errorSessionExpired,
      InvalidCredentialsFailure() => l.errorInvalidCredentials,
      UnexpectedFailure() => l.errorUnexpected,
      // رسالة السيرفر بتوصف حالة إحنا مش عارفينها مسبقاً، فبنعرضها زي ما هي
      ServerFailure(:final serverMessage) =>
        serverMessage?.isNotEmpty == true ? serverMessage! : l.errorServer,
    };
  }
}
