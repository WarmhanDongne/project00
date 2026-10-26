import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('태블릿 로비는 wakelock 없이 게임과 같은 immersive viewport를 쓴다', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await AppSystemUi.enterTabletPlatformFullscreen();

    expect(
      calls,
      contains(
        isA<MethodCall>()
            .having(
              (call) => call.method,
              'method',
              'SystemChrome.setEnabledSystemUIMode',
            )
            .having(
              (call) => call.arguments,
              'mode',
              'SystemUiMode.immersiveSticky',
            ),
      ),
    );
  });

  test('방에 있는 동안은 로비·대기실에서도 화면을 켜 두고, 나가면 푼다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    addTearDown(() {
      AppSystemUi.resetForTesting();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    AppSystemUi.resetForTesting();
    final tabletRoom = Object();
    final phoneRoom = Object();

    await AppSystemUi.enterTabletPlatformFullscreen();
    expect(AppSystemUi.keepsScreenOn, isFalse);

    AppSystemUi.setInRoom(tabletRoom, true);
    await AppSystemUi.enterTabletPlatformFullscreen();
    expect(AppSystemUi.keepsScreenOn, isTrue);

    // 게임을 마치고 대기실로 돌아와도 방에 있으면 계속 켜 둡니다.
    await AppSystemUi.enterGameFullscreen();
    await AppSystemUi.showPlatformSystemBars();
    expect(AppSystemUi.keepsScreenOn, isTrue);

    AppSystemUi.setInRoom(phoneRoom, true);
    AppSystemUi.setInRoom(tabletRoom, false);
    expect(AppSystemUi.keepsScreenOn, isTrue);
    AppSystemUi.setInRoom(phoneRoom, false);
    expect(AppSystemUi.keepsScreenOn, isFalse);

    // 방 밖이어도 게임 화면은 켜 둡니다.
    await AppSystemUi.enterGameFullscreen();
    expect(AppSystemUi.keepsScreenOn, isTrue);
  });
}
