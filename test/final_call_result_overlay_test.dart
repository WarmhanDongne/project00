import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/widgets/tablet/result_overlay.dart';

void main() {
  testWidgets('최종 승리자 프로필과 닉네임을 표시하고 결과 버튼이 작동한다', (tester) async {
    var restartCount = 0;
    var homeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FinalCallResultOverlay(
          winner: const FinalCallPlayer(
            uid: 'winner',
            nickname: 'mino123',
            profileImageUrl: '',
            seatIndex: 0,
            status: 'alive',
            lives: 1,
          ),
          onRestart: () => restartCount++,
          onHome: () => homeCount++,
        ),
      ),
    );

    expect(find.text('게임 종료'), findsOneWidget);
    expect(find.text('mino123'), findsOneWidget);
    expect(find.byKey(const Key('final-call-winner-profile')), findsOneWidget);
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
