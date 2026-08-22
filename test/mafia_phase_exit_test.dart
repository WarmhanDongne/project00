import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_phase_views.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/night_action_view.dart';

//=======================단계가 끝날 때 사라지는 것들==============================
// 확정(2026-08)
// - 태블릿 카드 확인 숫자는 전원이 확인하면(4/4) 곧바로 사라집니다.
// - 밤 화면의 안내 문구·선택 그리드·'선택 완료' 버튼은 제출하면 **함께**
//   부드럽게 사라집니다. 버튼만 따로 흐려지면 문구는 툭 끊겨 보입니다.
void main() {
  List<MafiaPlayer> players(int count) => [
    for (var i = 0; i < count; i += 1)
      MafiaPlayer(
        uid: 'u$i',
        nickname: '플레이어$i',
        profileImageUrl: '',
        seatIndex: i,
      ),
  ];

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = MafiaPhoneDesign.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  double opacityAbove(WidgetTester tester, Finder finder) {
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: finder, matching: find.byType(FadeTransition)).first,
    );
    return fade.opacity.value;
  }

  //=======================태블릿 카드 확인 숫자==============================
  testWidgets('전원이 확인하면 확인 숫자가 곧바로 사라진다', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<double> pumpDeal(int confirmed) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaTabletRoleDealView(
            players: players(4),
            confirmedCount: confirmed,
          ),
        ),
      );
      // 카드가 다 날아가야(더미가 비어야) 숫자가 드러납니다. 분배 연출은
      // 인원수만큼 시간차를 두므로 넉넉히 돌립니다.
      for (var i = 0; i < 40; i += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .opacity;
    }

    // 아직 한 명이 남았으면 숫자가 보입니다.
    expect(await pumpDeal(3), 1);
    // 4/4가 되면 곧바로 거둡니다.
    expect(await pumpDeal(4), 0);
  });

  //=======================밤 선택 화면==============================
  testWidgets('제출하면 문구와 선택 완료 버튼이 같은 속도로 함께 사라진다', (tester) async {
    Widget nightView({required bool isSubmitted}) => MafiaNightActionView(
      role: MafiaRoles.find('police'),
      players: players(4),
      selectedUid: 'u1',
      isSubmitted: isSubmitted,
      onSelect: (_) {},
      onConfirm: () {},
    );

    await pumpPhone(tester, nightView(isSubmitted: false));
    expect(find.text('선택 완료'), findsOneWidget);
    expect(find.textContaining('대상을 선택하세요'), findsOneWidget);

    // 제출한 직후: 문구와 버튼이 같은 투명도로 함께 흐려집니다.
    await tester.pumpWidget(MaterialApp(home: nightView(isSubmitted: true)));
    await tester.pump(MafiaNightActionView.modeFadeDuration ~/ 2);

    final buttonOpacity = opacityAbove(
      tester,
      find.byType(MafiaPhoneActionButton),
    );
    final promptOpacity = opacityAbove(
      tester,
      find.textContaining('대상을 선택하세요'),
    );
    expect(buttonOpacity, lessThan(1));
    expect(buttonOpacity, greaterThan(0));
    expect(promptOpacity, buttonOpacity);

    // 전환이 끝나면 둘 다 트리에서 빠집니다.
    await tester.pumpAndSettle();
    expect(find.text('선택 완료'), findsNothing);
    expect(find.textContaining('대상을 선택하세요'), findsNothing);
    expect(find.text('선택을 완료했습니다'), findsOneWidget);
  });
}
