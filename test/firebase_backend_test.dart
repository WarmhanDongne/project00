import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/firebase/services/realtime_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_Core());
  setUpAll(() async {
    await Firebase.initializeApp();
    await Firebase.initializeApp(
      name: FirebaseBackend.appName,
      options: const FirebaseOptions(
        apiKey: 'local-emulator-only',
        appId: '1:1:ios:1',
        messagingSenderId: '1',
        projectId: FirebaseBackend.projectId,
        databaseURL: 'https://demo-mosigame-e13-default-rtdb.firebaseio.com',
      ),
    );
  });

  test('all SDK accessors and the shared database use the selected app', () {
    final expected = FirebaseBackend.isLocal
        ? FirebaseBackend.appName
        : '[DEFAULT]';
    expect(FirebaseBackend.auth.app.name, expected);
    expect(FirebaseBackend.firestore.app.name, expected);
    expect(FirebaseBackend.functions.app.name, expected);
    expect(FirebaseBackend.database.app.name, expected);
    expect(RealtimeDatabaseService.instance.app.name, expected);
    expect(
      identical(RealtimeDatabaseService.instance, FirebaseBackend.database),
      isTrue,
    );
    expect(
      identical(
        FirebaseBackend.functions,
        FirebaseFunctions.instanceFor(
          app: FirebaseBackend.app,
          region: 'asia-northeast3',
        ),
      ),
      isTrue,
    );
  });

  test('invalid modes and non-debug local builds fail closed', () {
    expect(
      () => FirebaseBackend.validate(backend: 'locla'),
      throwsArgumentError,
    );
    expect(
      () => FirebaseBackend.validate(backend: 'local', debug: false),
      throwsStateError,
    );
    expect(
      () => FirebaseBackend.validate(backend: 'server', debug: false),
      returnsNormally,
    );
    expect(
      () => FirebaseBackend.validate(backend: 'local', debug: true),
      returnsNormally,
    );
    for (final host in [
      'http://localhost',
      'localhost:9000',
      ' localhost',
      '',
    ]) {
      if (host.isEmpty) continue;
      expect(
        () => FirebaseBackend.validate(emulatorHost: host),
        throwsArgumentError,
      );
    }
  });

  test(
    'Android and iOS simulator defaults point back to the host computer',
    () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(FirebaseBackend.host, '10.0.2.2');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(FirebaseBackend.host, '127.0.0.1');
    },
  );

  test('app and games cannot accidentally bypass backend selection', () {
    final violations = <String>[];
    for (final directory in [Directory('lib'), Directory('packages')]) {
      for (final file
          in directory.listSync(recursive: true).whereType<File>()) {
        final path = file.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart') ||
            path.contains('/test/') ||
            !path.contains('/lib/') && !path.startsWith('lib/') ||
            path.endsWith('/firebase_backend.dart') ||
            path.endsWith('/firebase_options.dart')) {
          continue;
        }
        if (RegExp(
          r'Firebase(Auth|Firestore|Database|Storage)\.instance\b|FirebaseFunctions\.instance(?:For)?\b|Firebase\.app\(',
        ).hasMatch(file.readAsStringSync())) {
          violations.add(path);
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Use FirebaseBackend or an explicitly selected app.',
    );
  });
}

class _Core extends MockFirebaseApp {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );
}
