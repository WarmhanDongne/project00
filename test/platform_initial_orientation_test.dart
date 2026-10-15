import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iPad는 네이티브 시작 화면부터 가로 방향만 허용한다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final orientations = _plistArray(
      plist,
      'UISupportedInterfaceOrientations~ipad',
    );

    expect(orientations, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(orientations, contains('UIInterfaceOrientationLandscapeRight'));
    expect(orientations, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(
      orientations,
      isNot(contains('UIInterfaceOrientationPortraitUpsideDown')),
    );
  });

  test('Android는 태블릿 시작 Activity를 첫 프레임 전에 가로로 고정한다', () {
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
