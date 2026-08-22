import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_result_view.dart';
import 'package:project00/games/mafia/widgets/mafia_flip_card.dart';

//=======================태블릿 결과 화면(시안 988:368)==============================
// 확정 순서: 승리 배경 → 2초 또는 탭 → 흰 판 → 카드가 한 장씩 놓임 →
// 놓인 순서대로 뒤집혀 신분 공개.
void main() {
  ({Map<String, MafiaPlayer> players, Map<String, MafiaRole?> roles}) build(
    int count,
  ) {
    final players = <String, MafiaPlayer>{};
    final roles = <String, MafiaRole?>{};
    for (var i = 0; i < count; i += 1) {
      final uid = 'u$i';
      players[uid] = MafiaPlayer(
        uid: uid,
        nickname: '플레이어$i',
        profileImageUrl: '',
        seatIndex: i,
        isAlive: i.isEven,
      );
      roles[uid] = MafiaRoles.find(i == 0 ? 'mafia' : 'citizen');
    }
    return (players: players, roles: roles);
  }

  Future<void> pumpResult(
    WidgetTester tester, {
    int count = 6,
    VoidCallback? onRestart,
  }) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = build(count);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaTabletResultView(
          winner: MafiaFaction.mafia,
          players: data.players,
          revealedRoles: data.roles,
          onRestart: onRestart,
        ),
      ),
    );
  }

  /// 연출이 끝날 때까지 넉넉히 돌립니다.
  Future<void> runReveal(WidgetTester tester) async {
    await tester.pump(MafiaTabletResultView.posterHold);
    for (var i = 0; i < 12; i += 1) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('승리 배경만 먼저 보이고 2초 뒤 판과 카드가 나온다', (tester) async {
    await pumpResult(tester);

    // 1박자: 배경 그림만. 카드도 버튼도 없습니다.
    await tester.pump();
    expect(find.byType(MafiaFlipCard), findsNothing);
    expect(find.text('다시하기'), findsNothing);

    // 2박자 이후: 카드가 놓이고 닉네임이 붙습니다.
    await runReveal(tester);
    expect(find.byType(MafiaFlipCard), findsNWidgets(6));
    expect(find.text('플레이어0'), findsOneWidget);
    expect(find.text('플레이어5'), findsOneWidget);
    expect(find.text('다시하기'), findsOneWidget);
    expect(find.text('홈으로'), findsOneWidget);
  });

  testWidgets('카드는 한 장씩 차례로 놓이고 앞 카드부터 뒤집힌다', (tester) async {
    await pumpResult(tester);
    await tester.pump(MafiaTabletResultView.posterHold);

    // 판이 올라온 직후에는 아직 카드가 다 놓이지 않았습니다.
    await tester.pump(MafiaTabletResultView.panelIn);
    await tester.pump(const Duration(milliseconds: 120));
    final early = tester.widgetList<MafiaFlipCard>(find.byType(MafiaFlipCard));
    expect(early.length, lessThan(6), reason: '카드가 한꺼번에 놓였습니다');

    // 뒤집기가 시작되면 앞 카드가 뒤 카드보다 더 뒤집혀 있습니다.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    final flips = tester
        .widgetList<MafiaFlipCard>(find.byType(MafiaFlipCard))
        .map((card) => card.progress)
        .toList();
    expect(flips.length, 6);
    expect(flips.first, greaterThan(flips.last), reason: '앞 카드부터 뒤집혀야 합니다');
  });

  testWidgets('12인이면 6장씩 두 줄로 놓인다', (tester) async {
    await pumpResult(tester, count: 12);
    await runReveal(tester);

    expect(find.byType(MafiaFlipCard), findsNWidgets(12));
    final first = tester.getRect(find.byType(MafiaFlipCard).first);
    final seventh = tester.getRect(find.byType(MafiaFlipCard).at(6));
    // 일곱 번째 카드는 둘째 줄이라 더 아래에 있고, 왼쪽 끝으로 돌아옵니다.
    expect(seventh.top, greaterThan(first.bottom));
    expect(seventh.left, closeTo(first.left, 1));
    // 카드는 판(시안 44~1149) 안에 들어갑니다.
    final last = tester.getRect(find.byType(MafiaFlipCard).last);
    expect(first.left, greaterThan(44));
    expect(last.right, lessThan(1149));
  });

  testWidgets('4인이면 한 줄이 가운데에 놓인다', (tester) async {
    await pumpResult(tester, count: 4);
    await runReveal(tester);

    expect(find.byType(MafiaFlipCard), findsNWidgets(4));
    final first = tester.getRect(find.byType(MafiaFlipCard).first);
    final last = tester.getRect(find.byType(MafiaFlipCard).last);
    // 묶음 가운데가 판 가운데(44 + 1105/2 = 596.5)와 맞습니다.
    expect((first.left + last.right) / 2, closeTo(596.5, 1));
  });

  testWidgets('연출이 끝난 뒤에도 버튼이 눌린다', (tester) async {
    var restarts = 0;
    await pumpResult(tester, onRestart: () => restarts += 1);
    await runReveal(tester);

    await tester.tap(find.text('다시하기'));
    expect(restarts, 1);
  });

  testWidgets('화면을 누르면 2초를 기다리지 않는다', (tester) async {
    await pumpResult(tester);
    await tester.pump();
    expect(find.byType(MafiaFlipCard), findsNothing);

    await tester.tapAt(const Offset(597, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MafiaFlipCard), findsWidgets);
  });
}
