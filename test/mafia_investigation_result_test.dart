import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';

//=======================경찰 조사 결과==============================
// 확정(2026-08): 결과가 마피아면 대상 사진의 테두리를 마피아 진영 색(빨강)으로
// 칠합니다. 결과 문구를 읽기 전에 색만으로 먼저 읽히게 하려는 것입니다.
//
// 진영은 **서버가 보낸 결과 문구**로만 판단합니다. 밀러(시민인데 마피아로
// 보임)·마피아 보스(마피아인데 시민으로 보임)를 클라이언트가 다시 계산하면
// 규칙이 깨집니다.
void main() {
  const target = MafiaPlayer(
    uid: 'target',
    nickname: '조사대상',
    profileImageUrl: '',
  );

  Future<Color?> borderColorOf(WidgetTester tester, String verdict) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MafiaNightActionView(
          role: MafiaRoles.find('police'),
          investigationResult: MafiaNightInvestigationResult(
            target: target,
            verdict: verdict,
          ),
          onConfirmResult: () {},
        ),
      ),
    );
    await tester.pump();

    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.border != null)
        .toList();
    final border = decorated
        .map((decoration) => decoration.border)
        .whereType<Border>()
        .firstWhere((border) => border.top.width > 0);
    return border.top.color;
  }

  testWidgets('마피아로 나오면 테두리가 빨간색이다', (tester) async {
    expect(await borderColorOf(tester, '마피아'), MafiaFactionColors.mafia);
  });

  testWidgets('시민으로 나오면 조사 색(하늘색) 테두리를 유지한다', (tester) async {
    final investigate = MafiaRoles.find('police')!.nightAction.accentColor;
    expect(await borderColorOf(tester, '시민'), investigate);
    expect(investigate, isNot(MafiaFactionColors.mafia));
  });

  test('정보원이 받는 마피아 진영 역할 이름도 마피아로 읽는다', () {
    bool showsMafia(String verdict) => MafiaNightInvestigationResult(
      target: target,
      verdict: verdict,
    ).showsMafia;

    expect(showsMafia('마피아'), isTrue);
    expect(showsMafia('마피아 보스'), isTrue);
    expect(showsMafia('야쿠자'), isTrue);
    expect(showsMafia('시민'), isFalse);
    expect(showsMafia('경찰'), isFalse);
    // 중립은 마피아가 아닙니다.
    expect(showsMafia('광대'), isFalse);
    // 추적자처럼 닉네임이 오는 결과와 빈 값도 색을 바꾸지 않습니다.
    expect(showsMafia('플레이어1'), isFalse);
    expect(showsMafia(''), isFalse);
  });
}
