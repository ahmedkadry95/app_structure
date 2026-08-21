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

GoRouter createRouter(TokenStore tokenStore) => GoRouter(
  refreshListenable: tokenStore,
  initialLocation: Routes.home,
  // في الـ debug بس — الـ observer بيتنادى مع كل تنقّل، ومفيش داعي
  // يشتغل في الإنتاج طالما الـ logger أصلاً مش هيطبع مستوى info
  observers: [if (kDebugMode) TalkerRouteObserver(sl<AppLogger>().talker)],
  routes: [
    GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
    GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    if (kDebugMode)
      GoRoute(
        path: Routes.logs,
        builder: (_, _) => TalkerScreen(talker: sl<AppLogger>().talker),
      ),
  ],
  redirect: (context, state) {
    if (state.matchedLocation == Routes.logs) return null;
    final onLoginPage = state.matchedLocation == Routes.login;
    if (!tokenStore.isLoggedIn) return onLoginPage ? null : Routes.login;
    return onLoginPage ? Routes.home : null;
  },
);
