import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../features/auth/presentation/pages/home_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../di/injection.dart';
import '../logging/app_logger.dart';
import '../network/token_store.dart';

abstract class Routes {
  static const login = '/login';
  static const home = '/';
  static const logs = '/logs';
}

/// الـ redirect بيبص على التوكن بس.
/// ولأن الـ TokenStore ChangeNotifier، أي مسح للتوكن (زي لما السيرفر
/// يقول Security.5) بيرجّع المستخدم للوجين لوحده من غير أي كود في الشاشات.
GoRouter createRouter(TokenStore tokenStore) => GoRouter(
  refreshListenable: tokenStore,
  initialLocation: Routes.home,
  observers: [TalkerRouteObserver(sl<AppLogger>().talker)],
  routes: [
    GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    // شاشة اللوجات في الـ debug بس — في الإنتاج مفيش تاريخ محفوظ أصلاً
    if (kDebugMode)
      GoRoute(
        path: Routes.logs,
        builder: (_, _) => TalkerScreen(talker: sl<AppLogger>().talker),
      ),
  ],
  redirect: (_, state) {
    // شاشة اللوجات مش محتاجة جلسة — لازم توصلها والتطبيق واقع
    if (state.matchedLocation == Routes.logs) return null;

    final onLoginPage = state.matchedLocation == Routes.login;
    if (!tokenStore.isLoggedIn) return onLoginPage ? null : Routes.login;
    return onLoginPage ? Routes.home : null;
  },
);
