import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_env.dart';
import 'core/di/injection.dart';
import 'core/l10n/l10n_extension.dart';
import 'core/locale/locale_cubit.dart';
import 'core/network/token_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'l10n/app_localizations.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final _router = createRouter(sl<TokenStore>());

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<LocaleCubit>()),
        BlocProvider(create: (_) => sl<AuthCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) => MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: _router,
          locale: locale,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.localizationsDelegates,
          builder: (context, child) => _EnvBanner(
            child: OfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

class _EnvBanner extends StatelessWidget {
  final Widget child;

  const _EnvBanner({required this.child});

  @override
  Widget build(BuildContext context) {
    final label = AppEnv.current.banner;
    if (label == null) return child;

    return Banner(
      message: label,
      location: BannerLocation.topEnd,
      color: Colors.orange.shade700,
      child: child,
    );
  }
}
