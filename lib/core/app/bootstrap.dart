import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:project00/firebase/firebase_options.dart';
import 'package:project00/core/app/app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLinks = AppLinks();
  await dotenv.load(fileName: '.env.dev');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Uri? initialEmailLink;
  try {
    initialEmailLink = await appLinks.getInitialLink();
  } catch (error) {
    debugPrint('초기 이메일 링크를 읽지 못했습니다: $error');
  }
  runApp(
    App(emailLinks: appLinks.uriLinkStream, initialEmailLink: initialEmailLink),
  );
}
