// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppL10nAr extends AppL10n {
  AppL10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'قهوة صوفا';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginUsername => 'اسم المستخدم';

  @override
  String get loginPassword => 'كلمة المرور';

  @override
  String get loginSubmit => 'دخول';

  @override
  String get loginUsernameRequired => 'اكتب اسم المستخدم';

  @override
  String get loginPasswordRequired => 'اكتب كلمة المرور';

  @override
  String get homeTitle => 'الرئيسية';

  @override
  String get homeLogout => 'خروج';

  @override
  String get homeCompany => 'الشركة';

  @override
  String get homeBranch => 'الفرع';

  @override
  String get homeCurrency => 'العملة';

  @override
  String get homeSessionId => 'رقم الجلسة';

  @override
  String get commonRetry => 'حاول تاني';

  @override
  String get commonOffline => 'مفيش اتصال بالإنترنت';

  @override
  String get errorOffline => 'مفيش اتصال بالإنترنت، اتأكد من الشبكة';

  @override
  String get errorNetwork => 'في مشكلة في الاتصال بالسيرفر';

  @override
  String get errorSessionExpired => 'انتهت الجلسة، سجّل دخول تاني';

  @override
  String get errorInvalidCredentials => 'اسم المستخدم أو كلمة المرور غير صحيحة';

  @override
  String get errorServer => 'حصل خطأ من السيرفر';

  @override
  String get errorUnexpected => 'حصل خطأ غير متوقع';
}
