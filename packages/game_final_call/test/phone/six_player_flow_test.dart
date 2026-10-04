import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/phone/providers/game_stage.dart';
import 'package:game_final_call/phone/widgets/spectator_view.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_kit/player_layouts/services/player_slot_positions.dart';

class _Game extends Fake implements FinalCallController {
  @override
  bool get loading => false;
  @override
  bool isEliminated = true;
  @override
  bool isFinished = false;
  @override
  bool get isNaturalResult => isFinished;
  @override
  String phase = 'dealing';
  @override
  int get round => 3;
  @override
  List<FinalCallCard> get hand => const [];
  @override
  int? resultRevealCompletedAt;
}

void main() {
  test('4·6인 배치에서 반대 번호 두 좌석은 테이블 중심을 마주 본다', () {
    for (final count in [4, 6]) {
      final centers = playerCentersForBoard(
        playerCount: count,
        boardSize: const Size(1024, 768),
      );
      for (var index = 0; index < count ~/ 2; index++) {
        final opposite = centers[index + count ~/ 2];
        final midpoint = (centers[index] + opposite) / 2;
        expect(midpoint.dx, closeTo(512, 0.00001));
        expect(midpoint.dy, closeTo(384, 0.00001));
      }
    }
  });

  test('탈락자는 다음 라운드와 재접속 때 새 손패 대기에 갇히지 않는다', () {
    final game = _Game();
    for (final phase in ['roundResult', 'dealing', 'playing', 'finalTurns']) {
      game.phase = phase;
      expect(
        resolveFinalCallPhoneStage(
          game: game,
          gameStartCompleted: false,
          announcedRound: null,
          handRevealed: false,
        ),
        FinalCallPhoneStage.spectating,
      );
    }
  });

  test('관전자도 최종 공개가 끝나면 손패 없이 우승 결과를 본다', () {
    final game = _Game()..isFinished = true;
    FinalCallPhoneStage stage() => resolveFinalCallPhoneStage(
      game: game,
      gameStartCompleted: true,
      announcedRound: 1,
      handRevealed: false,
    );
    expect(stage(), FinalCallPhoneStage.roundResultWaiting);
    game.resultRevealCompletedAt = 100;
    expect(stage(), FinalCallPhoneStage.result);
  });

  test('생존자는 기존 분배 대기를 유지한다', () {
    final game = _Game()..isEliminated = false;
    expect(
      resolveFinalCallPhoneStage(
        game: game,
        gameStartCompleted: true,
        announcedRound: 1,
        handRevealed: false,
      ),
      FinalCallPhoneStage.dealing,
    );
  });

  testWidgets('관전 화면은 작은 가로 화면에서 남은 팀과 최종 공개를 안내한다', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget screen(bool waiting) => MaterialApp(
      home: Scaffold(
        body: FinalCallSpectatorView(
          remainingTeamCount: 2,
          waitingForResult: waiting,
        ),
      ),
    );
    await tester.pumpWidget(screen(false));
    expect(find.text('우리 팀 탈락 · 관전 중'), findsOneWidget);
    expect(find.textContaining('남은 2팀'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(screen(true));
    expect(find.text('태블릿에서 최종 결과를 확인해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
