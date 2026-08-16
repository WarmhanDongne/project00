import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/final_call/final_call_game.dart';
import 'package:project00/games/liars_poker/liars_poker_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('게임 화면 방향 정책', () {
    test('Liar\'s Poker 휴대폰은 세로와 양쪽 가로를 허용한다', () {
      expect(
        const LiarsPokerGame().phoneOrientation,
        PhoneGameOrientation.portraitAndLandscape,
      );
      expect(
        AppOrientation.phoneGameOrientations(
          const LiarsPokerGame().phoneOrientation,
        ),
        const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    });

    test('Final Call 휴대폰은 양쪽 가로만 허용한다', () {
      expect(
        const FinalCallGame().phoneOrientation,
        PhoneGameOrientation.landscapeOnly,
      );
      expect(
        AppOrientation.phoneGameOrientations(
          const FinalCallGame().phoneOrientation,
        ),
        const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    });
  });

  group('화면 방향 네이티브 요청', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      AppOrientation.invalidate();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setPreferredOrientations') {
              calls.add(call);
            }
            return null;
          });
    });

    tearDown(() {
      AppOrientation.invalidate();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('성공한 동일 방향 요청만 생략한다', () async {
      await AppOrientation.lockPlatformLandscape();
      await AppOrientation.lockTabletGameLandscape();

      expect(calls, hasLength(1));
    });

    test('캐시를 무효화하면 동일 방향도 네이티브에 다시 전달한다', () async {
      await AppOrientation.lockPlatformLandscape();
      AppOrientation.invalidate();
      await AppOrientation.lockPlatformLandscape();

      expect(calls, hasLength(2));
    });

    test('실패한 방향 요청은 적용된 것으로 캐시하지 않는다', () async {
      var shouldFail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method != 'SystemChrome.setPreferredOrientations') {
              return null;
            }
            calls.add(call);
            if (shouldFail) {
              shouldFail = false;
              throw PlatformException(code: 'scene-unavailable');
            }
            return null;
          });

      await expectLater(
        AppOrientation.lockPlatformLandscape(),
        throwsA(isA<PlatformException>()),
      );
      await AppOrientation.lockPlatformLandscape();

      expect(calls, hasLength(2));
    });
  });
}
