import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:game_kit/firebase/firebase_options.dart';

/// Connect every service before any auth listener, clock or game service starts.
Future<void> initializeFirebaseBackend() async {
  FirebaseBackend.validate();
  if (!FirebaseBackend.isLocal) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  }

  const project = FirebaseBackend.projectId;
  await Firebase.initializeApp(
    name: FirebaseBackend.appName,
    options: FirebaseOptions(
      // Synthetic, not a credential. Native iOS Installations validates format
      // even when all Firebase services are connected to emulators.
      apiKey: 'A00000000000000000000000000000000000000',
      appId: defaultTargetPlatform == TargetPlatform.android
          ? '1:123456789012:android:00000000000000000000000000000000'
          : '1:123456789012:ios:00000000000000000000000000000000',
      messagingSenderId: '123456789012',
      projectId: project,
      databaseURL: 'https://$project-default-rtdb.firebaseio.com',
      storageBucket: '$project.appspot.com',
    ),
  );
  final host = FirebaseBackend.host;
  await FirebaseBackend.auth.useAuthEmulator(
    host,
    9099,
    automaticHostMapping: false,
  );
  FirebaseBackend.firestore.useFirestoreEmulator(
    host,
    8080,
    automaticHostMapping: false,
  );
  FirebaseBackend.database.useDatabaseEmulator(
    host,
    9000,
    automaticHostMapping: false,
  );
  FirebaseBackend.functions.useFunctionsEmulator(
    host,
    5001,
    automaticHostMapping: false,
  );
  await FirebaseStorage.instanceFor(
    app: FirebaseBackend.app,
  ).useStorageEmulator(host, 9199, automaticHostMapping: false);
  debugPrint('Firebase backend: LOCAL ($project at $host)');
}
