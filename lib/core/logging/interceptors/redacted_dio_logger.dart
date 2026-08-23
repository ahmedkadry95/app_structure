import 'package:dio/dio.dart';

import '../app_logger.dart';
import 'pretty_api_logger.dart';

List<Interceptor> buildNetworkLoggers(AppLogger logger) => [
  PrettyApiLogger(logger),
];
