import 'package:flutter/services.dart';

enum AppEnv {
  staging(
    baseUrl: 'https://staging.qahwa-sofa.com/api',
    showDevTools: true,
    banner: 'تجريبي',
  ),
  production(
    baseUrl: 'https://qahwa-sofa.com/api',
    showDevTools: false,
    banner: null,
  );

  const AppEnv({
    required this.baseUrl,
    required this.showDevTools,
    required this.banner,
  });

  final String baseUrl;

  final bool showDevTools;

  final String? banner;

  bool get isStaging => this == AppEnv.staging;

  bool get isProduction => this == AppEnv.production;

  static final AppEnv current = switch (appFlavor) {
    'staging' => AppEnv.staging,
    'production' => AppEnv.production,
    _ => _missingFlavor(),
  };

  static AppEnv _missingFlavor() {
    assert(
      false,
      'التطبيق اتبنى من غير --flavor.\n'
      'شغّله بـ: flutter run --flavor staging',
    );
    return AppEnv.production;
  }
}
