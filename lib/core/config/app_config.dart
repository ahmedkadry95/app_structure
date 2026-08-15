class AppConfig {
  const AppConfig._();

  /// بيتغيّر وقت البناء عشان نقدر نشاور على staging:
  ///   flutter run --dart-define=BASE_URL=https://staging.example.com/api
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://qahwa-sofa.com/api',
  );

  /// الـ workstation اللي بنسجل بيه دخول على Prism
  static const String workstation = String.fromEnvironment(
    'WORKSTATION',
    defaultValue: 'webclient',
  );
}
