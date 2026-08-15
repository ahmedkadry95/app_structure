import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// الواجهة الوحيدة للوج في المشروع.
///
/// غلاف رفيع حوالين Talker — نفس المبدأ بتاع `SecureStore`: باقي الكود
/// مايستوردش المكتبة مباشرة، فلو بدّلناها يوم التغيير في ملف واحد.
class AppLogger {
  final Talker talker;

  AppLogger(this.talker);

  /// في الـ debug: كل حاجة، وبنحتفظ بتاريخ عشان شاشة اللوجات.
  /// في الإنتاج: الأخطاء بس — لوج كتير بيستهلك ذاكرة وأداء وبيزوّد
  /// احتمال إن حاجة حساسة تتسرّب من غير ما ناخد بالنا.
  factory AppLogger.create() => AppLogger(
    TalkerFlutter.init(
      // التاريخ في الـ debug بس — هو اللي شاشة /logs بتقرا منه.
      // الـ analyzer شايف kDebugMode = true فبيقول إن القيمة زيادة، لكنها
      // في الإنتاج بتبقى false فعلاً — شيلها ونحتفظ بتاريخ اللوجات في الرام.
      // ignore: avoid_redundant_argument_values
      settings: TalkerSettings(useHistory: kDebugMode),
      logger: TalkerLogger(
        settings: TalkerLoggerSettings(
          level: kDebugMode ? LogLevel.debug : LogLevel.error,
          // الافتراضي 110 — بيرسم إطار عرضه شاشة كاملة حوالين كل سطر
          maxLineWidth: 64,
        ),
      ),
    ),
  );

  void debug(String message) => talker.debug(message);

  void info(String message) => talker.info(message);

  void warning(String message) => talker.warning(message);

  void error(String message, [Object? exception, StackTrace? stackTrace]) =>
      talker.error(message, exception, stackTrace);

  /// للأخطاء اللي مش متوقعة خالص (crash handlers)
  void handle(Object exception, [StackTrace? stackTrace, String? message]) =>
      talker.handle(exception, stackTrace, message);

  /// لوجر مش بيطلّع حاجة — الافتراضي في الاختبارات.
  factory AppLogger.silent() =>
      AppLogger(Talker(settings: TalkerSettings(enabled: false)));
}

AppLogger? _global;

/// اللوجر العام.
///
/// **ليه global والمشروع كله شغال بـ get_it؟** لأن فيه حتة واحدة مالهاش
/// constructor تحقن فيها حاجة: `Future.toResult()` — دي extension، وهي
/// بالظبط المكان اللي كل أخطاء المشروع بتعدي منه. البديل كان إننا نمرّر
/// اللوجر في كل نداء ونضيّع بساطة `.toResult()` اللي بنينا الطبقة عليها.
///
/// الافتراضي صامت، فالاختبارات مش محتاجة تظبط حاجة.
AppLogger get appLog => _global ??= AppLogger.silent();

set appLog(AppLogger logger) => _global = logger;
