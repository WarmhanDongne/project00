import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';

void main() {
  testWidgets('자리 배치는 선택 해제가 성공한 경우에만 뒤로 이동한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    var allowCancel = false;
    var cancelCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerLayoutEditor(
                      initialLayout: _layout,
                      tableColor: Colors.grey,
                      onPrepare: (_) async => true,
                      onComplete: (_) {},
                      onCancel: () async {
                        cancelCalls += 1;
                        return allowCancel;
                      },
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerLayoutEditor), findsOneWidget);
    expect(find.byTooltip('뒤로가기'), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(cancelCalls, 1);
    expect(find.byType(PlayerLayoutEditor), findsOneWidget);

    allowCancel = true;
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(cancelCalls, 2);
    expect(find.byType(PlayerLayoutEditor), findsNothing);
  });
}

const _layout = PlayerLayoutModel(
  players: [
    PlayerLayoutPlayer(
      uid: 'one',
      nickname: '한 명',
      characterId: 'cat',
      seatIndex: 0,
    ),
    PlayerLayoutPlayer(
      uid: 'two',
      nickname: '두 명',
      characterId: 'frog',
      seatIndex: 1,
    ),
  ],
);
