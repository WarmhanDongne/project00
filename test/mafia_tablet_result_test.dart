import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_result_view.dart';

//=======================태블릿 결과 화면(시안 1113:13·16)==============================
// 확정 순서: 승리 배경 → 2초 또는 화면 탭 → 명단판 → 진영·신분 공개.
void main() {
  /// 시민 [citizens]명 + 마피아 [mafia]명으로 판을 짭니다.
  ({Map<String, MafiaPlayer> players, Map<String, MafiaRole?> roles}) build({
    int citizens = 3,
    int mafia = 1,
  }) {
    final players = <String, MafiaPlayer>{};
    final roles = <String, MafiaRole?>{};
    var seat = 0;
    for (var i = 0; i < mafia; i += 1) {
      final uid = 'm$i';
      players[uid] = MafiaPlayer(
        uid: uid,
        nickname: '마피아$i',
        profileImageUrl: '',
        seatIndex: seat++,
      );
      roles[uid] = MafiaRoles.find('mafia');
    }
    for (var i = 0; i < citizens; i += 1) {
      final uid = 'c$i';
      players[uid] = MafiaPlayer(
        uid: uid,
        nickname: '시민$i',
        profileImageUrl: '',
        seatIndex: seat++,
      );
      roles[uid] = MafiaRoles.find('citizen');
    }
    return (players: players, roles: roles);
  }

  Future<void> pumpResult(
    WidgetTester tester, {
    int citizens = 3,
    int mafia = 1,
    VoidCallback? onRestart,
  }) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = build(citizens: citizens, mafia: mafia);
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

  testWidgets('승리 배경만 먼저 보이고 2초 뒤 명단이 올라온다', (tester) async {
    await pumpResult(tester);

    // 1박자: 배경 그림만. 문구도 버튼도 없습니다.
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('마피아진영'), findsNothing);
    expect(find.text('다시하기'), findsNothing);

    // 2박자: 2초가 지나면 명단판이 올라옵니다.
    await tester.pump(MafiaTabletResultView.posterHold);
    await tester.pump();
    expect(find.text('마피아진영'), findsOneWidget);
    expect(find.text('시민진영'), findsOneWidget);
    expect(find.text('중립진영'), findsOneWidget);

    // 3박자: 신분 + 닉네임과 버튼이 드러납니다.
    await tester.pumpAndSettle();
    expect(find.text('마피아 마피아0'), findsOneWidget);
    expect(find.text('시민 시민0'), findsOneWidget);
    expect(find.text('다시하기'), findsOneWidget);
    expect(find.text('홈으로'), findsOneWidget);
  });

  testWidgets('화면을 누르면 2초를 기다리지 않는다', (tester) async {
    await pumpResult(tester);
    await tester.pump();
    expect(find.text('마피아진영'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(597, 417));
    await tester.pump();
    expect(find.text('마피아진영'), findsOneWidget);
  });

  testWidgets('명단이 올라온 뒤에도 버튼이 눌린다', (tester) async {
    var restarts = 0;
    await pumpResult(tester, onRestart: () => restarts += 1);
    await tester.pump(MafiaTabletResultView.posterHold);
    await tester.pumpAndSettle();

    // 화면 전체를 덮는 탭 레이어가 버튼을 가리지 않아야 합니다.
    await tester.tap(find.text('다시하기'));
    expect(restarts, 1);
  });

  testWidgets('12인(시민 9명) 명단도 판 안에 들어간다', (tester) async {
    // 12인 구성은 시민 진영이 9명입니다. 시안은 6줄이라 줄 간격이 좁아집니다.
    await pumpResult(tester, citizens: 9, mafia: 3);
    await tester.pump(MafiaTabletResultView.posterHold);
    await tester.pumpAndSettle();

    for (var i = 0; i < 9; i += 1) {
      expect(find.text('시민 시민$i'), findsOneWidget);
    }
    // 마지막 줄이 버튼 자리(627)를 넘지 않아야 합니다.
    final lastRow = tester.getRect(find.text('시민 시민8'));
    expect(lastRow.bottom, lessThanOrEqualTo(627));
    // 세 칸의 첫 줄은 같은 높이에서 시작합니다.
    expect(
      tester.getRect(find.text('마피아 마피아0')).top,
      closeTo(tester.getRect(find.text('시민 시민0')).top, 0.5),
    );
  });
}
