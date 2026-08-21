import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_tally_view.dart';

//=======================투표지·개표 연출==============================
// 확정(2026-08): 투표하면 그 좌석에서 투표지가 투표함으로 날아가 사라지고,
// 개표는 투표함이 이동한 뒤 표가 한 장씩 나와 득표수가 올라갑니다.
void main() {
  Map<String, MafiaPlayer> buildPlayers(int count) => {
    for (var i = 0; i < count; i += 1)
      'u$i': MafiaPlayer(
        uid: 'u$i',
        nickname: '플레이어$i',
        profileImageUrl: '',
        seatIndex: i,
        isAlive: true,
      ),
  };

  group('투표 중 투표지', () {
    Future<void> pumpLayer(WidgetTester tester, List<String> submitted) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MafiaBallotTossLayer(
            submittedUids: submitted,
            seatIndexes: const {'u0': 0, 'u1': 1, 'u2': 2, 'u3': 3},
            boardSeatCount: 4,
          ),
        ),
      );
    }

    testWidgets('새로 투표한 사람이 생기면 종이가 날아간다', (tester) async {
      await pumpLayer(tester, const []);
      expect(find.byType(MafiaBallotPaper), findsNothing);

      // u1이 투표 → 그 좌석에서 한 장이 날아갑니다.
      await pumpLayer(tester, const ['u1']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MafiaBallotPaper), findsOneWidget);

      // 도착하면 투표함에 들어가며 사라집니다.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.byType(MafiaBallotPaper), findsNothing);
    });

    testWidgets('처음부터 투표해 있던 사람은 다시 날리지 않는다', (tester) async {
      // 재접속·재빌드 상황입니다. 이미 낸 표가 또 날아가면 안 됩니다.
      await pumpLayer(tester, const ['u0', 'u1']);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MafiaBallotPaper), findsNothing);
    });
  });

  group('개표', () {
    testWidgets('투표함이 이동한 뒤 표가 나와 득표수가 올라간다', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MafiaTabletTallyView(
            result: const MafiaVoteResult(
              tally: {'u0': 2, 'u1': 1},
              executedUid: 'u0',
              tie: false,
              abstainCount: 0,
            ),
            players: buildPlayers(4),
          ),
        ),
      );

      // 투표함 이동(0.8초) 동안에는 아직 득표수가 없습니다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('표'), findsNothing);

      // 표가 한 장씩 나와 착지하면 득표수가 보입니다.
      var sawCount = false;
      for (var i = 0; i < 15 && !sawCount; i += 1) {
        await tester.pump(const Duration(milliseconds: 150));
        sawCount = find.textContaining('표').evaluate().isNotEmpty;
      }
      expect(sawCount, isTrue, reason: '표가 한 장도 개표되지 않았습니다');

      // 연출이 끝나면 최종 득표수가 남습니다.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('2표'), findsOneWidget);
      expect(find.text('1표'), findsOneWidget);
      expect(find.byType(MafiaBallotPaper), findsNothing);
    });
  });
}
