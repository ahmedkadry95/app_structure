import 'package:flutter/widgets.dart';

import '../network/failures.dart';
import 'l10n_extension.dart';


extension FailureL10n on Failure {
  String localize(BuildContext context) {

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
