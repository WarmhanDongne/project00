import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';
import 'package:project00/games/mafia/widgets/phone/role_card_layer.dart';
import 'package:project00/games/mafia/widgets/phone/vote_view.dart';

//=======================2026-08 추가 역할의 화면 상태==============================
// 새 역할은 "고를 수 없는 밤"과 "투표할 수 없는 낮"을 만듭니다. 그 상태에서
// 막힌 화면(비활성 그리드)을 보여 주면 안 되고, **다른 사람과 겉모습이 같은
// 대기 화면**이어야 합니다. 겉모습이 갈리면 옆에서 보고 신분을 알 수 있습니다.
void main() {
  List<MafiaPlayer> buildPlayers(int count) => [
    for (var i = 0; i < count; i += 1)
      MafiaPlayer(
        uid: 'u$i',
        nickname: '플레이어$i',
        profileImageUrl: '',
        seatIndex: i,
      ),
  ];

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  //=======================밤 — 능력을 다 쓴 경우 (자경단원)============
  testWidgets('능력을 다 쓴 밤은 대기 화면이고 선택 완료 버튼이 없다', (tester) async {
    await pumpPhone(
      tester,
      MafiaNightActionView(
        role: MafiaRoles.find('vigilante'),
        players: buildPlayers(5),
        abilityExhausted: true,
        remainingSeconds: 40,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('선택 완료'), findsNothing);
    // 안내 문구(`제거 할 대상을 …`)도 나오지 않아야 합니다.
    expect(find.textContaining('대상을 선택하세요'), findsNothing);
  });

  testWidgets('능력이 남아 있으면 평소처럼 고를 수 있다', (tester) async {
    await pumpPhone(
      tester,
      MafiaNightActionView(
        role: MafiaRoles.find('vigilante'),
        players: buildPlayers(5),
        remainingSeconds: 40,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('선택 완료'), findsOneWidget);
  });

  //=======================밤 — 사망자를 고르는 역할 (영매·도둑)========
  test('영매와 도둑만 사망자를 고른다', () {
    final deadPickers = MafiaRoles.implemented
        .where((role) => role.targetsDead)
        .map((role) => role.id)
        .toSet();
    expect(deadPickers, {'medium', 'thief'});
  });

  testWidgets('사망자가 없는 첫 밤에는 영매도 대기 화면이다', (tester) async {
    await pumpPhone(
      tester,
      MafiaNightActionView(
        // 호출부가 사망자 명단을 넘기므로 첫 밤에는 비어 있습니다.
        role: MafiaRoles.find('medium'),
        players: const [],
        remainingSeconds: 40,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('선택 완료'), findsNothing);
    expect(find.textContaining('대상을 선택하세요'), findsNothing);
  });

  testWidgets('사망자가 있으면 영매가 교신 대상을 고른다', (tester) async {
    await pumpPhone(
      tester,
      MafiaNightActionView(
        role: MafiaRoles.find('medium'),
        players: buildPlayers(2),
        remainingSeconds: 40,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('선택 완료'), findsOneWidget);
    expect(find.textContaining('교신'), findsOneWidget);
  });

  //=======================낮 — 투표권을 잃은 경우 (마담)===============
  testWidgets('유혹당하면 그리드 없이 이유만 알려 준다', (tester) async {
    await pumpPhone(
      tester,
      MafiaVoteView(
        role: MafiaRoles.find('doctor'),
        players: buildPlayers(5),
        voteBanned: true,
        remainingSeconds: 20,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('이번 낮에는\n투표할 수 없습니다'), findsOneWidget);
    expect(find.text('투표 할 대상을 선택하세요'), findsNothing);
  });

  testWidgets('유혹당하지 않으면 평소처럼 투표한다', (tester) async {
    await pumpPhone(
      tester,
      MafiaVoteView(
        role: MafiaRoles.find('doctor'),
        players: buildPlayers(5),
        remainingSeconds: 20,
        onSelect: (_) {},
        onConfirm: () {},
      ),
    );

    expect(find.text('투표 할 대상을 선택하세요'), findsOneWidget);
  });

  //=======================밤 결과 제목==============================
  test('새 역할의 동사가 그대로 결과 제목이 된다', () {
    // phone_game_screen이 `{동사} 결과`로 만듭니다. 역할 이름으로 분기하지
    // 않으므로 동사가 비어 있지 않은지만 지킵니다.
    for (final id in ['police', 'detective', 'medium', 'thief']) {
      final role = MafiaRoles.find(id)!;
      expect(
        role.nightPromptVerb,
        isNotEmpty,
        reason: '$id: 동사가 없으면 결과 제목이 만들어지지 않습니다',
      );
    }
  });

  //=======================신분 카드의 개인 안내==============================
  // 처형자는 목표를 모르면 역할이 성립하지 않습니다. 새 화면을 만들지 않고
  // 기존 신분 카드 아래에 한 줄로 붙였습니다.
  Future<void> pumpOpenedCard(
    WidgetTester tester, {
    required String roleId,
    String? notice,
  }) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MafiaPhoneRoleCardLayer(
          role: MafiaRoles.find(roleId),
          phaseKey: 'roleReveal',
          isFirstReveal: true,
          notice: notice,
        ),
      ),
    );
    // 카드가 가운데로 내려온 뒤 눌러서 엽니다(카드는 눌러야 뒤집힙니다).
    await tester.pump();
    await tester.pump(MafiaPhoneRoleCardLayer.travelDuration);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(const Offset(201, 400));
    await tester.pump();
    await tester.pump(MafiaPhoneRoleCardLayer.flipDuration);
    await tester.pump(const Duration(milliseconds: 16));
    // 문구는 0.3초 뒤부터 떠오릅니다.
    await tester.pump(MafiaPhoneRoleCardLayer.textDelay);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('처형자의 목표가 신분 카드에 한 줄로 붙는다', (tester) async {
    await pumpOpenedCard(tester, roleId: 'executioner', notice: '목표 · 플레이어2');

    expect(find.text('목표 · 플레이어2'), findsOneWidget);
    // 카드가 내려가기까지 남은 타이머를 흘려보냅니다.
    await tester.pump(MafiaPhoneRoleCardLayer.firstRevealHold);
    await tester.pump(MafiaPhoneRoleCardLayer.travelDuration);
  });

  testWidgets('안내가 없으면 아무 줄도 붙지 않는다', (tester) async {
    await pumpOpenedCard(tester, roleId: 'citizen');

    expect(find.textContaining('목표 ·'), findsNothing);
    expect(find.textContaining('신분이 바뀌었습니다'), findsNothing);
    // 신분 이름 자체는 나옵니다(카드가 열린 상태인지 확인).
    expect(find.textContaining('입니다'), findsOneWidget);
    await tester.pump(MafiaPhoneRoleCardLayer.firstRevealHold);
    await tester.pump(MafiaPhoneRoleCardLayer.travelDuration);
  });

  //=======================신분이 새지 않는지==============================
  test('동료를 모르는 공격 역할은 같은 편 목록에 의존하지 않는다', () {
    // 짐승인간·연쇄살인마는 동료를 모릅니다. 그래서 밤 명단에서 같은 편을 빼는
    // 처리가 이 역할에는 적용될 수 없습니다(적용되면 진영이 드러납니다).
    for (final id in ['beast', 'serial_killer']) {
      final role = MafiaRoles.find(id)!;
      expect(role.nightAction, MafiaNightAction.eliminate, reason: id);
      expect(role.knowsAllies, isFalse, reason: id);
    }
  });
}
