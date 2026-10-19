import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iPadOS 26은 고정 가로 호환 모드 대신 resizable scene을 사용한다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final storyboard = File(
      'ios/Runner/Base.lproj/Main.storyboard',
    ).readAsStringSync();
    final sceneDelegate = File(
      'ios/Runner/SceneDelegate.swift',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final orientations = _plistArray(
      plist,
      'UISupportedInterfaceOrientations~ipad',
    );

    expect(orientations, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(orientations, contains('UIInterfaceOrientationLandscapeRight'));
    expect(orientations, contains('UIInterfaceOrientationPortrait'));
    expect(orientations, contains('UIInterfaceOrientationPortraitUpsideDown'));
    expect(plist, contains('<key>UIRequiresFullScreen</key>'));
    expect(plist, contains('<key>UIRequiresFullScreen</key>\n\t<true/>'));
    expect(
      plist,
      contains('<key>UIRequiresFullScreenIgnoredStartingWithVersion</key>'),
    );
    expect(
      plist,
      contains(
        '<key>UIRequiresFullScreenIgnoredStartingWithVersion</key>\n'
        '\t<string>26.0</string>',
      ),
    );
    expect(storyboard, contains('customClass="FlutterViewController"'));
    expect(sceneDelegate, isNot(contains('requestGeometryUpdate')));
    expect(main, contains('AppOrientation.allowPlatformRotation()'));
    expect(main, contains('AppSystemUi.enterTabletPlatformFullscreen()'));
  });

  test('Android는 전체화면 task와 태블릿 시작 가로 방향을 요청한다', () {
    final defaultResources = File(
      'android/app/src/main/res/values/bools.xml',
    ).readAsStringSync();
    final tabletResources = File(
      'android/app/src/main/res/values-sw600dp/bools.xml',
    ).readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/warmhandongne/msg/MainActivity.kt',
    ).readAsStringSync();

    expect(
      defaultResources,
      contains('<bool name="is_tablet_device">false</bool>'),
    );
    expect(
      tabletResources,
      contains('<bool name="is_tablet_device">true</bool>'),
    );
    expect(manifest, contains('android:appCategory="game"'));
    expect(manifest, contains('android:resizeableActivity="false"'));
    expect(manifest, contains('android:supportsPictureInPicture="false"'));
    expect(
      manifest,
      contains('android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY'),
    );

    final directionRequest = activity.indexOf(
      'requestedOrientation = '
      'ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE',
    );
    final flutterStartup = activity.indexOf(
      'super.onCreate(savedInstanceState)',
    );
    expect(directionRequest, greaterThanOrEqualTo(0));
    expect(flutterStartup, greaterThan(directionRequest));
  });
}

String _plistArray(String plist, String key) {
  final keyIndex = plist.indexOf('<key>$key</key>');
  expect(keyIndex, greaterThanOrEqualTo(0), reason: '$key 키가 없습니다.');
  final arrayStart = plist.indexOf('<array>', keyIndex);
  final arrayEnd = plist.indexOf('</array>', arrayStart);
  expect(arrayStart, greaterThan(keyIndex), reason: '$key 배열 시작이 없습니다.');
  expect(arrayEnd, greaterThan(arrayStart), reason: '$key 배열 끝이 없습니다.');
  return plist.substring(arrayStart, arrayEnd);
}
