import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_env.dart';
import 'core/di/injection.dart' as di;
import 'core/logging/app_logger.dart';
import 'core/logging/compact_bloc_observer.dart';
import 'core/widgets/startup_failure.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await di.init();
  } catch (e, stackTrace) {
    appLog.error('Fail to initialize app', e, stackTrace);
    runApp(StartupFailure(error: e));
    return;
  }

  appLog.info('Flavor: ${AppEnv.current.name} · ${AppEnv.current.baseUrl}');

  FlutterError.onError = (details) {
    appLog.handle(details.exception, details.stack, details.library);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.handle(error, stack, 'Unhandled Exception');
    return true;
  };
  Bloc.observer = CompactBlocObserver(appLog);
  runApp(const App());
}
