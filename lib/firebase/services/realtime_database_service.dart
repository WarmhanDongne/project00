import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// 프로젝트에서 사용하는 Firebase Realtime Database 진입점입니다.
abstract final class RealtimeDatabaseService {
  static final FirebaseDatabase instance = _createInstance();

  static FirebaseDatabase _createInstance() {
    final app = Firebase.app();
    return FirebaseDatabase.instanceFor(
      app: app,
      // 별도 상수의 슬래시·리전 차이로 iOS 네이티브 인스턴스가 나뉘지 않도록
      // FlutterFire 초기화에 사용된 URL을 그대로 재사용합니다.
      databaseURL: app.options.databaseURL,
    );
  }
}
