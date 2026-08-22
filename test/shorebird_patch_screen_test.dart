import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/update/shorebird_patch_screen.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';

//=======================Shorebird 패치 화면==============================
// 재접속 화면과 같은 골격을 쓰고 가운데 그림과 문구만 다릅니다. 그림 파일이
// 저장소에 들어오기 전에도 화면이 깨지지 않아야 합니다.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ShorebirdPatchScreen()));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('휴대폰 세로와 태블릿 가로 모두에서 문구가 보인다', (tester) async {
    for (final size in [const Size(402, 874), const Size(1194, 834)]) {
      await pumpAt(tester, size);

      expect(find.text('업데이트를 받는 중'), findsOneWidget);
      expect(find.text('잠시만 기다려 주세요'), findsOneWidget);
      // 그림 파일이 아직 없어도 오류 없이 그려집니다.
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('재접속 화면과 같은 골격을 쓰고 그림만 바꾼다', (tester) async {
    await pumpAt(tester, const Size(402, 874));

    final reconnect = tester.widget<GameReconnectScreen>(
      find.byType(GameReconnectScreen),
    );
    expect(reconnect.illustrationAsset, ShorebirdPatchScreen.illustrationAsset);
    // 반짝이는 별은 재접속 화면과 같은 그림을 씁니다.
    expect(reconnect.sparkleAsset, GameReconnectScreen.defaultSparkleAsset);
  });

  testWidgets('시간이 지나면 기다림 표시가 버튼으로 바뀐다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var skips = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ShorebirdPatchScreen(
          buttonDelay: const Duration(seconds: 2),
          onSkip: () => skips += 1,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('나중에 하기'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('나중에 하기'));
    expect(skips, 1);
  });
}
