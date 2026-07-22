import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:project00/core/constants/firebase_constants.dart';

/// 프로젝트에서 사용하는 Firebase Realtime Database 진입점입니다.
abstract final class RealtimeDatabaseService {
  static final FirebaseDatabase instance = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: FirebaseConstants.realtimeDatabaseUrl,
  );
}
