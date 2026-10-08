import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_mafia/phone/providers/game_stage.dart';
import 'package:game_mafia/phone/screens/game_screen.dart';
import 'package:game_mafia/shared/models/game_rules.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/shared/services/command_service.dart';
import 'package:game_mafia/shared/services/game_service.dart';
import 'package:game_mafia/shared/services/query_service.dart';

void main() {
  testWidgets('토론 종료 동의는 느린 응답 중 즉시 집계되고 실패 때만 복원된다', (tester) async {
    final controller = _LatencyController();
    await tester.pumpWidget(_screen(controller, MafiaPhoneStage.day));

    expect(find.text('토론 끝내기 동의'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    await tester.tap(find.text('토론 끝내기 동의'));
    await tester.pump();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('동의했습니다'), findsOneWidget);
    expect(find.text('토론 끝내기 동의'), findsNothing);

    controller.discussionResult.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('토론 끝내기 동의'), findsOneWidget);
    expect(find.text('1 / 2'), findsNothing);
  });

  testWidgets('찬반 투표는 응답 전에 완료 상태를 유지한다', (tester) async {
    final controller = _LatencyController(trial: true);
    await tester.pumpWidget(_screen(controller, MafiaPhoneStage.voting));

    await tester.tap(find.text('처형 반대'));
    await tester.pump();

    expect(find.text('투표 완료'), findsOneWidget);
    expect(find.text('처형 반대'), findsNothing);

    controller.trialResult.complete(true);
    await tester.pump();

    // callable은 끝났지만 RTDB snapshot은 아직 오지 않은 상황입니다.
    expect(find.text('투표 완료'), findsOneWidget);
  });
}

Widget _screen(_LatencyController controller, MafiaPhoneStage stage) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 402,
        height: 874,
        child: MafiaPhoneGameScreen(
          controller: controller,
          stage: stage,
          regions: const PhoneGameRegions(showTimer: true, showActions: true),
        ),
      ),
    ),
  );
}

class _LatencyController extends MafiaController {
  _LatencyController({this.trial = false})
    : super(
        roomCode: 'TEST',
        uid: 'me',
        service: MafiaService(
          command: _Command(),
          query: _Query(),
          interruption: _Interruption(),
        ),
      );

  final bool trial;
  final discussionResult = Completer<bool>();
  final trialResult = Completer<bool>();

  @override
  int? get gameStartedAt => 1;
  @override
  int get round => 1;
  @override
  int? get turnDeadlineAt => null;
  @override
  String get phase => trial ? 'voting' : 'day';
  @override
  bool get isNight => false;
  @override
  bool get isDay => !trial;
  @override
  bool get isVoting => trial;
  @override
  bool get isFinished => false;
  @override
  bool get actionDeadlinePassed => false;
  @override
  bool get privateDataReady => true;
  @override
  MafiaRole? get myRole => null;
  @override
  MafiaInvestigation? get currentInvestigation => null;
  @override
  bool get roleChangedThisRound => false;
  @override
  bool get hasSubmittedNight => false;
  @override
  bool get hasVoted => false;
  @override
  String? get voteTargetUid => null;
  @override
  bool? get trialVote => null;
  @override
  bool get isVoteBanned => false;
  @override
  bool get canAct => true;
  @override
  bool get canEndDiscussion => true;
  @override
  bool get hasVotedToSkipDiscussion => false;
  @override
  int get discussionSkipCount => 0;
  @override
  bool get isDayEndedByVote => false;
  @override
  MafiaRuleState get ruleState => trial
      ? const MafiaRuleState(
          rules: MafiaRules(trial: true),
          trialStage: 'verdict',
          candidateUid: 'candidate',
        )
      : const MafiaRuleState();
  @override
  Map<String, MafiaPlayer> get players => const {
    'me': MafiaPlayer(
      uid: 'me',
      nickname: '나',
      profileImageUrl: '',
      seatIndex: 0,
    ),
    'candidate': MafiaPlayer(
      uid: 'candidate',
      nickname: '후보',
      profileImageUrl: '',
      seatIndex: 1,
    ),
  };
  @override
  List<MafiaPlayer> get alivePlayers => players.values.toList(growable: false);
  @override
  MafiaMorningResult? get morningResult => null;
  @override
  bool get isSpectating => false;

  @override
  Future<bool> endDiscussion() => discussionResult.future;
  @override
  Future<bool> submitTrialVote(bool execute) => trialResult.future;
}

class _Command extends Fake implements MafiaCommandService {}

class _Query extends Fake implements MafiaQueryService {}

class _Interruption extends Fake implements GameInterruptionCommandService {}
