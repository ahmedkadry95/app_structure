// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Qahwa Sofa';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginUsernameRequired => 'Enter your username';

  @override
  String get loginPasswordRequired => 'Enter your password';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeLogout => 'Sign out';

  @override
  String get homeCompany => 'Company';

  @override
  String get homeBranch => 'Branch';

  @override
  String get homeCurrency => 'Currency';

  @override
  String get homeSessionId => 'Session ID';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonOffline => 'No internet connection';

  @override
  String get errorOffline => 'No internet connection — check your network';

  @override
  String get errorNetwork => 'Could not reach the server';

  @override
  String get errorSessionExpired =>
      'Your session expired, please sign in again';

  @override
  String get errorInvalidCredentials => 'Incorrect username or password';

  @override
  String get errorServer => 'The server returned an error';

  @override
  String get errorUnexpected => 'Something went wrong';
}
