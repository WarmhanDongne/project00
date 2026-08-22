import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/widgets/phone/day_discussion_view.dart';
import 'package:project00/games/mafia/widgets/phone/morning_announcement_view.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';
import 'package:project00/games/mafia/widgets/phone/vote_view.dart';

import 'support/ejection_beats.dart';

//=======================2026-08 실기기 지적 사항==============================
// 실제로 한 판 돌려 보고 나온 지적들을 화면 쪽에서 잠가 둡니다. 규칙 자체는
// 서버 테스트(functions/test/mafia-*.test.mjs)가 지킵니다.
void main() {
  const design = Size(402, 874);

  MafiaPlayer player(String uid, {bool alive = true}) => MafiaPlayer(
    uid: uid,
    nickname: uid,
    profileImageUrl: '',
    seatIndex: 0,
    isAlive: alive,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  //=======================낮 투표 — 고르기 전에는 버튼이 없습니다==============
  group('낮 투표 선택 완료 버튼', () {
    testWidgets('아무도 고르지 않으면 보이지 않는다', (tester) async {
      await pump(
        tester,
        MafiaVoteView(
          role: MafiaRoles.find('citizen'),
          players: [player('a'), player('b')],
          onSelect: (_) {},
          onConfirm: () {},
        ),
      );

      // 자리는 남아 있지만 완전히 투명합니다.
      expect(find.text('선택 완료'), findsOneWidget);
      expect(opacityOf(tester, '선택 완료'), 0);
    });

    testWidgets('고르면 같은 자리에 드러난다', (tester) async {
      await pump(
        tester,
        MafiaVoteView(
          role: MafiaRoles.find('citizen'),
          players: [player('a'), player('b')],
          selectedUid: 'a',
          onSelect: (_) {},
          onConfirm: () {},
        ),
      );

      expect(opacityOf(tester, '선택 완료'), 1);
    });
  });

  //=======================영매·도둑은 사망자를 고릅니다=======================
  // 그리드가 '살아 있는 사람만' 누를 수 있게 돼 있어, 명단이 보이는데도 아무도
  // 고를 수 없었습니다(2026-08 실기기: 영매·도둑).
  group('사망자 지목', () {
    testWidgets('영매는 죽은 사람을 누를 수 있다', (tester) async {
      final picked = <String>[];
      await pump(
        tester,
        MafiaNightActionView(
          role: MafiaRoles.find('medium'),
          players: [player('dead1', alive: false)],
          onSelect: picked.add,
        ),
      );

      await tester.tap(find.text('dead1'));
      expect(picked, ['dead1']);
    });

    testWidgets('평소 밤에는 죽은 사람이 눌리지 않는다', (tester) async {
      final picked = <String>[];
      await pump(
        tester,
        MafiaNightActionView(
          role: MafiaRoles.find('mafia'),
          players: [player('alive1'), player('dead1', alive: false)],
          onSelect: picked.add,
        ),
      );

      await tester.tap(find.text('dead1'));
      expect(picked, isEmpty, reason: '사망자는 마피아의 대상이 아니다');
      await tester.tap(find.text('alive1'));
      expect(picked, ['alive1']);
    });

    testWidgets('도둑도 사망자 명단에서 고른다', (tester) async {
      final thief = MafiaRoles.find('thief');
      expect(thief?.targetsDead, isTrue, reason: '도둑은 사망자를 고르는 역할이다');

      final picked = <String>[];
      await pump(
        tester,
        MafiaNightActionView(
          role: thief,
          players: [player('dead1', alive: false)],
          onSelect: picked.add,
        ),
      );
      await tester.tap(find.text('dead1'));
      expect(picked, ['dead1']);
    });
  });

  //=======================경찰 결과는 문장으로==============================
  // `시민`이라는 한 낱말은 직업 이름이기도 해서 "정확한 직업을 알아냈다"로
  // 읽힙니다(2026-08 지적). 진영 조사는 문장으로 적습니다.
  group('경찰 조사 결과', () {
    testWidgets('마피아면 마피아입니다로 적는다', (tester) async {
      await pump(
        tester,
        MafiaNightActionView(
          role: MafiaRoles.find('police'),
          investigationResult: MafiaNightInvestigationResult(
            target: player('철수'),
            verdict: '마피아',
            asFactionSentence: true,
          ),
          onConfirmResult: () {},
        ),
      );

      expect(find.text('철수님은 마피아입니다'), findsOneWidget);
    });

    testWidgets('시민이면 마피아가 아닙니다로 적는다', (tester) async {
      await pump(
        tester,
        MafiaNightActionView(
          role: MafiaRoles.find('police'),
          investigationResult: MafiaNightInvestigationResult(
            target: player('영희'),
            verdict: '시민',
            asFactionSentence: true,
          ),
          onConfirmResult: () {},
        ),
      );

      expect(find.text('영희님은 마피아가 아닙니다'), findsOneWidget);
      // 직업 이름을 그대로 노출하지 않습니다.
      expect(find.text('시민'), findsNothing);
    });

    testWidgets('영매는 직업 이름을 그대로 보여 준다', (tester) async {
      await pump(
        tester,
        MafiaNightActionView(
          role: MafiaRoles.find('medium'),
          investigationResult: MafiaNightInvestigationResult(
            target: player('철수'),
            verdict: '경찰',
            title: '교신 결과',
          ),
          onConfirmResult: () {},
        ),
      );

      expect(find.text('경찰'), findsOneWidget);
      expect(find.textContaining('마피아가 아닙니다'), findsNothing);
    });
  });

  //=======================기자의 취재 공개==============================
  testWidgets('취재가 성공한 아침에는 공개 안내가 함께 나온다', (tester) async {
    await pump(
      tester,
      MafiaMorningAnnouncementView(
        role: MafiaRoles.find('citizen'),
        result: const MafiaMorningResult(
          deadUids: [],
          savedCount: 0,
          exposedUid: 'target',
        ),
        players: {'target': player('target')},
      ),
    );

    // 박자는 머무르기(Timer)와 연출(애니메이션)을 번갈아 거칩니다.
    await pumpUntilText(tester, MafiaCopy.exposureBeats.last);
  });

  //=======================투표로 끝난 토론==============================
  group('토론이 투표로 종료되면', () {
    testWidgets('안내만 남고 버튼·타이머가 사라진다', (tester) async {
      await pump(
        tester,
        MafiaDayDiscussionView(
          role: MafiaRoles.find('citizen'),
          remainingSeconds: 2,
          canEndDiscussion: true,
          onEndDiscussion: () {},
          endedByVote: true,
        ),
      );

      expect(find.text(MafiaCopy.discussionSkippedNotice), findsOneWidget);
      expect(find.text('토론 종료 하기'), findsNothing);
      expect(find.text('2s'), findsNothing);
    });

    testWidgets('평소에는 그대로 토론 화면이다', (tester) async {
      await pump(
        tester,
        MafiaDayDiscussionView(
          role: MafiaRoles.find('citizen'),
          remainingSeconds: 90,
          canEndDiscussion: true,
          onEndDiscussion: () {},
        ),
      );

      expect(find.text('자유 토론'), findsOneWidget);
      expect(find.text('토론 종료 하기'), findsOneWidget);
    });
  });

  //=======================건달은 투표권을 막습니다==============================
  test('건달은 능력이 아니라 투표권을 막는다', () {
    final gangster = MafiaRoles.find('gangster')!;
    expect(gangster.blocksTargetVote, isTrue);
    expect(gangster.blocksAbility, isFalse);
    // 능력을 막지 않으므로 밤의 앞 구간(차단)에 끼지 않습니다.
    expect(gangster.nightPhase, isNot(MafiaNightPhase.roleblock));

    final madam = MafiaRoles.find('madam')!;
    expect(madam.blocksAbility, isTrue, reason: '마담은 능력까지 막는다');
    expect(madam.nightPhase, MafiaNightPhase.roleblock);
  });

  //=======================자경단원 설명==============================
  test('자경단원 카드에 1회 제한과 오발이 적혀 있다', () {
    final vigilante = MafiaRoles.find('vigilante')!;
    expect(vigilante.description, contains('1번'));
    expect(vigilante.description, contains('시민'));
    // 밤 문구는 '제거'가 아니라 '처형'입니다(확정 2026-08).
    expect(vigilante.nightPromptVerb, '처형');
  });
}

/// 그 글자가 들어 있는 버튼의 목표 불투명도입니다.
double opacityOf(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(finder.first).opacity;
}
