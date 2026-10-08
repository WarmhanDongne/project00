import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/phone/widgets/night_action_view.dart';
import 'package:game_mafia/phone/widgets/result_sequence.dart';
import 'package:game_mafia/phone/widgets/vote_view.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/tablet/screens/day_view.dart';

const _names = ['나연', '민준', '서아', '지호', '도윤'];

List<MafiaPlayer> _players() => [
  for (var i = 0; i < _names.length; i++)
    MafiaPlayer(
      uid: 'p$i',
      nickname: _names[i],
      profileImageUrl: '',
      seatIndex: i,
    ),
];

Widget _phone(Widget child) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(402, 874)),
    child: Scaffold(body: SizedBox(width: 402, height: 874, child: child)),
  ),
);

void main() {
  test('이름 받침에 맞춰 이/가를 붙인다', () {
    expect(mafiaJosa('민준', '이', '가'), '민준이');
    expect(mafiaJosa('태오', '이', '가'), '태오가');
    expect(mafiaJosa('Alex', '이', '가'), 'Alex가');
    expect(mafiaNoirClock(150), '2:30');
    expect(mafiaNoirClock(-3), '0:00');
  });

  testWidgets('밤 제거 화면은 고른 사람 이름으로 버튼을 만들고 동료 선택을 안내한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var confirmed = 0;
    await tester.pumpWidget(
      _phone(
        MafiaNightActionView(
          role: MafiaRoles.find('mafia'),
          players: _players().skip(1).toList(),
          selectedUid: 'p2',
          allySelectedUids: const {'p3'},
          remainingSeconds: 38,
          onSelect: (_) {},
          onConfirm: () => confirmed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('오늘 밤의 표적'), findsOneWidget);
    expect(find.text('0:38'), findsOneWidget);
    expect(find.text('빨간 모서리는 동료가 고른 사람입니다'), findsOneWidget);
    await tester.tap(find.text('서아 제거'));
    expect(confirmed, 1);
  });

  testWidgets('투표 화면에는 기권 칸이 없고 고른 사람에게 투표한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var confirmed = 0;
    await tester.pumpWidget(
      _phone(
        MafiaVoteView(
          role: MafiaRoles.find('citizen'),
          players: _players().skip(1).toList(),
          selectedUid: 'p3',
          remainingSeconds: 21,
          onSelect: (_) {},
          onConfirm: () => confirmed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(MafiaVoteView.prompt), findsOneWidget);
    expect(find.text('기권'), findsNothing);
    await tester.tap(find.text('지호에게 투표'));
    await tester.pump(const Duration(seconds: 1));
    expect(confirmed, 1);
  });

  testWidgets('휴대폰 결과는 확인을 누를 때 전원 신분 명단으로 넘어간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final players = _players();
    await tester.pumpWidget(
      _phone(
        MafiaPhoneResultSequence(
          winner: MafiaFaction.mafia,
          players: players,
          revealedRoles: {
            for (final player in players)
              player.uid: MafiaRoles.find(
                player.uid == 'p0' ? 'mafia' : 'citizen',
              ),
          },
          myUid: 'p0',
          myRole: MafiaRoles.find('mafia'),
          didWin: true,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('당신의 팀이 이겼습니다'), findsOneWidget);
    expect(find.text('신분 정보'), findsNothing);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('신분 정보'), findsOneWidget);
  });

  testWidgets('태블릿 투표 화면은 낸 사람과 고민 중인 사람을 구분한다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MafiaTabletDayView(
            showBallotBox: true,
            remainingSeconds: 21,
            players: _players(),
            round: 3,
            voteSubmittedUids: const ['p0', 'p1', 'p2'],
            voteEligibleCount: 5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('투표 완료'), findsNWidgets(4));
    expect(find.text('고민 중…'), findsNWidgets(2));
    expect(find.text('3일째 낮 · 비밀 투표'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
