import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/tablet/widgets/tablet_room_panel.dart';

void main() {
  //=======================제약 없이도 스스로 크기를 정한다==============================
  // 이 카드는 초대 화면에서는 Flexible 안(높이 유한)에, 활성 방 화면에서는
  // Column > Padding > Row 직속(가로·세로 모두 무한)에 놓입니다. 예전에는
  // AspectRatio를 써서 후자에서 'RenderAspectRatio has unbounded constraints'로
  // 화면 전체가 죽었고, 그래서 방을 만든 직후에는 멀쩡하다가 누군가 입장하는
  // 순간 터졌습니다.
  testWidgets('가로·세로가 모두 무한이어도 요청한 크기의 정사각형이 된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    RoomQrCard(roomCode: 'ABCDE', size: 92),
                    Expanded(child: Text('참여 코드')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RoomQrCard)), const Size(92, 92));
  });

  testWidgets('부모가 더 좁으면 그만큼 줄어든다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // 느슨한 제약이어야 줄어들 수 있습니다. tight 제약에서는 어떤
          // 위젯도 부모가 정한 크기를 벗어나지 못합니다.
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 140),
              child: const RoomQrCard(roomCode: 'ABCDE', size: 240),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RoomQrCard)), const Size(140, 140));
  });

  testWidgets('초대 화면처럼 Flexible 안에서도 정사각형을 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: Column(
              children: [
                Flexible(
                  flex: 8,
                  child: RoomQrCard(roomCode: 'ABCDE', size: 240),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(RoomQrCard));
    expect(size.width, size.height);
    expect(size.width, lessThanOrEqualTo(240));
  });
}
