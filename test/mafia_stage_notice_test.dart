import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/announcement_reveal.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/mafia_flow_config.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';

import 'support/ejection_beats.dart';

//=======================단계 안내 순서==============================
// 확정(2026-08): 아침은 '아침이 되었습니다' → 사망자 발표 → '토론을 시작합니다'
// 세 박자이고, 개표 발표는 마지막에 '밤이 되었습니다'로 끝납니다.
void main() {
  final players = {
    'u0': const MafiaPlayer(
      uid: 'u0',
      nickname: '가나',
      profileImageUrl: '',
      seatIndex: 0,
    ),
  };

  Future<void> pumpTablet(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  testWidgets('아침은 안내 → 발표 → 토론 안내 순서로 흐른다', (tester) async {
    await pumpTablet(
      tester,
      MafiaTabletMorningSequence(
        result: const MafiaMorningResult(deadUids: ['u0'], savedCount: 0),
        players: players,
      ),
    );

    // 1박자: 아침 안내만 떠오릅니다. 사망자 발표는 아직 나오지 않습니다.
    await tester.pump();
    expect(find.text(MafiaCopy.morningNotice), findsOneWidget);
    expect(find.text('가나님은'), findsNothing);

    // 2박자: 안내가 물러난 뒤 사망자 발표가 떠오릅니다.
    // 확정(2026-08): 긴 발표는 '가나님은' → '밤을 넘기지 못했습니다' 두 방으로
    // 나뉘어 내려찍힙니다.
    await pumpUntilText(tester, '가나님은');
    // 발표가 붙는 프레임과 안내가 걷히는 프레임이 겹칠 수 있어 한 박 둡니다.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(MafiaCopy.morningNotice), findsNothing);
    await pumpUntilText(tester, '밤을 넘기지 못했습니다');

    // 3박자: 발표가 물러나고 토론 시작 안내가 떠오릅니다.
    await pumpUntilText(
      tester,
      MafiaCopy.discussionNotice,
      limit:
          MafiaTabletMorningSequence.announcementHold +
          MafiaAnnouncementReveal.exitDuration +
          MafiaAnnouncementReveal.enterDuration,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('밤을 넘기지 못했습니다'), findsNothing);
  });

  testWidgets('개표 발표는 밤 안내로 끝난다', (tester) async {
    await pumpTablet(
      tester,
      MafiaTabletVoteResultSequence(
        result: const MafiaVoteResult(
          tally: {'u0': 1},
          executedUid: 'u0',
          tie: false,
          abstainCount: 0,
        ),
        players: players,
        executed: players['u0'],
        executedRole: null,
      ),
    );

    await tester.pump();
    expect(find.text(MafiaCopy.nightNotice), findsNothing);

    // 개표(4초) → 처형 발표(9초)가 끝나면 밤 안내가 떠오릅니다.
    await tester.pump(MafiaTabletVoteResultSequence.tallyHold);
    await tester.pump(MafiaAnnouncementReveal.exitDuration);
    await tester.pump(MafiaTabletVoteResultSequence.executionHold);
    await tester.pump(MafiaAnnouncementReveal.exitDuration);
    await tester.pump(MafiaAnnouncementReveal.enterDuration);
    expect(find.text(MafiaCopy.nightNotice), findsOneWidget);
  });

  test('단계 시간이 연출 박자의 합과 같다', () {
    // 한쪽만 바꾸면 안내가 잘리거나 빈 화면이 남습니다.
    expect(
      MafiaTabletStage.morning.announcementHold,
      MafiaTabletMorningSequence.totalHold,
    );
    expect(
      MafiaTabletStage.voteResult.announcementHold,
      MafiaTabletVoteResultSequence.totalHold,
    );
    // 아침은 2.5 + 8 + 2.5 = 13초입니다.
    expect(MafiaTabletMorningSequence.totalHold.inMilliseconds, 13000);
    // 개표는 4 + 9 + 2.5 = 15.5초입니다.
    expect(MafiaTabletVoteResultSequence.totalHold.inMilliseconds, 15500);
  });

  test('토론 시간은 생존 인원을 따른다', () {
    expect(MafiaTiming.discussion(2).inSeconds, 90);
    expect(MafiaTiming.discussion(3).inSeconds, 90);
    expect(MafiaTiming.discussion(4).inSeconds, 120);
    expect(MafiaTiming.discussion(6).inSeconds, 180);
    expect(MafiaTiming.discussion(8).inSeconds, 240);
    expect(MafiaTiming.discussion(10).inSeconds, 300);
    // 표에 없는 인원은 양 끝 값을 씁니다.
    expect(MafiaTiming.discussion(1).inSeconds, 90);
    expect(MafiaTiming.discussion(12).inSeconds, 300);
  });
}
