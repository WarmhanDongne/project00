import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:project00/firebase_options.dart';
import 'package:project00/platform/app/app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}
