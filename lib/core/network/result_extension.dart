import 'package:dio/dio.dart';

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
      return Error(handleDioError(e));
    } catch (_) {
      return Error(const ServerFailure('حصل خطأ غير متوقع'));
    }
  }
}
