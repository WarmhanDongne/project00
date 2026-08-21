import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/role_deal_toss_animation.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';

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

  testWidgets('확인 현황은 카드가 다 날아갈 때까지 카드 뒤에 숨는다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MafiaTabletRoleDealView(
          players: [
            for (var i = 0; i < 4; i += 1)
              MafiaPlayer(
                uid: 'u$i',
                nickname: '플레이어$i',
                profileImageUrl: '',
                seatIndex: i,
              ),
          ],
          confirmedCount: 2,
        ),
      ),
    );

    // 나눠 주는 동안에는 자리만 잡아 두고 보이지 않습니다.
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    // 더미 등장 뒤 마지막 장까지 날아가면 그 자리에 드러납니다.
    // (연출 단계마다 틱 시작 프레임이 끼어들어 정확한 시각은 프레임마다 다릅니다)
    var revealed = false;
    for (var i = 0; i < 16 && !revealed; i += 1) {
      await tester.pump(const Duration(milliseconds: 200));
      revealed =
          tester
              .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .opacity ==
          1;
    }
    expect(revealed, isTrue, reason: '카드가 다 날아갔는데 문구가 드러나지 않았습니다');

    // 드러난 문구는 화면 가운데(더미가 있던 자리)에 남습니다.
    await tester.pumpAndSettle();
    final textCenter = tester.getCenter(find.text('2 / 4'));
    expect(textCenter.dx, closeTo(1194 / 2, 1));
    expect(textCenter.dy, greaterThan(834 / 2));
    expect(textCenter.dy, lessThan(540));
  });
}
