import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/games/mafia/widgets/phone/vote_view.dart';

//=======================휴대폰 투표 제출 연출==============================
// 확정(2026-08): 표를 내면 가운데 요소가 뭉쳐 사라지고, 태블릿에서 쓰는 그
// 투표지 한 장으로 바뀌어 화면 위로 날아갑니다.
void main() {
  List<MafiaPlayer> buildPlayers(int count) => [
    for (var i = 0; i < count; i += 1)
      MafiaPlayer(
        uid: 'u$i',
        nickname: '플레이어$i',
        profileImageUrl: '',
        seatIndex: i,
      ),
  ];

  Future<int> pumpAndConfirm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var confirms = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaVoteView(
          role: MafiaRoles.find('citizen'),
          players: buildPlayers(4),
          selectedUid: 'u1',
          remainingSeconds: 20,
          onSelect: (_) {},
          onConfirm: () => confirms += 1,
        ),
      ),
    );
    // 버튼 위젯의 박스는 화면 전체라(자기 Stack + Positioned 구조), 실제
    // 버튼이 놓인 자리(시안 top 652, 높이 79.6)를 눌러야 맞습니다.
    await tester.tapAt(const Offset(201, 692));
    await tester.pump();
    return confirms;
  }

  testWidgets('누르면 서버로 바로 보내고 연출이 시작된다', (tester) async {
    final confirms = await pumpAndConfirm(tester);

    // 서버 전송은 연출을 기다리지 않습니다(눌린 느낌이 바로 와야 합니다).
    expect(confirms, 1);
  });

  testWidgets('가운데 요소가 뭉쳐 사라지고 투표지가 위로 날아간다', (tester) async {
    await pumpAndConfirm(tester);

    // 연출 초반: 격자가 아직 있지만 작아지며 흐려집니다.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(MafiaPlayerSelectGrid), findsOneWidget);
    final fading = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((o) => o.opacity)
        .toList();
    expect(fading.any((value) => value < 1), isTrue);

    // 중반: 태블릿과 같은 투표지가 생깁니다.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MafiaBallotPaper), findsOneWidget);
    final firstTop = tester.getTopLeft(find.byType(MafiaBallotPaper)).dy;

    // 후반: 종이가 위로 올라갑니다.
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.getTopLeft(find.byType(MafiaBallotPaper)).dy,
      lessThan(firstTop),
    );

    // 연출이 끝나면 대기 화면으로 넘어갑니다(서버 응답과 무관하게).
    await tester.pump(MafiaVoteView.submitDuration);
    await tester.pump();
    expect(find.byType(MafiaBallotPaper), findsNothing);
  });

  testWidgets('재접속처럼 이미 낸 상태로 들어오면 연출 없이 대기 화면이다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MafiaVoteView(
          role: MafiaRoles.find('citizen'),
          players: buildPlayers(4),
          selectedUid: 'u1',
          isSubmitted: true,
        ),
      ),
    );

    expect(find.byType(MafiaBallotPaper), findsNothing);
    expect(find.byType(MafiaPlayerSelectGrid), findsNothing);
    expect(find.textContaining('기다리는 중입니다'), findsOneWidget);
  });
}
