import 'package:dio/dio.dart';

import '../app_logger.dart';
import 'pretty_api_logger.dart';

/// الـ interceptors المسؤولة عن لوج الشبكة.
///
/// واحد بس دلوقتي — [PrettyApiLogger] — بيتعامل مع كل الريكوستات بنفس
/// الشكل، والتنقية جواه مش على مستوى الفلترة.
List<Interceptor> buildNetworkLoggers(AppLogger logger) => [
  PrettyApiLogger(logger),
];
