import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/tablet/result_overlay.dart';

void main() {
  testWidgets('승리 팀 두 명의 프로필과 닉네임을 표시하고 결과 버튼이 작동한다', (tester) async {
    var restartCount = 0;
    var homeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FinalCallResultOverlay(
          winners: const [
            FinalCallPlayer(
              uid: 'winner1',
              nickname: 'mino123',
              profileImageUrl: '',
              seatIndex: 0,
              team: FinalCallTeam.red,
              status: 'alive',
              lives: 1,
            ),
            FinalCallPlayer(
              uid: 'winner2',
              nickname: 'teammate',
              profileImageUrl: '',
              seatIndex: 2,
              team: FinalCallTeam.red,
              status: 'alive',
              lives: 3,
            ),
          ],
          winningTeam: FinalCallTeam.red,
          onRestart: () => restartCount++,
          onHome: () => homeCount++,
        ),
      ),
    );

    expect(find.text('게임 종료'), findsOneWidget);
    expect(find.text('mino123  ·  teammate'), findsOneWidget);
    expect(find.text('RED TEAM WINNER'), findsOneWidget);
    expect(
      find.byKey(const Key('final-call-winner-profile-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('final-call-winner-profile-1')),
      findsOneWidget,
    );
    expect(find.text('다시하기'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.byKey(const Key('final-call-restart-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('final-call-home-button')));
    await tester.pump();

    expect(restartCount, 1);
    expect(homeCount, 1);
  });
}
