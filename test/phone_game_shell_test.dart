import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';
import 'package:project00/games/shared/game_flow/phone_game_flow_config.dart';
import 'package:project00/games/shared/game_flow/phone_game_shell.dart';

/// 공용 휴대폰 게임 셸의 표시 규칙을 고정합니다.
///
/// 특히 "진행 중에는 어떤 상태에서도 퇴장할 수 있어야 한다"는 규칙은 실제로
/// 깨진 적이 있어(손패를 모두 제출해 화면이 비면 상단바가 사라져 나갈 수
/// 없었음) 회귀 방지용으로 남겨 둡니다.
void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required GameScreenPhase phase,
    bool contentReady = true,
    bool contentRevealed = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneGameShell(
          phase: phase,
          roundNumber: 2,
          contentReady: contentReady,
          contentRevealed: contentRevealed,
          background: const ColoredBox(color: Colors.grey),
          topBar: const Text('상단바'),
          content: const Text('게임화면'),
          result: const Text('결과'),
          onIntroCompleted: () {},
          onRoundIntroCompleted: () {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('접속 중에는 상단바도 게임 화면도 없다', (tester) async {
    await pumpShell(tester, phase: GameScreenPhase.connecting);
    expect(find.text('상단바'), findsNothing);
    expect(find.text('게임화면'), findsNothing);
  });

  testWidgets('GAME START / ROUND N 안내 중에는 상단바를 감춘다', (tester) async {
    await pumpShell(tester, phase: GameScreenPhase.intro);
    expect(find.text('상단바'), findsNothing);
    expect(find.text('게임화면'), findsNothing);

    await pumpShell(tester, phase: GameScreenPhase.roundIntro);
    expect(find.text('상단바'), findsNothing);
    expect(find.text('ROUND 2'), findsOneWidget);
  });

  testWidgets('안내 문구 유지 시간을 Flow Config로 조정한다', (tester) async {
    var introCompleted = false;
    final defaultConfig = buildPhoneGameFlowConfig(roundNumber: 1);
    final shortIntroConfig = GameFlowConfig<GameScreenPhase>(
      steps: {
        ...defaultConfig.steps,
        GameScreenPhase.intro: const GameFlowStep<GameScreenPhase>(
          stage: GameScreenPhase.intro,
          showScreen: false,
          showAnnouncement: true,
          announcementId: 'short-game-start',
          announcementKind: GameAnnouncementKind.gameStart,
          announcement: 'GAME START',
          announcementDuration: Duration(milliseconds: 120),
          animation: GameFlowAnimationConfig(
            name: 'PhoneGameStartAnimation',
            duration: Duration(milliseconds: 120),
          ),
          blocksInteraction: true,
          advancePolicy: GameFlowAdvancePolicy.clientPresentation,
        ),
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneGameShell(
          phase: GameScreenPhase.intro,
          roundNumber: 1,
          flowConfig: shortIntroConfig,
          background: const ColoredBox(color: Colors.grey),
          content: const Text('게임화면'),
          onIntroCompleted: () => introCompleted = true,
          onRoundIntroCompleted: () {},
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(introCompleted, true);
  });

  testWidgets('손패 펼치는 중에는 상단바를 아직 보여주지 않는다', (tester) async {
    await pumpShell(
      tester,
      phase: GameScreenPhase.playing,
      contentRevealed: false,
    );
    expect(find.text('상단바'), findsNothing);
    expect(find.text('게임화면'), findsOneWidget);
  });

  testWidgets('진행 중에는 상단바와 게임 화면이 함께 보인다', (tester) async {
    await pumpShell(tester, phase: GameScreenPhase.playing);
    expect(find.text('상단바'), findsOneWidget);
    expect(find.text('게임화면'), findsOneWidget);
  });

  testWidgets('손패가 비어 화면이 없어도 퇴장할 수 있어야 한다', (tester) async {
    // 최종 제출 후처럼 그릴 내용이 없는 순간에도 상단바(퇴장)는 남아야 합니다.
    await pumpShell(
      tester,
      phase: GameScreenPhase.playing,
      contentReady: false,
    );
    expect(find.text('게임화면'), findsNothing);
    expect(find.text('상단바'), findsOneWidget, reason: '퇴장 경로가 사라지면 안 됩니다');
  });

  testWidgets('결과 화면에서도 상단바가 남는다', (tester) async {
    await pumpShell(tester, phase: GameScreenPhase.result);
    expect(find.text('결과'), findsOneWidget);
    expect(find.text('상단바'), findsOneWidget);
  });

  testWidgets('정리 중에는 안내 문구만 보인다', (tester) async {
    await pumpShell(tester, phase: GameScreenPhase.closing);
    expect(find.text('인원 부족으로 게임을 종료합니다'), findsOneWidget);
    expect(find.text('상단바'), findsNothing);
  });
}
