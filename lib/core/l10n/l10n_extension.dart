import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// اختصار لـ `AppL10n.of(context)`.
///
/// بنستخدم الـ context بتاع الويدجت نفسه عن قصد مش أي context عام:
/// `AppL10n.of` مش بس بيجيب القيمة — هو كمان بيسجّل الويدجت كمستمع
/// للـ `Localizations` اللي فوقه. ده اللي بيخلي الشاشة تعيد البناء
/// أول ما اللغة تتغير من الزرار.
///
/// أي حل "global" بيستخدم navigatorKey بيتخطى التسجيل ده، فبتلاقي
/// شاشات بتتغير وشاشات لأ.
extension L10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
