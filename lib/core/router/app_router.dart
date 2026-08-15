import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/home_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../network/token_store.dart';

abstract class Routes {
  static const login = '/login';
  static const home = '/';
}

/// الـ redirect بيبص على التوكن بس.
/// ولأن الـ TokenStore ChangeNotifier، أي مسح للتوكن (زي لما السيرفر
/// يقول Security.5) بيرجّع المستخدم للوجين لوحده من غير أي كود في الشاشات.
GoRouter createRouter(TokenStore tokenStore) => GoRouter(
  refreshListenable: tokenStore,
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.login,
      builder: (_, _) => const LoginScreen(),
    ),
    GoRoute(
      path: Routes.home,
      builder: (_, _) => const HomeScreen(),
    ),
  ],
  redirect: (_, state) {
    final onLoginPage = state.matchedLocation == Routes.login;

    if (!tokenStore.isLoggedIn) return onLoginPage ? null : Routes.login;
    return onLoginPage ? Routes.home : null;
  },
);
