import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// اللغة الحالية للتطبيق.
///
/// ده اللي بيخلي زرار تبديل اللغة يشتغل. `MaterialApp.locale` مجرد قيمة —
/// لازم حد يمسكها، ويعيد بناء الـ MaterialApp لما تتغير، ويحفظها عشان
/// تفضل بعد ما التطبيق يقفل. الكلاس ده بيعمل التلاتة.
class LocaleCubit extends Cubit<Locale> {
  static const _key = 'app_locale';
  static const fallback = Locale('ar');

  final SharedPreferences _prefs;

  LocaleCubit(this._prefs) : super(_readSaved(_prefs));

  /// بتتقرا وقت البناء — عشان أول إطار يترسم باللغة الصح من غير رفرفة
  static Locale _readSaved(SharedPreferences prefs) {
    final code = prefs.getString(_key);
    if (code == null) return fallback;
    return AppL10n.supportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => fallback,
    );
  }

  Future<void> setLocale(Locale locale) async {
    if (locale == state) return;
    await _prefs.setString(_key, locale.languageCode);
    emit(locale);
  }

  Future<void> toggle() =>
      setLocale(state.languageCode == 'ar' ? const Locale('en') : fallback);
}
