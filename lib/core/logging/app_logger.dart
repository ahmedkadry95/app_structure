import 'package:talker_flutter/talker_flutter.dart';

import '../config/app_env.dart';

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
      // التاريخ هو اللي شاشة /logs بتقرا منه — فمربوط بنفس الشرط
      settings: TalkerSettings(useHistory: AppEnv.current.showDevTools),
      logger: TalkerLogger(
        settings: TalkerLoggerSettings(
          level: AppEnv.current.showDevTools ? LogLevel.debug : LogLevel.error,
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
