import 'package:flutter/widgets.dart';

import '../network/failures.dart';
import 'l10n_extension.dart';

/// بيحوّل نوع الـ Failure لنص مترجم.
///
/// ده المكان الوحيد اللي بيربط بين طبقة الشبكة والنص اللي المستخدم بيقراه.
extension FailureL10n on Failure {
  String localize(BuildContext context) {
    // متغير محلي هنا مش `context.l10n` في كل فرع — النداء بيعمل lookup
    // في شجرة الويدجتس، ومفيش داعي نكرره 6 مرات في switch واحد.
    final l = context.l10n;

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
