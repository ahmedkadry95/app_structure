import 'app_env.dart';

class AppConfig {
  const AppConfig._();

  static String get baseUrl => AppEnv.current.baseUrl;

  static const String workstation = String.fromEnvironment(
    'WORKSTATION',
    defaultValue: 'webclient',
  );
}
