import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'dio_error_handler.dart';
import 'failures.dart';
import 'result.dart';

/// نقطة الترجمة الوحيدة في المشروع:
/// أي Future بيرمي exceptions → Result نظيفة.
/// الـ try/catch مكتوب هنا مرة واحدة بس في المشروع كله.
extension ResultX<T> on Future<T> {
  Future<Result<T>> toResult() async {
    try {
      return Success(await this);
    } on DioException catch (e) {
      // مفيش لوج هنا عن قصد: الـ PrettyApiLogger سجّل الريكوست بالفعل
      // بالـ status وسبب السيرفر، والـ BlocObserver هيسجّل الحالة الناتجة.
      // تسجيل تالت هنا كان بيكرر نفس المعلومة تلات مرات.
      return Failed(handleDioError(e));
    } catch (e, stackTrace) {
      // مهم: بنمسك الـ stack trace هنا. الـ catch ده هو آخر حاجة بين
      // أي bug في التطبيق وبين اختفاءه للأبد — من غير التسجيل ده،
      // FormatException من parsing أو TypeError بيبقى مجرد
      // "حصل خطأ غير متوقع" على الشاشة وخلاص.
      appLog.error('exception غير متوقع في toResult', e, stackTrace);
      return const Failed(UnexpectedFailure());
    }
  }
}
