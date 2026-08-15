import 'package:app_structure/core/logging/log_redaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// الـ tests دي بتحرس على حاجة واحدة: **الباسورد مايوصلش لوج أبداً**.
///
/// Prism بياخد الكريدنشيالز في الـ query string، فأي logger افتراضياً
/// بيطبعها. لو أي test هنا فشل، يبقى فيه تسريب حقيقي في الـ debug builds.
void main() {
  // نفس شكل ريكوست اللوجين الحقيقي
  final loginUri = Uri.parse(
    'https://qahwa-sofa.com/api/security/login'
    '?usr=some_user&pwd=S3cr3t%40Pass!&ws=webclient',
  );

  group('redactUri', () {
    test('الباسورد مبيظهرش في الناتج نهائياً', () {
      final result = redactUri(loginUri);

      expect(result, isNot(contains('S3cr3t')));
      expect(result, isNot(contains('Pass')));
      expect(result, contains('pwd=$redactedMark'));
    });

    test('اسم المستخدم كمان متخفي', () {
      final result = redactUri(loginUri);

      expect(result, isNot(contains('some_user')));
      expect(result, contains('usr=$redactedMark'));
    });

    test('القيم غير الحساسة بتفضل ظاهرة عشان اللوج يفضل مفيد', () {
      final result = redactUri(loginUri);

      expect(result, contains('ws=webclient'));
      expect(result, contains('/api/security/login'));
      expect(result, contains('qahwa-sofa.com'));
    });

    test('URI من غير query بيرجع زي ما هو', () {
      final uri = Uri.parse('https://qahwa-sofa.com/api/security/session');

      expect(redactUri(uri), uri.toString());
    });

    test('ريكوست عادي مفيهوش أسرار بيفضل كامل', () {
      final uri = Uri.parse(
        'https://qahwa-sofa.com/api/products?page=2&limit=50',
      );

      expect(redactUri(uri), contains('page=2'));
      expect(redactUri(uri), contains('limit=50'));
      expect(redactUri(uri), isNot(contains(redactedMark)));
    });

    test('المقارنة مش حساسة لحالة الحروف', () {
      final uri = Uri.parse('https://x.com/a?PWD=secret&Token=abc123');
      final result = redactUri(uri);

      expect(result, isNot(contains('secret')));
      expect(result, isNot(contains('abc123')));
    });

    test('كل مفتاح حساس معروف بيتخفي فعلاً', () {
      for (final key in sensitiveQueryKeys) {
        final uri = Uri.parse('https://x.com/a?$key=LEAKED_VALUE');

        expect(
          redactUri(uri),
          isNot(contains('LEAKED_VALUE')),
          reason: 'المفتاح "$key" في القايمة بس قيمته اتسربت',
        );
      }
    });
  });

  group('redactHeaders', () {
    test('التوكن بتاع Prism مبيظهرش', () {
      final headers = <String, dynamic>{
        'Auth-Session': 'C0A8C2695C034F05AD591FC0D6915E38',
        'Accept': 'application/json',
      };

      final result = redactHeaders(headers);

      expect(result['Auth-Session'], redactedMark);
      expect(result['Accept'], 'application/json');
      expect(result.toString(), isNot(contains('C0A8C269')));
    });

    test('كل هيدر حساس معروف بيتخفي فعلاً', () {
      for (final header in sensitiveHeaders) {
        final result = redactHeaders(<String, dynamic>{header: 'LEAKED_VALUE'});

        expect(
          result[header],
          redactedMark,
          reason: 'الهيدر "$header" في القايمة بس قيمته اتسربت',
        );
      }
    });

    test('الهيدرز العادية بتفضل زي ما هي', () {
      final headers = <String, dynamic>{
        'Accept-Language': 'ar',
        'Content-Type': 'application/json',
      };

      expect(redactHeaders(headers), headers);
    });
  });

  group('hasSensitiveQuery', () {
    test('ريكوست اللوجين متعلّم كحساس', () {
      expect(hasSensitiveQuery(loginUri), isTrue);
    });

    test('ريكوست عادي مش متعلّم', () {
      expect(
        hasSensitiveQuery(Uri.parse('https://x.com/api/products?page=1')),
        isFalse,
      );
    });

    test('URI من غير query مش متعلّم', () {
      expect(hasSensitiveQuery(Uri.parse('https://x.com/api/products')), false);
    });
  });
}
