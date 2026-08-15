import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const App());
}
