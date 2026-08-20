import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/constants/app_constants.dart';
import 'package:project00/core/utils/app_version.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/gamelist/service/game_compatibility.dart';

GameInfo _game(String id, {String minAppVersion = ''}) =>
    GameInfo.fromJson({'id': id, 'name': id, 'minAppVersion': minAppVersion});

void main() {
  //=======================버전 상수 드리프트 방지==============================
  // 스토어 배포 버전 판단이 이 상수 하나에 걸려 있습니다. pubspec 버전을 올리고
  // 상수를 잊으면, 새 게임에 minAppVersion을 적어도 구버전으로 오인해 게임이
  // 잠깁니다. 이 테스트가 두 값을 강제로 묶습니다.
  test('AppConstants.appVersion은 pubspec.yaml의 version과 같다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml에서 version을 찾지 못했습니다');
    expect(AppConstants.appVersion, match!.group(1));
  });

  //=======================버전 비교==============================
  test('버전 비교는 숫자 조각 기준으로 동작한다', () {
    expect(compareAppVersions('1.0.0', '1.0.0'), 0);
    expect(compareAppVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareAppVersions('1.10.0', '1.9.0'), greaterThan(0));
    expect(compareAppVersions('2.0', '2.0.0'), 0);
    // 빌드 번호는 스토어 버전 비교에 쓰지 않습니다.
    expect(compareAppVersions('1.0.0+99', '1.0.0+1'), 0);
  });

  test('minAppVersion이 비어 있으면 항상 통과한다', () {
    expect(isAppVersionAtLeast(current: '1.0.0', minimum: ''), isTrue);
    expect(isAppVersionAtLeast(current: '1.0.0', minimum: '  '), isTrue);
  });

  test('서버에 잘못 입력된 버전 문자열로 게임이 잠기지 않는다', () {
    expect(isAppVersionAtLeast(current: '1.0.0', minimum: 'abc'), isTrue);
  });

  //=======================실행 가능 판단==============================
  // 스토어에 배포된 앱은 이후 Firestore에 추가된 게임 문서를 그대로 받습니다.
  // 코드가 없는 게임은 시작 대신 업데이트 안내로 이어져야 합니다.
  test('레지스트리에 있는 게임은 실행할 수 있다', () {
    expect(isGamePlayableOnThisBuild(_game('liars_poker')), isTrue);
    expect(isGamePlayableOnThisBuild(_game('final_call')), isTrue);
  });

  test('이 빌드에 코드가 없는 게임은 실행할 수 없다', () {
    expect(isGamePlayableOnThisBuild(_game('future_game_2027')), isFalse);
  });

  test('요구 버전이 현재 빌드보다 높으면 실행할 수 없다', () {
    expect(
      isGamePlayableOnThisBuild(_game('liars_poker', minAppVersion: '99.0.0')),
      isFalse,
    );
    expect(
      isGamePlayableOnThisBuild(
        _game('liars_poker', minAppVersion: AppConstants.appVersion),
      ),
      isTrue,
    );
  });
}
