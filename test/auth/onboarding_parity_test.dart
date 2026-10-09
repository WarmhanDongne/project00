import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';

//=======================앱·서버 온보딩 값 대조==============================
// 온보딩 문서의 `status`·`provider`는 **서버가 쓰고 앱이 읽습니다.** 앱 쪽
// enum에 없는 값이 문서에 있으면 `UserOnboarding.fromSnapshot`이 null을 돌려주고,
// 게이트는 복구 화면과 스피너를 오가며 멈춥니다.
//
// 실제로 애플 로그인을 붙일 때 서버에만 `apple`을 추가해서, 애플로 로그인한
// 기기가 무한 로딩에 갇혔습니다(2026-08-22). 이 시험이 그 재발을 막습니다.
void main() {
  final types = File('functions/src/auth/onboarding-types.ts');

  /// TS의 `export const <이름> = [ "a", "b" ] as const;`에서 값을 읽습니다.
  Set<String> serverValues(String constName) {
    final source = types.readAsStringSync();
    final start = source.indexOf('export const $constName');
    expect(start, isNot(-1), reason: '$constName을 찾지 못했습니다');
    final open = source.indexOf('[', start);
    final close = source.indexOf(']', open);
    final body = source.substring(open + 1, close);
    return RegExp(
      '"([A-Za-z]+)"',
    ).allMatches(body).map((match) => match.group(1)!).toSet();
  }

  test('회원가입 단계 값이 서버와 같다', () {
    expect(
      OnboardingStatus.values.map((status) => status.name).toSet(),
      serverValues('ONBOARDING_STATUSES'),
    );
  });

  test('회원가입 경로 값이 서버와 같다', () {
    // 여기서 어긋나면 그 경로로 가입한 기기가 무한 로딩에 갇힙니다.
    expect(
      OnboardingProvider.values.map((provider) => provider.name).toSet(),
      serverValues('ONBOARDING_PROVIDERS'),
    );
  });

  test('애플 경로는 앱이 읽을 수 있다', () {
    // 서버 syncAppleUserProfile이 `provider: "apple"`로 씁니다.
    expect(
      OnboardingProvider.values.map((provider) => provider.name),
      contains('apple'),
    );
  });
}
