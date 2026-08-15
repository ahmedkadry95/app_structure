import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

import 'app.dart';
import 'core/di/injection.dart' as di;
import 'core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await di.init();
  } catch (e, stackTrace) {
    // من غير الحماية دي، أي فشل في التهيئة (keychain، prefs) بيدي
    // شاشة سودا من غير أي رسالة
    appLog.error('فشلت تهيئة التطبيق', e, stackTrace);
    runApp(_StartupFailure(error: e));
    return;
  }

  // كل خطأ في الـ widgets وكل خطأ خارج الـ Flutter zone بيتسجّل
  FlutterError.onError = (details) {
    appLog.handle(details.exception, details.stack, details.library);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.handle(error, stack, 'خطأ غير ممسوك');
    return true;
  };

  // كل تغيير حالة في أي Cubit بيتسجّل.
  //
  // `printChanges` لازم تتفعّل بإيدينا: الافتراضي بيسجّل الـ transitions
  // بتاعة الـ Bloc، والـ Cubit مبيعملش transitions — بيعمل changes. من غير
  // السطر ده الـ observer بيتركّب وميسجّلش ولا حاجة.
  //
  // ملحوظة: `Session.toString` بيخفي التوكن — لولاه كان هيتطبع هنا
  Bloc.observer = TalkerBlocObserver(
    talker: appLog.talker,
    settings: const TalkerBlocLoggerSettings(
      printChanges: true,
      printCreations: true,
      printClosings: true,
    ),
  );

  runApp(const App());
}

/// شاشة بديلة لما التهيئة نفسها تفشل — أحسن من شاشة سودا
class _StartupFailure extends StatelessWidget {
  final Object error;
  const _StartupFailure({required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'مقدرناش نشغّل التطبيق',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
