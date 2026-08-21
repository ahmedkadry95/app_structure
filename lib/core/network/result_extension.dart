import 'package:dio/dio.dart';

import 'dio_error_handler.dart';
import 'failures.dart';
import 'result.dart';

extension ResultX<T> on Future<T> {
  Future<Result<T>> toResult() async {
    try {
      return Success(await this);
    } on DioException catch (e) {
      return Failed(handleDioError(e));
    } catch (e, stackTrace) {
      return const Failed(UnexpectedFailure());
    }
  }
}
