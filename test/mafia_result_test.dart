import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_result_view.dart';
import 'package:project00/games/mafia/widgets/phone/result_sequence.dart';
import 'package:project00/games/mafia/widgets/phone/result_view.dart';

/// 결과 화면(P9)입니다.
///
/// 승리 진영에 **맞는 그림**이 나가는지가 핵심입니다. 마피아가 이겼는데 시민
/// 포스터가 뜨면 게임 결과를 잘못 알리는 것이므로, 대응을 직접 확인합니다.
void main() {
  group('진영별 그림 대응', () {
    test('휴대폰·태블릿 포스터가 승리 진영과 맞는다', () {
      expect(
        MafiaResultArt.phonePoster(MafiaFaction.mafia)?.path,
        contains('background_mafia_win_phone'),
      );
      expect(
        MafiaResultArt.phonePoster(MafiaFaction.citizen)?.path,
        contains('background_citizen_win_phone'),
      );
      expect(
        MafiaResultArt.tabletPoster(MafiaFaction.mafia)?.path,
        contains('background_mafia_win.png'),
      );
      expect(
        MafiaResultArt.tabletPoster(MafiaFaction.citizen)?.path,
        contains('background_citizen_win.png'),
      );
    });

    test('배너는 승리 진영이 승리 배너, 반대편이 패배 배너를 쓴다', () {
      expect(
        MafiaResultArt.winnerBanner(MafiaFaction.mafia)?.path,
        contains('banner_mafia_win'),
      );
      expect(
        MafiaResultArt.loserBanner(MafiaFaction.mafia)?.path,
        contains('banner_citizen_lose'),
      );
      expect(
        MafiaResultArt.winnerBanner(MafiaFaction.citizen)?.path,
        contains('banner_citizen_win'),
      );
      expect(
        MafiaResultArt.loserBanner(MafiaFaction.citizen)?.path,
        contains('banner_mafia_lose'),
      );
    });

    test('패배 진영은 승리 진영의 반대편이다', () {
      expect(MafiaResultArt.loserOf(MafiaFaction.mafia), MafiaFaction.citizen);
      expect(MafiaResultArt.loserOf(MafiaFaction.citizen), MafiaFaction.mafia);
      // 중립은 진영 대결이 아니라 개별 조건이므로 상대가 정해지지 않습니다.
      expect(MafiaResultArt.loserOf(MafiaFaction.neutral), isNull);
    });

    test('중립 승리는 전용 그림이 없어 null이다', () {
      expect(MafiaResultArt.phonePoster(MafiaFaction.neutral), isNull);
      expect(MafiaResultArt.tabletPoster(MafiaFaction.neutral), isNull);
      expect(MafiaResultArt.winnerBanner(MafiaFaction.neutral), isNull);
      expect(MafiaResultArt.phonePoster(null), isNull);
    });

    test('진영 색은 한 곳에서만 정의된다', () {
      expect(MafiaFaction.citizen.color, MafiaFactionColors.citizen);
      expect(MafiaFaction.mafia.color, MafiaFactionColors.mafia);
      expect(MafiaFaction.neutral.color, MafiaFactionColors.neutral);
    });
  });

  group('휴대폰 결과 화면', () {
    testWidgets('포스터가 있으면 그림만 보여 준다 (문구·버튼 없음)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MafiaResultView(winner: MafiaFaction.mafia)),
      );

      // 시안대로 문구가 없습니다. 다시하기·홈으로는 태블릿에만 있습니다.
      expect(find.byType(Text), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('포스터가 없는 중립 승리는 문구로 대신 알린다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MafiaResultView(
            winner: MafiaFaction.neutral,
            winnerLabel: '광대 승리',
          ),
        ),
      );

      expect(find.text('광대 승리'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('광대 승리')).style?.color,
        MafiaFactionColors.neutral,
      );
    });

    testWidgets('승리 진영을 모르면 게임 종료로 알린다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MafiaResultView(winner: null)),
      );

      expect(find.text('게임 종료'), findsOneWidget);
    });
  });

  group('휴대폰 결과 순서 (확정 2026-08)', () {
    Future<void> pumpSequence(WidgetTester tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaPhoneResultSequence(
            winner: MafiaFaction.citizen,
            players: const [
              MafiaPlayer(
                uid: 'u0',
                nickname: '가나',
                profileImageUrl: '',
                seatIndex: 0,
              ),
              MafiaPlayer(
                uid: 'u1',
                nickname: '다라',
                profileImageUrl: '',
                seatIndex: 1,
              ),
            ],
            revealedRoles: {'u0': null, 'u1': null},
          ),
        ),
      );
    }

    testWidgets('승리 그림을 2초 보여 준 뒤 전원 신분 명단으로 넘어간다', (tester) async {
      await pumpSequence(tester);

      // 1박자: 그림만. 닉네임은 아직 없습니다.
      await tester.pump();
      expect(find.byType(MafiaResultView), findsOneWidget);
      expect(find.text('가나'), findsNothing);

      // 2박자: 2초 뒤 명단이 떠오릅니다.
      await tester.pump(MafiaPhoneResultSequence.defaultPosterHold);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MafiaResultView), findsNothing);
      expect(find.text('가나'), findsOneWidget);
      expect(find.text('다라'), findsOneWidget);
    });

    test('휴대폰과 태블릿의 승리 화면 시간이 같다', () {
      expect(
        MafiaPhoneResultSequence.defaultPosterHold,
        MafiaTabletResultView.posterHold,
      );
      expect(
        MafiaPhoneResultSequence.defaultPosterHold,
        const Duration(seconds: 2),
      );
    });
  });
}
