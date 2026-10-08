import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/models/presentation_timing.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/tablet/animations/action_motion.dart';
import 'package:game_holdem/tablet/animations/card_deal_animation.dart';
import 'package:game_holdem/tablet/screens/table_screen.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';

import '../support/fixtures.dart';

const _layout = PlayerLayoutModel(
  players: [
    PlayerLayoutPlayer(
      uid: 'me',
      nickname: '민지',
      characterId: 'frog',
      seatIndex: 0,
    ),
    PlayerLayoutPlayer(
      uid: 'rival',
      nickname: '하준',
      characterId: 'frog',
      seatIndex: 1,
    ),
  ],
);

void main() {
  late GameAssetStore previousStore;

  setUp(() {
    previousStore = GameAssetStore.instance;
    GameAssetStore.instance = FakeHoldemAssetStore();
  });
  tearDown(() => GameAssetStore.instance = previousStore);

  Future<void> pump(WidgetTester tester, HoldemGameState game) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HoldemTableScreen(game: game, playerLayout: _layout),
      ),
    );
  }

  testWidgets('진행 중 테이블은 팟·좌석·행동 라벨을 공개 정보로만 그린다', (tester) async {
    await pump(
      tester,
      playingState(
        turnUid: 'me',
        lastAction: const HoldemLastActionModel(
          uid: 'rival',
          kind: 'bet',
          amount: 400,
          createdAt: 1,
        ),
      ),
    );

    expect(find.text('POT 1,800'), findsNWidgets(2));
    expect(find.text('민지'), findsOneWidget);
    expect(find.text('하준'), findsOneWidget);
    expect(find.text('벳'), findsOneWidget);
    expect(find.text('SB'), findsOneWidget);
    expect(find.byType(MosiFace), findsNWidgets(2));
    for (final uid in ['me', 'rival']) {
      final profile = tester.widget<Positioned>(
        find.byKey(Key('holdem-profile-$uid')),
      );
      expect(profile.left, -42);
      final face = tester.widget<MosiFace>(
        find.descendant(
          of: find.byKey(Key('holdem-profile-$uid')),
          matching: find.byType(MosiFace),
        ),
      );
      expect(face.size, 82);
    }
    expect(find.textContaining('블라인드'), findsNothing);
    expect(find.textContaining('고민 중'), findsOneWidget);
    expect(find.bySemanticsLabel('스페이드 K'), findsOneWidget);
    // 태블릿은 개인 손패를 받지 않으므로 좌석 카드는 모두 뒷면입니다.
    expect(find.bySemanticsLabel('다이아몬드 Q'), findsNothing);
    expect(find.bySemanticsLabel('뒷면 카드'), findsNWidgets(4));
  });

  testWidgets('새 핸드는 중앙 덱에서 각 좌석에 두 장씩 분배한다', (tester) async {
    final hand = playingState(phase: 'dealing', lastAction: null);
    await pump(tester, hand);
    final deal = tester.widget<HoldemCardDealAnimation>(
      find.byType(HoldemCardDealAnimation),
    );
    expect(deal.seatCount, 2);
    expect(deal.seatIndexes, [0, 1]);
    expect(find.bySemanticsLabel('홀덤 카드 분배'), findsOneWidget);
    expect(find.byType(HoldemCardView), findsNWidgets(4));
    await tester.pump(const Duration(milliseconds: 2700));
    final firstSeatCard = tester.widget<Positioned>(
      find.byKey(const ValueKey('holdem-dealt-0')),
    );
    expect(firstSeatCard.left! + 41, closeTo(1366 * .16, 18));
    await pump(tester, hand.copyWith(handNumber: 3));
    expect(find.byKey(const ValueKey('holdem-deal-3')), findsOneWidget);
    final nextHandCard = tester.widget<Positioned>(
      find.byKey(const ValueKey('holdem-dealt-0')),
    );
    expect(nextHandCard.top, lessThan(0));
  });

  testWidgets('쇼다운은 승자와 공개 손패를 강조하고 족보 안내를 숨긴다', (tester) async {
    await pump(
      tester,
      playingState(
        phase: 'handResult',
        turnUid: null,
        result: HoldemHandResultModel(
          reason: 'showdown',
          winnerUids: const ['rival'],
          awards: const {'rival': 1800},
          revealedHands: {
            'rival': [card('k', 'hearts'), card('k', 'clubs')],
            'me': [card('q', 'diamonds'), card('2', 'diamonds')],
          },
          handCategories: const {'rival': 'threeOfAKind', 'me': 'highCard'},
          bestCards: {
            'rival': [
              card('k', 'hearts'),
              card('k', 'clubs'),
              card('k', 'spades'),
              card('9', 'hearts'),
              card('4', 'clubs'),
            ],
          },
        ),
      ),
    );

    expect(find.text('하준 승리'), findsNWidgets(2));
    expect(find.text('+1,800'), findsNWidgets(2));
    expect(find.textContaining('트리플'), findsNothing);
    expect(find.byKey(const Key('holdem-showdown-countdown')), findsOneWidget);
    expect(HoldemTiming.handResult('showdown'), const Duration(seconds: 12));
    expect(find.text('WIN'), findsOneWidget);
    expect(find.bySemanticsLabel('하트 K'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    for (final uid in ['me', 'rival']) {
      final hand = tester.widget<Positioned>(
        find.byKey(Key('holdem-showdown-hand-$uid')),
      );
      expect(hand.top, -105);
      for (var index = 0; index < 2; index++) {
        final card = tester.widget<HoldemCardView>(
          find.byKey(Key('holdem-showdown-card-$uid-$index')),
        );
        expect(card.width, 126);
      }
    }
    final publicKing = tester
        .widgetList<HoldemCardView>(find.byType(HoldemCardView))
        .firstWhere((view) => view.card?.id == 'k_spades');
    expect(publicKing.width, closeTo(142, .01));
  });

  testWidgets('승리 칩 이동 중에는 중앙 카드와 결과 문구를 비운다', (tester) async {
    final initial = playingState(lastAction: null);
    await pump(tester, initial);
    await pump(
      tester,
      initial.copyWith(
        phase: 'handResult',
        result: const HoldemHandResultModel(
          reason: 'showdown',
          winnerUids: ['rival'],
          awards: {'rival': 1800},
          revealedHands: {},
          handCategories: {},
          bestCards: {},
        ),
      ),
    );

    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('holdem-center-opacity')))
          .opacity,
      1,
    );
    await tester.pump(const Duration(seconds: 7));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('holdem-center-opacity')))
          .opacity,
      1,
    );
    expect(find.byKey(const Key('holdem-showdown-countdown')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('holdem-center-opacity')))
          .opacity,
      0,
    );
    final potPosition = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.byType(HoldemPotChipStack),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(potPosition.top, closeTo(512 - 26, 1));
    expect(find.byType(HoldemPotAwardMotion), findsOneWidget);
  });

  testWidgets('베팅 칩 더미는 투척 방향으로 넘어져 중앙 팟에 낮게 누적된다', (tester) async {
    final initial = playingState(lastAction: null);
    await pump(tester, initial);

    await pump(
      tester,
      initial.copyWith(
        revision: 10,
        potTotal: 2200,
        lastAction: const HoldemLastActionModel(
          uid: 'rival',
          kind: 'raise',
          amount: 400,
          createdAt: 2,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.bySemanticsLabel('베팅 칩 이동'), findsOneWidget);
    expect(find.bySemanticsLabel('팟 칩 2,200'), findsOneWidget);
    final motion = tester.widget<HoldemTableActionMotion>(
      find.byType(HoldemTableActionMotion),
    );
    expect(motion.tableCenter.dx, closeTo(683, .01));
    expect(motion.tableCenter.dy, closeTo(512, .01));
    expect(motion.potTarget.dx, closeTo(motion.tableCenter.dx, .01));
    expect(motion.potTarget.dy, greaterThan(motion.tableCenter.dy));

    await tester.pump(const Duration(milliseconds: 1450));
    expect(find.bySemanticsLabel('베팅 칩 이동'), findsNothing);
    expect(find.bySemanticsLabel('팟 칩 2,200'), findsOneWidget);
  });

  testWidgets('새 핸드의 스몰·빅 블라인드도 차례로 중앙에 투입된다', (tester) async {
    await pump(
      tester,
      playingState(phase: 'preflop', lastAction: null).copyWith(
        communityCards: const [],
        potTotal: 30,
        players: {
          'me': player('me', '민지', 0, stack: 990, streetContribution: 10),
          'rival': player('rival', '하준', 1, stack: 980, streetContribution: 20),
        },
      ),
    );
    expect(find.bySemanticsLabel('블라인드 칩 이동'), findsOneWidget);
    expect(
      tester
          .widget<HoldemTableActionMotion>(find.byType(HoldemTableActionMotion))
          .amount,
      10,
    );
    await tester.pump(const Duration(milliseconds: 1150));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<HoldemTableActionMotion>(find.byType(HoldemTableActionMotion))
          .amount,
      20,
    );
  });

  testWidgets('스트리트 변경 시 공개 카드 영역이 은은하게 나타난다', (tester) async {
    final initial = playingState(
      phase: 'preflop',
    ).copyWith(communityCards: const []);
    await pump(tester, initial);
    await tester.pump(const Duration(milliseconds: 600));
    await pump(
      tester,
      initial.copyWith(
        phase: 'flop',
        communityCards: [
          card('k', 'spades'),
          card('9', 'hearts'),
          card('4', 'clubs'),
        ],
      ),
    );
    final board = find.byKey(const ValueKey('board-2-flop'));
    final opacity = tester.widget<Opacity>(
      find.descendant(of: board, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(.5));
    await tester.pump(const Duration(milliseconds: 600));
    final settled = tester.widget<Opacity>(
      find.descendant(of: board, matching: find.byType(Opacity)).first,
    );
    expect(settled.opacity, closeTo(1, .01));
  });

  testWidgets('폴드 카드는 중앙으로 이동해 사라지고 체크도 같은 흐름으로 표시된다', (tester) async {
    final initial = playingState(lastAction: null);
    await pump(tester, initial);

    await pump(
      tester,
      initial.copyWith(
        revision: 10,
        lastAction: const HoldemLastActionModel(
          uid: 'rival',
          kind: 'fold',
          amount: 0,
          createdAt: 3,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('폴드 카드 이동'), findsOneWidget);

    await pump(
      tester,
      initial.copyWith(
        revision: 11,
        lastAction: const HoldemLastActionModel(
          uid: 'me',
          kind: 'check',
          amount: 0,
          createdAt: 4,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.bySemanticsLabel('폴드 카드 이동'), findsNothing);
    expect(find.byType(HoldemTableActionMotion), findsOneWidget);
    expect(
      tester
          .widget<HoldemTableActionMotion>(find.byType(HoldemTableActionMotion))
          .kind,
      'check',
    );
    expect(find.bySemanticsLabel('체크 이동'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.bySemanticsLabel('체크 이동'), findsNothing);
  });

  testWidgets('폴드 승리 시 팟 칩이 승자에게 이동하며 보유 칩 숫자가 증가한다', (tester) async {
    final initial = playingState(
      lastAction: const HoldemLastActionModel(
        uid: 'me',
        kind: 'call',
        amount: 400,
        createdAt: 5,
      ),
    );
    await pump(tester, initial);

    final result = HoldemHandResultModel(
      reason: 'fold',
      winnerUids: const ['rival'],
      awards: const {'rival': 1800},
      revealedHands: const {},
      handCategories: const {},
      bestCards: const {},
    );
    await pump(
      tester,
      initial.copyWith(
        phase: 'handResult',
        revision: 10,
        turnUid: null,
        players: {
          'me': player('me', '민지', 0, stack: 4900, handStatus: 'folded'),
          'rival': player('rival', '하준', 1, stack: 7600),
        },
        lastAction: const HoldemLastActionModel(
          uid: 'me',
          kind: 'fold',
          amount: 0,
          createdAt: 6,
        ),
        result: result,
      ),
    );

    expect(find.text('5,800'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('승리 칩 이동 1,800'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.bySemanticsLabel('승리 칩 이동 1,800'), findsNothing);
    expect(find.text('7,600'), findsOneWidget);
  });
}
