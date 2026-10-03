import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/shared/models/game_composition.dart';
import 'package:game_mafia/shared/models/game_rules.dart';
import 'package:game_mafia/shared/models/role_catalog.dart';
import 'package:game_mafia/shared/models/game_state.dart';
import 'package:game_mafia/shared/models/state_models.dart';
import 'package:game_mafia/shared/services/private_state_mapper.dart';
import 'package:game_mafia/shared/widgets/private_peek.dart';
import 'package:game_mafia/shared/widgets/trial_view.dart';

void main() {
  test('이전 snapshot은 기본 규칙, 새 snapshot은 재판·공개 옵션을 보존한다', () {
    expect(MafiaRuleState.fromMap({}).rules, const MafiaRules());
    final ruleState = MafiaRuleState.fromMap({
      'rules': {'trial': true, 'executionReveal': 'faction'},
      'composition': {'mafia': 2, 'citizen': 4},
      'trial': {'stage': 'verdict', 'candidateUid': 'u1'},
      'revealedFactions': {'u2': 'mafia'},
    });
    expect(ruleState.rules.trial, isTrue);
    expect(ruleState.candidateUid, 'u1');
    expect(ruleState.composition, {'mafia': 2, 'citizen': 4});
    expect(ruleState.revealedFactions, {'u2': 'mafia'});
    expect(
      MafiaPrivateSnapshot.fromValue({'trialVote': false}).trialVote,
      isFalse,
    );
    expect(MafiaPrivateSnapshot.fromValue({}).trialVote, isNull);
    final state = MafiaGameState.initial().copyWith(
      ruleState: ruleState,
      trialVote: false,
    );
    expect(state.copyWith().trialVote, isFalse);
    expect(state.copyWith(trialVote: null).trialVote, isNull);
    expect(state.copyWith(ruleState: const MafiaRuleState()), isNot(state));
  });

  test('구현된 역할마다 비어 있지 않은 규칙 설명이 있다', () {
    for (final role in MafiaRoles.implemented) {
      expect(MafiaCopy.roleRules(role).trim(), isNotEmpty, reason: role.id);
    }
  });

  test('기본 구성은 전 인원에서 네 기본 역할만 사용하고 인원 합계가 맞다', () {
    for (var count = 4; count <= 12; count++) {
      final roles = MafiaComposition.basicFor(count);
      expect(roles.keys.toSet(), {'citizen', 'mafia', 'police', 'doctor'});
      expect(roles.values.reduce((a, b) => a + b), count);
      expect(roles['mafia']! * 2, lessThan(count));
    }
  });

  test('룰북은 선택한 역할·옵션·중립 조건을 설명하고 미선택 역할 설명은 제외한다', () {
    final text = MafiaCopy.rulesFor(
      const MafiaRuleState(
        rules: MafiaRules(trial: true, executionReveal: 'hidden'),
        composition: {'mafia': 1, 'jester': 1, 'citizen': 4},
      ),
    );
    expect(text, contains('30초 변론'));
    expect(text, contains('공개하지 않음'));
    expect(text, contains('광대: 자신이 낮 투표로 처형'));
    expect(text, isNot(contains('처형자:')));
    expect(text, contains('한 번 확정'));
    expect(
      MafiaCopy.rulesFor(const MafiaRuleState(composition: {'unknown': 1})),
      isNotEmpty,
    );
  });

  testWidgets('관전 신분은 누르는 동안만 표시하고 취소·앱 비활성화 즉시 가린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MafiaPrivatePeek(height: 300, child: Text('비밀 역할 배정')),
        ),
      ),
    );
    expect(find.text('비밀 역할 배정'), findsNothing);
    var gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('spectator-peek'))),
    );
    await tester.pump();
    expect(find.text('비밀 역할 배정'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.text('비밀 역할 배정'), findsNothing);
    gesture = await tester.startGesture(const Offset(200, 100));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();
    expect(find.text('비밀 역할 배정'), findsNothing);
    gesture = await tester.startGesture(const Offset(200, 100));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('비밀 역할 배정'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
  });

  testWidgets('변론에는 투표 버튼이 없고 찬반에는 각각 정확한 선택을 전달한다', (tester) async {
    bool? vote;
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaTrialView(
          candidate: '후보',
          defending: true,
          onVote: (v) => vote = v,
        ),
      ),
    );
    expect(find.text('처형 찬성'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaTrialView(
          candidate: '후보',
          defending: false,
          onVote: (v) => vote = v,
        ),
      ),
    );
    await tester.tap(find.text('처형 찬성'));
    expect(vote, isTrue);
    await tester.tap(find.text('처형 반대'));
    expect(vote, isFalse);
    await tester.pumpWidget(
      const MaterialApp(
        home: MafiaTrialView(candidate: '후보', defending: false, hasVoted: true),
      ),
    );
    expect(find.text('투표 완료'), findsOneWidget);
    expect(find.text('처형 찬성'), findsNothing);
  });

  testWidgets('찬반 결과를 지목 득표와 구별하여 가결·부결과 기권을 표시한다', (tester) async {
    final result = MafiaVoteResult.fromMap({
      'tally': {'u1': 5},
      'verdict': {'yes': 3, 'no': 1},
      'abstainCount': 2,
    });
    await tester.pumpWidget(
      MaterialApp(home: MafiaVerdictSummary(result: result)),
    );
    expect(find.text('처형 부결'), findsOneWidget);
    expect(find.text('찬성 3 · 반대 1\n기권 2'), findsOneWidget);
  });

  testWidgets('좁은 휴대폰에서 긴 후보 이름·투표·비공개 발표가 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaTrialView(
          candidate: '이름이 아주 긴 참가자',
          defending: false,
          remainingSeconds: 30,
          onVote: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: MafiaLimitedDisclosure(
          nickname: '이름이 아주 긴 참가자',
          faction: 'mafia',
        ),
      ),
    );
    expect(find.text('마피아 진영입니다'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
