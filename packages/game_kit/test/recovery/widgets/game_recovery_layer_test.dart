import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/widgets/game_connecting_overlay.dart';
import 'package:game_kit/recovery/widgets/game_interruption_layer.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

void main() {
  testWidgets('요청 안내와 연결 복구 설정을 공용 레이어에 전달한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameRecoveryLayer(
            request: GameRequestRecovery(message: '전송하지 못했습니다.'),
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
    final connecting = tester.widget<GameConnectingOverlay>(
      find.byType(GameConnectingOverlay),
    );
    expect(connecting.exitDelay, const Duration(seconds: 10));
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

    expect(find.byType(GameRequestNotice), findsNothing);
    expect(find.byType(GameInterruptionLayer), findsOneWidget);
  });
}
