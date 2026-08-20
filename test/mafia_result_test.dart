import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
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
        contains('background_phone_mafia_win'),
      );
      expect(
        MafiaResultArt.phonePoster(MafiaFaction.citizen)?.path,
        contains('background_phone_sitizen_win'),
      );
      expect(
        MafiaResultArt.tabletPoster(MafiaFaction.mafia)?.path,
        contains('background_tablet_mafia_win'),
      );
      expect(
        MafiaResultArt.tabletPoster(MafiaFaction.citizen)?.path,
        contains('background_tablet_sitizen_win'),
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
}
