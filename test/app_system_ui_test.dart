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
}
