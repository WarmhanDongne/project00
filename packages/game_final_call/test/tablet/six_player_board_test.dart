import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/tablet/providers/game_stage.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_final_call/tablet/widgets/result_overlay.dart';

class _BoardGame extends Fake implements FinalCallController {
  @override
  final Map<String, FinalCallPlayer> players = {
    for (var i = 0; i < 6; i++)
      'p$i': FinalCallPlayer(
        uid: 'p$i',
        nickname: '참가자 $i',
        characterId: 'frog',
        seatIndex: i,
        team: FinalCallTeam.values[i % 3],
        status: 'alive',
        lives: 3,
      ),
  };
  @override
  int get round => 2;
  @override
  FinalCallCard get discardCard =>
      const FinalCallCard(id: 'red_5', color: 'red', value: 5);
  @override
  FinalCallDiscardEvent? get discardEvent => null;
  @override
  String? get pendingDrawUid => null;
  @override
  String? get pendingDrawSource => null;
  @override
  String? get turnUid => 'p1';
  @override
  FinalCallPlayer? get turnPlayer => players[turnUid];
  @override
  int? get turnDeadlineAt => null;
  @override
  String? get callerUid => null;
  @override
  String get phase => 'playing';
  @override
  int get deckRemainingCount => 17;
}

void main() {
  testWidgets('6인 보드는 세 팀의 하트를 표시하고 탈락 팀은 하트 대신 탈락 표시를 유지한다', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = _BoardGame();
    Widget board() => MaterialApp(
      home: Scaffold(
        body: FinalCallTabletGameLayer(
          controller: game,
          stage: FinalCallTabletStage.playing,
          flowConfig: buildFinalCallTabletFlowConfig(closingMessage: ''),
          onRoundRevealCompleted: () {},
          onDealingCompleted: () {},
        ),
      ),
    );
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    for (final team in FinalCallTeam.values) {
      for (var heart = 0; heart < 3; heart++) {
        expect(
          find.byKey(ValueKey('final-call-${team.name}-heart-$heart')),
          findsNWidgets(2),
        );
      }
    }
    for (final uid in ['p2', 'p5']) {
      final player = game.players[uid]!;
      game.players[uid] = FinalCallPlayer(
        uid: uid,
        nickname: player.nickname,
        characterId: player.characterId,
        seatIndex: player.seatIndex,
        team: player.team,
        status: 'eliminated',
        lives: uid == 'p2' ? 0 : 3,
      );
    }
    await tester.pumpWidget(board());
    await tester.pumpAndSettle();
    expect(find.text('그린팀 탈락'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('final-call-green-heart-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('final-call-blue-heart-0')),
      findsNWidgets(2),
    );
    // Party Pop 테이블: 차례 알약과 덱 장수, 라운드 안내를 표시합니다.
    expect(find.text('참가자 1 차례예요'), findsOneWidget);
    expect(find.text('덱 17'), findsOneWidget);
    expect(find.text('2라운드 · 같은 색 = 맞은편 짝꿍'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('그린팀 우승 화면은 양쪽 팀원의 이름과 올바른 팀명을 표시한다', (tester) async {
    final winners = _BoardGame().players.values
        .where((p) => p.team == FinalCallTeam.green)
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: FinalCallResultOverlay(
          winners: winners,
          winningTeam: FinalCallTeam.green,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('그린팀 승리'), findsOneWidget);
    expect(find.textContaining('참가자 2'), findsOneWidget);
    expect(find.textContaining('참가자 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
