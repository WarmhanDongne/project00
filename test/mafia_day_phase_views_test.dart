import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/execution_view.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';
import 'package:project00/games/mafia/widgets/phone/player_select_grid.dart';
import 'package:project00/games/mafia/widgets/phone/spectator_roster_view.dart';
import 'package:project00/games/mafia/widgets/phone/vote_view.dart';

import 'support/ejection_beats.dart';

/// 낮 단계 화면들(P7 투표·처형, P8 관전)입니다.
///
/// 시안이 정한 규칙 중 **틀리면 게임이 어긋나는 것**만 확인합니다. 좌표는
/// 렌더로 눈으로 대조했고, 골든 이미지는 기기·폰트에 따라 달라져 남기지 않습니다.
List<MafiaPlayer> buildPlayers(int count) => [
  for (var i = 0; i < count; i += 1)
    MafiaPlayer(uid: 'u$i', nickname: '플레이어$i', profileImageUrl: ''),
];

void main() {
  group('P7 투표', () {
    Future<void> pump(
      WidgetTester tester, {
      String? selectedUid,
      bool isSubmitted = false,
      int playerCount = 9,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaVoteView(
            role: MafiaRoles.find('citizen'),
            players: buildPlayers(playerCount),
            selectedUid: selectedUid,
            remainingSeconds: 30,
            isSubmitted: isSubmitted,
            onSelect: (_) {},
            onConfirm: () {},
          ),
        ),
      );
    }

    testWidgets('낮 배경이라 안내·타이머가 검은색이다', (tester) async {
      await pump(tester);

      expect(
        tester.widget<Text>(find.text('투표 할 대상을 선택하세요')).style?.color,
        Colors.black,
      );
      expect(tester.widget<Text>(find.text('30초')).style?.color, Colors.black);
    });

    testWidgets('대상을 고르기 전에는 버튼이 비활성이다', (tester) async {
      await pump(tester);

      expect(
        tester
            .widget<MafiaPhoneActionButton>(find.byType(MafiaPhoneActionButton))
            .enabled,
        isFalse,
      );
    });

    testWidgets('대상을 고르면 버튼이 활성되고 나머지가 흐려진다', (tester) async {
      await pump(tester, selectedUid: 'u4');

      expect(
        tester
            .widget<MafiaPhoneActionButton>(find.byType(MafiaPhoneActionButton))
            .enabled,
        isTrue,
      );

      final grid = tester.widget<MafiaPlayerSelectGrid>(
        find.byType(MafiaPlayerSelectGrid),
      );
      // 밤 지목과 달리 낮 투표는 고른 뒤 나머지를 흐립니다.
      expect(grid.dimsUnselected, isTrue);
      expect(grid.nicknameColor, Colors.black);
      expect(grid.selectionColor, MafiaVoteView.selectionColor);
      expect(grid.selectionBorderWidth, 3);
    });

    testWidgets('표를 내면 그리드·타이머가 사라지고 대기 문구만 남는다', (tester) async {
      await pump(tester, selectedUid: 'u4', isSubmitted: true);

      expect(find.byType(MafiaPlayerSelectGrid), findsNothing);
      expect(find.text('30초'), findsNothing);
      expect(find.byType(MafiaPhoneActionButton), findsNothing);
      expect(find.textContaining('기다리는 중입니다'), findsOneWidget);
    });

    testWidgets('12인이면 그리드가 4열로 바뀐다', (tester) async {
      await pump(tester, playerCount: 12);

      expect(MafiaPlayerSelectGrid.columnsFor(12), 4);
      expect(find.byType(MafiaPlayerSelectGrid), findsOneWidget);
    });
  });

  group('P7 처형자 발표', () {
    testWidgets('처형된 사람의 닉네임과 문구를 보여 준다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionResultView(
            role: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
          ),
        ),
      );

      expect(find.text('오늘의 처형자'), findsOneWidget);
      expect(find.text('플레이어0'), findsOneWidget);
      // 확정(2026-08): 긴 발표는 두 박자로 나뉘어 내려찍힙니다.
      expect(find.text('플레이어0님이'), findsOneWidget);
      await pumpUntilText(tester, '처형되었습니다');
    });

    testWidgets('당사자는 다른 문구를 보고 아래 문구가 없다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionResultView(
            role: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
            isMe: true,
          ),
        ),
      );

      expect(find.text('당신은 처형 당했습니다'), findsOneWidget);
      expect(find.text('오늘의 처형자'), findsNothing);
      expect(find.text('플레이어0'), findsOneWidget);
      // 제목에서 이미 알렸으므로 같은 말을 두 번 하지 않습니다.
      expect(find.textContaining('처형되었습니다'), findsNothing);
    });

    testWidgets('당사자 닉네임은 시안대로 Light다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionResultView(
            role: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
            isMe: true,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('플레이어0')).style?.fontWeight,
        FontWeight.w300,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionResultView(
            role: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('플레이어0')).style?.fontWeight,
        FontWeight.w400,
      );
    });

    testWidgets('아무도 처형되지 않으면 그 사실을 알린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionResultView(
            role: MafiaRoles.find('citizen'),
            executed: null,
          ),
        ),
      );

      expect(find.text('처형된 사람이 없습니다'), findsOneWidget);
      expect(find.textContaining('처형되었습니다'), findsNothing);
    });
  });

  group('P7 신분 공개', () {
    testWidgets('카드가 뒤집히면 신분 문구가 나타나고 알림이 온다', (tester) async {
      var revealed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionRevealView(
            myRole: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
            executedRole: MafiaRoles.find('mafia'),
            onRevealed: () => revealed = true,
          ),
        ),
      );

      // 카드가 절반 돌아가기 전에는 신분 문구가 아직 없습니다.
      expect(find.text('플레이어0님은'), findsNothing);
      expect(revealed, isFalse);

      await tester.pump(MafiaExecutionRevealView.revealDelay);
      await tester.pump(MafiaExecutionRevealView.flipDuration);

      // 뒤집힌 뒤 두 박자로 찍힙니다.
      await pumpUntilText(tester, '플레이어0님은');
      await pumpUntilText(tester, '마피아였습니다');
      expect(revealed, isTrue);
    });

    testWidgets('재접속 복원은 연출 없이 공개 상태로 시작한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionRevealView(
            myRole: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
            executedRole: MafiaRoles.find('mafia'),
            initiallyRevealed: true,
          ),
        ),
      );

      // 연출 시간이 지나기 전에 이미 공개된 상태여야 합니다.
      expect(find.text('플레이어0님은'), findsOneWidget);
      await pumpUntilText(tester, '마피아였습니다');
    });

    testWidgets('이 빌드가 모르는 신분이면 확인할 수 없다고 알린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaExecutionRevealView(
            myRole: MafiaRoles.find('citizen'),
            executed: buildPlayers(1).first,
            executedRole: null,
          ),
        ),
      );

      await tester.pump(MafiaExecutionRevealView.revealDelay);
      await tester.pump(MafiaExecutionRevealView.flipDuration);
      await pumpUntilText(tester, '플레이어0님의');
      await pumpUntilText(tester, '신분을 확인할 수 없습니다');
    });
  });

  group('P8 관전자 정보', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool isNight,
      int playerCount = 9,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaSpectatorRosterView(
            myRole: MafiaRoles.find('citizen'),
            isNight: isNight,
            revealed: [
              for (final player in buildPlayers(playerCount))
                MafiaRevealedPlayer(
                  player: player,
                  role: MafiaRoles.find('mafia'),
                ),
            ],
          ),
        ),
      );
    }

    testWidgets('낮에는 글자가 검은색, 밤에는 흰색이다', (tester) async {
      await pump(tester, isNight: false);
      expect(
        tester.widget<Text>(find.text('관전자 정보')).style?.color,
        Colors.black,
      );

      await pump(tester, isNight: true);
      expect(
        tester.widget<Text>(find.text('관전자 정보')).style?.color,
        Colors.white,
      );
    });

    testWidgets('모든 플레이어의 닉네임을 보여 준다', (tester) async {
      await pump(tester, isNight: false);

      for (var i = 0; i < 9; i += 1) {
        expect(find.text('플레이어$i'), findsOneWidget);
      }
    });

    testWidgets('카드 에셋이 없는 역할은 이름으로 대신 알린다', (tester) async {
      // 카드가 없는 역할을 목록에서 직접 찾습니다. 카드가 하나씩 들어와도
      // 이 테스트가 낡지 않게 특정 역할을 박지 않습니다.
      final noCard = MafiaRoles.all.where((role) => role.card == null).toList();
      if (noCard.isEmpty) {
        // 모든 역할에 카드가 생기면 이 대체 표시는 더 필요하지 않습니다.
        return;
      }
      final role = noCard.first;

      await tester.pumpWidget(
        MaterialApp(
          home: MafiaSpectatorRosterView(
            myRole: MafiaRoles.find('citizen'),
            isNight: false,
            revealed: [
              MafiaRevealedPlayer(player: buildPlayers(1).first, role: role),
            ],
          ),
        ),
      );

      // 뒷면만 두면 어떤 신분인지 알 수 없어 이 화면의 목적이 무너집니다.
      expect(find.text(role.displayName), findsOneWidget);
    });

    testWidgets('이 빌드가 모르는 신분은 이름 없이도 깨지지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaSpectatorRosterView(
            myRole: MafiaRoles.find('citizen'),
            isNight: false,
            revealed: [
              MafiaRevealedPlayer(player: buildPlayers(1).first, role: null),
            ],
          ),
        ),
      );

      expect(find.text('플레이어0'), findsOneWidget);
    });

    testWidgets('12인이면 명단도 4열로 바뀐다', (tester) async {
      await pump(tester, isNight: false, playerCount: 12);

      expect(MafiaTileGridSpec.of(12).columns, 4);
      // 4열 3행이 관전 화면 시작점(203)에서도 버튼 자리를 넘지 않습니다.
      expect(
        MafiaSpectatorRosterView.gridTop +
            MafiaTileGridSpec.of(12).sizeFor(12).height,
        lessThanOrEqualTo(MafiaPhoneDesign.buttonTop),
      );
    });
  });
}
