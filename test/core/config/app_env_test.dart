import 'package:app_structure/core/config/app_config.dart';
import 'package:app_structure/core/config/app_env.dart';
import 'package:flutter_test/flutter_test.dart';

/// حارس على جدول البيئات.
///
/// أهم حاجة هنا: لو حد بدّل الـ URLs بالغلط (أو خلّى الاتنين واحد)،
/// التست بيفشل — بدل ما نكتشف إن نسخة "تجريبي" بتكتب على الإنتاج
/// بعد ما تكون وصلت لجهاز مختبر.
void main() {
  group('جدول البيئات', () {
    test('كل بيئة ليها سيرفر مختلف', () {
      expect(
        AppEnv.staging.baseUrl,
        isNot(AppEnv.production.baseUrl),
        reason: 'لو الاتنين نفس السيرفر يبقى الـ flavors شكلية',
      );
    });

    test('الإنتاج على الدومين الحقيقي', () {
      expect(AppEnv.production.baseUrl, 'https://qahwa-sofa.com/api');
    });

    test('التجريبي مش على دومين الإنتاج', () {
      expect(AppEnv.staging.baseUrl, contains('staging'));
      expect(AppEnv.staging.baseUrl, isNot(contains('://qahwa-sofa.com')));
    });

    test('كل الـ URLs عبر HTTPS', () {
      for (final env in AppEnv.values) {
        expect(env.baseUrl, startsWith('https://'), reason: env.name);
      }
    });
  });

  group('القدرات', () {
    test('أدوات المطوّرين مقفولة في الإنتاج بس', () {
      expect(AppEnv.production.showDevTools, isFalse);
      expect(AppEnv.staging.showDevTools, isTrue);
    });

    test('الإنتاج من غير شريط، والتجريبي بشريط', () {
      expect(AppEnv.production.banner, isNull);
      expect(AppEnv.staging.banner, isNotNull);
      expect(AppEnv.staging.banner, isNotEmpty);
    });

    test('isLive / isStaging متسقين', () {
      expect(AppEnv.production.isProduction, isTrue);
      expect(AppEnv.production.isStaging, isFalse);
      expect(AppEnv.staging.isStaging, isTrue);
      expect(AppEnv.staging.isProduction, isFalse);
    });
  });

  test('من غير --flavor الحارس بيضرب بدل ما يشتغل بصمت على الإنتاج', () {
    // الاختبارات بتشتغل من غير flavor، فـ AppEnv.current بيوصل لـ
    // _missingFlavor() والـ assert بيضرب (في الـ debug بس).
    // ده مقصود: المطور اللي نسي --flavor لازم يعرف فوراً.
    expect(
      () => AppConfig.baseUrl,
      throwsA(isA<AssertionError>()),
      reason:
          'لو ده عدى بصمت، يبقى ممكن حد يشتغل على الإنتاج من غير ما ياخد باله',
    );
  });
}
