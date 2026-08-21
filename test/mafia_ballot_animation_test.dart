import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/ballot_animations.dart';
import 'package:project00/games/mafia/models/mafia_player.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_day_view.dart';
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

  group('투표함 자리', () {
    test('투표함이 삽화 속 모자를 가리지 않는다', () {
      // 확정(2026-08): 투표함은 삽화 가운데(어두운 탁자) 위에 뜨지만,
      // 아래쪽 모자를 덮으면 안 됩니다. 투표함을 키우거나 내릴 때 이 검사가
      // 먼저 실패합니다.
      final box = MafiaBallotBoxRects.voting;
      final hat = MafiaTabletDayView.hatRegion;
      expect(box.overlaps(hat), isFalse, reason: '투표함($box)이 모자($hat)를 덮습니다');
      expect(box.bottom, lessThanOrEqualTo(hat.top));
      // 삽화 안에는 들어가 있어야 합니다(화면 밖으로 나가면 안 됩니다).
      expect(box.top, greaterThan(0));
      expect(box.right, lessThan(1194));
    });
  });

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

      // 투표함 이동(0.8초) 동안에는 아직 표가 나오지 않습니다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MafiaBallotPaper), findsNothing);

      // 표가 한 장씩 나와 날아갑니다.
      var sawBallot = false;
      for (var i = 0; i < 15 && !sawBallot; i += 1) {
        await tester.pump(const Duration(milliseconds: 150));
        sawBallot = find.byType(MafiaBallotPaper).evaluate().isNotEmpty;
      }
      expect(sawBallot, isTrue, reason: '표가 한 장도 개표되지 않았습니다');

      // 확정(2026-08): 연출이 끝나면 세 장(2 + 1)이 **쌓인 채 남습니다.**
      // '2표' 같은 숫자 문구는 쓰지 않습니다.
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(MafiaBallotPaper), findsNWidgets(3));
      expect(find.textContaining('표'), findsNothing);
    });

    testWidgets('표는 프로필 위로 한 장씩 쌓인다', (tester) async {
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MafiaTabletTallyView(
            result: const MafiaVoteResult(
              tally: {'u0': 3},
              executedUid: 'u0',
              tie: false,
              abstainCount: 0,
            ),
            players: buildPlayers(4),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 세 장이 쌓이고, 위로 갈수록 y가 작아집니다(= 위에 놓입니다).
      final papers = tester
          .widgetList<MafiaBallotPaper>(find.byType(MafiaBallotPaper))
          .toList();
      expect(papers.length, 3);
      final tops =
          tester
              .widgetList(find.byType(MafiaBallotPaper))
              .map((w) => tester.getCenter(find.byWidget(w)).dy)
              .toList()
            ..sort();
      // 장마다 확실히 다른 높이에 놓입니다(겹쳐 쌓인 더미).
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));

      // 가장 아래 표도 프로필(닉네임) 위쪽에 있습니다.
      final nickname = tester.getCenter(find.text('플레이어0')).dy;
      expect(tops[2], lessThan(nickname));
    });

    testWidgets('프로필 아래에 닉네임을 적는다', (tester) async {
      // 확정(2026-08): 사진만으로는 멀리서 누구인지 알기 어렵습니다.
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

      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 표를 받은 두 사람만 칸에 오릅니다.
      expect(find.text('플레이어0'), findsOneWidget);
      expect(find.text('플레이어1'), findsOneWidget);
      // 표를 못 받은 사람은 칸에 오르지 않습니다.
      expect(find.text('플레이어2'), findsNothing);
    });
  });
}
