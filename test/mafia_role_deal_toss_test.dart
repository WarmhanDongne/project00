import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/role_deal_toss_animation.dart';

//=======================T1 나눠 주기 연출==============================
// 중앙 더미 → 좌석 방향으로 1장씩 → 화면 밖. 흩어진 좌석(12인 방에 4명)
// 배치가 과거에 공용 연출을 터뜨렸던 사례라 그 조합을 그대로 씁니다.
void main() {
  testWidgets('흩어진 좌석에서도 한 장씩 날아가고 끝나면 화면이 빈다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MafiaRoleDealTossAnimation(
            playerSeatIndexes: [1, 5, 8, 11],
            boardSeatCount: 12,
          ),
        ),
      ),
    );

    // 더미 등장(620ms) 동안 카드 더미 한 장이 보입니다.
    await tester.pump(); // 등장 시작 프레임
    await tester.pump(const Duration(milliseconds: 620));
    expect(find.byType(Image), findsOneWidget);

    // 비행 중 어느 프레임에서는 더미 + 날아가는 카드가 함께 보여야 합니다.
    // (틱 시작 프레임이 끼어들어 정확한 시각은 프레임마다 다를 수 있습니다)
    var sawFlight = false;
    for (var i = 0; i < 12 && !sawFlight; i += 1) {
      await tester.pump(const Duration(milliseconds: 200));
      sawFlight = tester.widgetList(find.byType(Image)).length >= 2;
    }
    expect(sawFlight, isTrue, reason: '카드가 한 장도 날아가지 않았습니다');

    // 전체(발사 간격 240ms×3 + 비행 560ms) 뒤에는 전부 화면 밖 = 빈 화면.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Image), findsNothing);
    await tester.pumpAndSettle();
  });
}
