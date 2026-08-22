import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/core/layout/device_layout.dart';

//=======================게임 종료 후 방향 복원==============================
// 게임을 나와 로비로 돌아올 때의 방향은 **기기**로 정합니다. 화면마다 세로·가로를
// 적어 두면 한 곳만 틀려도 로비가 엉뚱한 방향으로 잠깁니다(마피아 태블릿이
// 세로로 되돌려 로비가 세로로 고정되던 문제).
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    AppOrientation.invalidate();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> requestedOrientations() {
    final call = calls.lastWhere(
      (call) => call.method == 'SystemChrome.setPreferredOrientations',
    );
    return (call.arguments as List).cast<String>();
  }

  testWidgets('태블릿은 가로로 되돌린다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    expect(DeviceLayout.isTabletDevice(), isTrue);

    await AppOrientation.restorePlatform();

    expect(requestedOrientations(), [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('휴대폰은 세로로 되돌린다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    expect(DeviceLayout.isTabletDevice(), isFalse);

    await AppOrientation.restorePlatform();

    expect(requestedOrientations(), ['DeviceOrientation.portraitUp']);
  });
}
