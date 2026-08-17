import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';

void main() {
  const interruption = GameInterruption(
    id: 'player-1-1000',
    playerUid: 'player-1',
    playerNickname: '민수',
    playerProfileImageUrl: '',
    reason: GameInterruptionReason.disconnected,
    startedAt: 1000,
    deadlineAt: 9999999999999,
    eligibleVoterUids: ['me', 'other'],
    requiredVotes: 2,
    voterUids: {},
    canContinue: true,
  );

  Widget buildLayer({
    required VoidCallback onGamePressed,
    VoidCallback? onVote,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            TextButton(onPressed: onGamePressed, child: const Text('game')),
            GameInterruptionLayer(
              interruption: interruption,
              currentUid: 'me',
              onVote: onVote == null
                  ? null
                  : () async {
                      onVote();
                    },
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('전체 화면을 어둡게 하고 프로필·투표 정보를 표시한다', (tester) async {
    await tester.pumpWidget(buildLayer(onGamePressed: () {}));

    expect(find.text('민수님의 연결이 끊어졌습니다'), findsOneWidget);
    expect(find.text('민수님을 제외하고 게임을 계속할까요?'), findsOneWidget);
    expect(find.text('동의 0 / 2'), findsOneWidget);
    expect(find.text('제외하고 계속하기'), findsOneWidget);
  });

  testWidgets('게임 조작은 막고 투표 버튼만 입력받는다', (tester) async {
    var gamePresses = 0;
    var votes = 0;
    await tester.pumpWidget(
      buildLayer(
        onGamePressed: () => gamePresses += 1,
        onVote: () => votes += 1,
      ),
    );

    await tester.tap(find.text('game'), warnIfMissed: false);
    await tester.tap(find.text('제외하고 계속하기'));
    expect(gamePresses, 0);
    expect(votes, 1);
  });

  //=======================Stack 붕괴 방지==============================
  // 이 레이어는 게임 화면 Stack의 맨 위에 항상 놓여 있고, 중단이 없는 평상시가
  // 대부분입니다. 그때 Positioned가 아닌 자식을 돌려주면 느슨한 Stack이
  // non-positioned 자식(0×0)에 맞춰 줄어들어 배경과 게임 레이어가 통째로
  // 사라집니다. 실제로 라이어스포커 태블릿 화면이 이 이유로 검게 나왔습니다.
  testWidgets('중단이 없어도 느슨한 Stack을 0으로 줄이지 않는다', (tester) async {
    const stackKey = Key('game-root');
    const backgroundKey = Key('game-background');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          // 게임 화면의 루트와 같은 구조입니다. fit을 지정하지 않은 Stack이
          // 기본값 StackFit.loose이며, 이 조건에서 회귀가 발생했습니다.
          body: Stack(
            key: stackKey,
            children: [
              Positioned.fill(
                child: ColoredBox(key: backgroundKey, color: Colors.green),
              ),
              GameInterruptionLayer(interruption: null, currentUid: 'me'),
            ],
          ),
        ),
      ),
    );

    final screen = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(find.byKey(stackKey)), screen);
    expect(tester.getSize(find.byKey(backgroundKey)), screen);
  });
}
