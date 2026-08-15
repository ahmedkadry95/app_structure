import 'package:bloc/bloc.dart';
import 'package:talker_flutter/talker_flutter.dart';

import 'app_logger.dart';

/// سطر واحد لكل تغيير حالة.
///
/// `TalkerBlocObserver` بيكتب 6 سطور للحاجة الواحدة:
/// ```
/// AuthCubit changed
/// CURRENT state:
/// AuthInitial()
/// NEXT state:
/// AuthLoading()
/// ```
/// اللي إحنا محتاجينه فعلاً هو: `AuthCubit  AuthInitial → AuthLoading`.
///
/// ملحوظة أمنية: بنطبع `nextState.toString()`، و`Session.toString` بيخفي
/// التوكن — لولاه كان هيتكتب هنا مع كل لوجين ناجح.
class CompactBlocObserver extends BlocObserver {
  final AppLogger logger;
  const CompactBlocObserver(this.logger);

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    logger.talker.logCustom(
      _BlocLog(
        '${bloc.runtimeType}  ${change.currentState} → ${change.nextState}',
        logKey: 'bloc',
        color: AnsiPen()..xterm(140),
      ),
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    logger.error('خطأ جوه ${bloc.runtimeType}', error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

class _BlocLog extends TalkerLog {
  _BlocLog(super.message, {required String logKey, required AnsiPen color})
    : super(title: 'bloc', key: logKey, pen: color);
}
