import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_recovery_context.dart';
import 'package:game_kit/game_flow/game_screen_phase.dart';
import 'package:game_kit/game_flow/phone_game_flow_config.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

void main() {
  testWidgets(
    'own ready acknowledgement failure exposes retry while locally usable',
    (tester) async {
      final session = GameRecoverySession()..localUsable = true;
      var retries = 0;
      session.retry = () => retries++;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameRecoveryLayer(
              session: session,
              request: const GameRequestRecovery(
                message: '화면 준비를 확인하지 못했어요. 다시 연결해주세요.',
              ),
              interruption: GameInterruptionRecovery(
                state: GameInterruption.fromMap({
                  'paused': true,
                  'pauseId': 'pause',
                  'causes': {
                    'player:me': {'uid': 'me', 'reason': 'preparationFailed'},
                  },
                }),
                currentUid: 'me',
              ),
              child: const Text('메뉴'),
            ),
          ),
        ),
      );
      expect(find.text('재시도'), findsOneWidget);
      expect(find.text('메뉴'), findsOneWidget);
      await tester.tap(find.text('재시도'));
      expect(retries, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
  testWidgets('정상 연결 대기는 오래 걸려도 기존 배경만 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameRecoveryLayer(
            connection: GameConnectionRecovery(
              isWaiting: true,
              exitDelay: Duration(seconds: 10),
            ),
            child: Text('게임 화면'),
          ),
        ),
      ),
    );

    expect(find.text('게임 화면'), findsOneWidget);
    expect(find.byType(GameRequestNotice), findsNothing);
    expect(find.byType(GameConnectingOverlay), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('게임 화면'), findsOneWidget);
    expect(find.text('게임 데이터를 다시 준비하고 있습니다.'), findsNothing);
    expect(find.text('게임과 그룹 나가기'), findsNothing);
  });

  testWidgets('플레이어 이탈 중에는 하위 요청 오류를 중복 표시하지 않는다', (tester) async {
    final interruption = GameInterruption(
      id: 'interruption-1',
      playerUid: 'player-2',
      playerNickname: '다른 플레이어',
      playerCharacterId: 'frog',
      reason: GameInterruptionReason.disconnected,
      startedAt: 1,
      deadlineAt: DateTime.now().millisecondsSinceEpoch + 60000,
      eligibleVoterUids: const ['player-1'],
      requiredVotes: 1,
      voterUids: const {},
      remainingPlayerCount: 3,
      minimumPlayerCount: 2,
      canContinue: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameRecoveryLayer(
            request: const GameRequestRecovery(message: '중복 오류'),
            interruption: GameInterruptionRecovery(
              state: interruption,
              currentUid: 'player-1',
            ),
            child: const Text('게임 화면'),
          ),
        ),
      ),
    );

    expect(find.text('중복 오류'), findsOneWidget);
    expect(find.byType(GameInterruptionLayer), findsNothing);
    expect(find.byType(GameRequestNotice), findsOneWidget);
    expect(find.text('내가 나가기'), findsNothing);
  });

  for (final role in GameInterruptionPresentation.values) {
    testWidgets('원인 없는 준비 barrier는 $role 중단 안내를 띄우지 않는다', (tester) async {
      final session = GameRecoverySession();
      addTearDown(session.dispose);
      var retries = 0, exits = 0;
      session.retry = () => retries++;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameRecoveryLayer(
              session: session,
              onExit: () => exits++,
              interruption: GameInterruptionRecovery(
                state: GameInterruption.fromMap({
                  'paused': true,
                  'pauseId': 'startup-barrier',
                }),
                currentUid: 'player',
                presentation: role,
              ),
              child: const Text('기존 배경'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 12));
      expect(find.text('기존 배경'), findsOneWidget);
      expect(find.byType(GameInterruptionLayer), findsNothing);
      expect(find.textContaining('게임을 잠시 멈췄어요'), findsNothing);
      expect(find.byType(GameConnectingOverlay), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(session.canSend, false);
      expect(retries, 0);
      expect(exits, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('휴대폰 셸의 연결 단계도 추가 안내나 퇴장 버튼을 만들지 않는다', (tester) async {
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneGameShell<GameScreenPhase>(
          stage: GameScreenPhase.connecting,
          stageRole: PhoneGameShellStageRole.connecting,
          flowConfig: buildPhoneGameFlowConfig(roundNumber: 1),
          roundNumber: 1,
          background: const ColoredBox(
            key: ValueKey('game-background'),
            color: Colors.purple,
          ),
          content: const SizedBox(),
          onConnectingExit: () => exits++,
          onIntroCompleted: () {},
          onRoundIntroCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    expect(find.byKey(const ValueKey('game-background')), findsOneWidget);
    expect(find.byType(GameConnectingOverlay), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(exits, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('실제 준비 실패는 기존 오류 안내와 메뉴를 사용한다', (tester) async {
    final session = GameRecoverySession();
    addTearDown(session.dispose);
    var retries = 0, exits = 0;
    session.retry = () => retries++;
    await tester.pumpWidget(
      MaterialApp(
        home: GameRecoveryLayer(
          session: session,
          request: const GameRequestRecovery(message: '화면 준비 실패'),
          child: PhoneGameShell<GameScreenPhase>(
            stage: GameScreenPhase.connecting,
            stageRole: PhoneGameShellStageRole.connecting,
            flowConfig: buildPhoneGameFlowConfig(roundNumber: 1),
            roundNumber: 1,
            background: const ColoredBox(
              key: ValueKey('game-background'),
              color: Colors.purple,
            ),
            content: const SizedBox(),
            topBar: TextButton(
              onPressed: () => exits++,
              child: const Text('기존 메뉴 나가기'),
            ),
            onIntroCompleted: () {},
            onRoundIntroCompleted: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-background')), findsOneWidget);
    expect(find.byType(GameRequestNotice), findsOneWidget);
    expect(find.text('화면 준비 실패'), findsOneWidget);
    expect(find.text('게임과 그룹 나가기'), findsNothing);
    await tester.tap(find.text('재시도'));
    expect(retries, 1);
    await tester.tap(find.text('기존 메뉴 나가기'));
    expect(exits, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('서버 중단 중 본인 준비 실패도 안내 한 곳에서 재시도한다', (tester) async {
    final session = GameRecoverySession();
    addTearDown(session.dispose);
    var retries = 0;
    session.retry = () => retries++;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameRecoveryLayer(
            session: session,
            request: const GameRequestRecovery(message: '본인 화면 준비 실패'),
            interruption: GameInterruptionRecovery(
              state: GameInterruption.fromMap({
                'paused': true,
                'pauseId': 'failed-pause',
                'causes': {
                  'player:me': {'incidentId': 'failed-player'},
                },
              }),
              currentUid: 'me',
            ),
            child: const Text('기존 화면'),
          ),
        ),
      ),
    );
    expect(find.byType(GameRequestNotice), findsOneWidget);
    expect(find.text('본인 화면 준비 실패'), findsOneWidget);
    await tester.tap(find.text('재시도'));
    expect(retries, 1);
    expect(find.text('내가 나가기'), findsNothing);
    expect(find.text('게임과 그룹 나가기'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('준비·barrier·복구 동안 플레이만 차단하고 메뉴와 화면 State를 유지한다', (tester) async {
    final session = GameRecoverySession();
    addTearDown(session.dispose);
    var plays = 0, exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GameRecoveryLayer(
          session: session,
          child: PhoneGameShell<GameScreenPhase>(
            stage: GameScreenPhase.playing,
            stageRole: PhoneGameShellStageRole.playing,
            flowConfig: buildPhoneGameFlowConfig(roundNumber: 1),
            roundNumber: 1,
            background: const ColoredBox(color: Colors.purple),
            content: Center(
              child: TextButton(
                onPressed: () => plays++,
                child: const Text('플레이'),
              ),
            ),
            topBar: TextButton(
              onPressed: () => exits++,
              child: const Text('기존 나가기'),
            ),
            onIntroCompleted: () {},
            onRoundIntroCompleted: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final contentElement = tester.element(find.text('플레이'));
    final position = tester.getCenter(find.text('플레이'));
    await tester.tapAt(position);
    expect(plays, 0);
    await tester.tap(find.text('기존 나가기'));
    expect(exits, 1);
    session
      ..localUsable = true
      ..serverConfirmed = true;
    session.changed();
    await tester.pump();
    await tester.tapAt(position);
    expect(plays, 0, reason: 'server pause still blocks play');
    session.paused = false;
    session.changed();
    await tester.pump();
    await tester.tapAt(position);
    expect(plays, 1);
    expect(tester.element(find.text('플레이')), same(contentElement));
    session.invalidate();
    await tester.pump();
    await tester.tapAt(position);
    expect(plays, 1);
    await tester.tap(find.text('기존 나가기'));
    expect(exits, 2);
    expect(find.textContaining('다시 준비'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
