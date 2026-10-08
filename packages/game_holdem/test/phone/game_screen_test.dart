import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/phone/screens/game_screen.dart';
import 'package:game_holdem/phone/widgets/hand_receive_animation.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown_face.dart';

import '../support/fixtures.dart';

void main() {
  late GameAssetStore previousStore;

  setUp(() {
    previousStore = GameAssetStore.instance;
    GameAssetStore.instance = FakeHoldemAssetStore();
  });
  tearDown(() => GameAssetStore.instance = previousStore);

  Future<List<(String, int?)>> pump(
    WidgetTester tester,
    HoldemGameState game, {
    Size size = const Size(390, 844),
    Future<bool> Function(String action, {int? amount})? onAction,
  }) async {
    final actions = <(String, int?)>[];
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldemPhoneGameScreen(
            game: game,
            uid: 'me',
            onAction:
                onAction ??
                (action, {amount}) async {
                  actions.add((action, amount));
                  return true;
                },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 950));
    return actions;
  }

  testWidgets('내 차례에는 서버가 허용한 퍽 행동을 보낸다', (tester) async {
    final actions = await pump(
      tester,
      playingState(
        legalActions: callOrRaise,
        lastAction: const HoldemLastActionModel(
          uid: 'rival',
          kind: 'bet',
          amount: 400,
          createdAt: 1,
        ),
      ),
    );

    expect(find.text('내 차례예요'), findsOneWidget);
    expect(
      tester.getRect(find.text('내 차례예요')).bottom,
      lessThan(tester.getRect(find.bySemanticsLabel('내 칩 4,900')).top),
    );
    expect(find.text('하준 님이 400 벳 했어요'), findsOneWidget);
    expect(find.bySemanticsLabel('다이아몬드 K'), findsNothing);
    expect(find.bySemanticsLabel('카드 확인'), findsOneWidget);
    expect(find.textContaining('POT'), findsNothing);
    expect(find.bySemanticsLabel('스페이드 K'), findsNothing);
    expect(find.bySemanticsLabel('내 칩 4,900'), findsOneWidget);
    expect(find.textContaining('블라인드'), findsNothing);
    expect(find.textContaining('원 페어'), findsNothing);

    await tester.tap(find.bySemanticsLabel('콜 400'));
    expect(actions, [('call', null)]);
  });

  testWidgets('공개 베팅과 개인 권한이 엇갈린 동안 CALL을 보내지 않는다', (tester) async {
    const staleCheck = HoldemLegalActionsModel(
      fold: true,
      check: true,
      call: false,
      bet: true,
      raise: false,
      allIn: true,
      toCall: 0,
      callAmount: 0,
      minimumTarget: 400,
      maximumTarget: 4900,
    );
    final actions = await pump(tester, playingState(legalActions: staleCheck));

    expect(find.bySemanticsLabel('체크'), findsNothing);
    expect(find.bySemanticsLabel('콜 400'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('콜 400'));

    expect(actions, isEmpty);
  });

  testWidgets('공개 베팅과 개인 권한이 엇갈린 동안 CHECK를 보내지 않는다', (tester) async {
    final actions = await pump(
      tester,
      playingState(
        legalActions: callOrRaise,
        players: {
          'me': player('me', '민지', 0, stack: 4900, streetContribution: 400),
          'rival': player(
            'rival',
            '하준',
            1,
            stack: 5800,
            streetContribution: 400,
          ),
        },
      ),
    );

    expect(find.bySemanticsLabel('콜 400'), findsNothing);
    expect(find.bySemanticsLabel('체크'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('체크'));

    expect(actions, isEmpty);
  });

  testWidgets('체크 성공 뒤 새 revision 전까지 진행 상태를 유지해 중복 입력을 막는다', (tester) async {
    final completer = Completer<bool>();
    var callCount = 0;
    const checkOrBet = HoldemLegalActionsModel(
      fold: true,
      check: true,
      call: false,
      bet: true,
      raise: false,
      allIn: true,
      toCall: 0,
      callAmount: 0,
      minimumTarget: 400,
      maximumTarget: 5300,
    );
    await pump(
      tester,
      playingState(
        legalActions: checkOrBet,
        players: {
          'me': player('me', '민지', 0, stack: 4900, streetContribution: 400),
          'rival': player(
            'rival',
            '하준',
            1,
            stack: 5800,
            streetContribution: 400,
          ),
        },
      ),
      onAction: (action, {amount}) {
        callCount += 1;
        return completer.future;
      },
    );

    await tester.tap(find.bySemanticsLabel('체크'));
    await tester.pump();
    expect(find.bySemanticsLabel('체크 처리 중'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('체크 처리 중'));
    await tester.pump();
    expect(callCount, 1);

    completer.complete(true);
    await tester.pump();
    expect(find.bySemanticsLabel('체크 처리 중'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('체크 처리 중'));
    expect(callCount, 1);

    await pump(
      tester,
      playingState(turnUid: 'rival', legalActions: null).copyWith(revision: 10),
      onAction: (action, {amount}) {
        callCount += 1;
        return Future.value(true);
      },
    );
    expect(find.bySemanticsLabel('체크 처리 중'), findsNothing);
    expect(find.textContaining('고민 중'), findsOneWidget);
  });

  testWidgets('턴 타이머가 끝나면 남아 있는 CHECK 버튼으로 요청을 보내지 않는다', (tester) async {
    const checkOrBet = HoldemLegalActionsModel(
      fold: true,
      check: true,
      call: false,
      bet: true,
      raise: false,
      allIn: true,
      toCall: 0,
      callAmount: 0,
      minimumTarget: 400,
      maximumTarget: 5300,
    );
    final actions = await pump(
      tester,
      playingState(
        legalActions: checkOrBet,
        players: {
          'me': player('me', '민지', 0, stack: 4900, streetContribution: 400),
          'rival': player(
            'rival',
            '하준',
            1,
            stack: 5800,
            streetContribution: 400,
          ),
        },
      ),
    );

    tester
        .widget<GameTurnCountdownFace>(find.byType(GameTurnCountdownFace))
        .onTimeout!();
    await tester.pump();

    expect(find.text('시간 종료'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('체크'));
    expect(actions, isEmpty);
  });

  testWidgets('레이즈 시트는 빠른 금액과 올인을 목표액으로 보낸다', (tester) async {
    final actions = await pump(tester, playingState(legalActions: callOrRaise));

    await tester.tap(find.bySemanticsLabel('Raise 금액 고르기'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('얼마나 올릴까요?'), findsOneWidget);
    expect(find.text('최소 800'), findsOneWidget);

    await tester.tap(find.text('최소'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Raise 800'));
    await tester.pump();
    expect(actions.last, ('raise', 800));

    // 실제 게임에서는 성공한 레이즈 뒤 서버의 새 revision과 다음 차례가
    // 도착해야 다시 행동할 수 있습니다. 다음 차례 상태를 받은 뒤 올인을
    // 별도로 검증합니다.
    await pump(
      tester,
      playingState(legalActions: callOrRaise).copyWith(revision: 10),
      onAction: (action, {amount}) async {
        actions.add((action, amount));
        return true;
      },
    );
    await tester.tap(find.bySemanticsLabel('Raise 금액 고르기'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('올인'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('All-in 4,900'));
    await tester.pump();
    expect(actions.last, ('allIn', null));
  });

  testWidgets('새 손패는 겹친 채 함께 뒤집힌 다음 좌우로 펼쳐진다', (tester) async {
    final hand = playingState(turnUid: 'rival');
    await pump(tester, hand);

    expect(find.text('하준 님이 고민 중'), findsOneWidget);
    expect(find.bySemanticsLabel('뒷면 카드'), findsNWidgets(2));
    expect(find.bySemanticsLabel('다이아몬드 K'), findsNothing);
    expect(find.textContaining('진동'), findsNothing);

    await tester.tap(find.bySemanticsLabel('카드 확인'));
    await tester.pump();
    double cardGap() {
      final left = tester.widget<Positioned>(
        find.byKey(const ValueKey('holdem-receive-card-0')),
      );
      final right = tester.widget<Positioned>(
        find.byKey(const ValueKey('holdem-receive-card-1')),
      );
      return right.left! - left.left!;
    }

    await tester.pump(const Duration(milliseconds: 250));
    expect(cardGap(), lessThan(10));
    expect(find.bySemanticsLabel('뒷면 카드'), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 470));
    expect(cardGap(), lessThan(10));
    expect(find.bySemanticsLabel('다이아몬드 K'), findsOneWidget);
    expect(find.bySemanticsLabel('다이아몬드 Q'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 220));
    expect(cardGap(), greaterThan(30));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.bySemanticsLabel('다이아몬드 K'), findsOneWidget);
    expect(find.bySemanticsLabel('카드 확인'), findsNothing);

    await pump(tester, hand.copyWith(handNumber: 3));
    expect(find.bySemanticsLabel('다이아몬드 K'), findsNothing);
    expect(find.bySemanticsLabel('카드 확인'), findsOneWidget);
  });

  testWidgets('공개 카드 스트리트가 바뀌어도 수령 중인 손패 애니메이션은 다시 시작하지 않는다', (tester) async {
    final hand = playingState(phase: 'preflop', turnUid: 'rival');
    await pump(tester, hand);
    final receive = tester.state(find.byType(HoldemHandReceiveAnimation));
    await pump(tester, hand.copyWith(phase: 'flop'));
    expect(
      tester.state(find.byType(HoldemHandReceiveAnimation)),
      same(receive),
    );
  });

  testWidgets('턴 전환 때 손패와 행동 영역의 위치가 움직이지 않는다', (tester) async {
    final myTurn = playingState(legalActions: callOrRaise);
    await pump(tester, myTurn);
    final handBefore = tester.getRect(
      find.byKey(const Key('holdem-phone-hand-area')),
    );
    final actionsBefore = tester.getRect(
      find.byKey(const Key('holdem-phone-actions-area')),
    );

    await pump(tester, myTurn.copyWith(turnUid: 'rival', legalActions: null));
    final handAfter = tester.getRect(
      find.byKey(const Key('holdem-phone-hand-area')),
    );
    final actionsAfter = tester.getRect(
      find.byKey(const Key('holdem-phone-actions-area')),
    );
    expect(handAfter, handBefore);
    expect(actionsAfter, actionsBefore);
    expect(
      tester.getRect(find.text('하준 님이 고민 중')).bottom,
      lessThan(tester.getRect(find.bySemanticsLabel('내 칩 4,900')).top),
    );
    expect(find.textContaining('진동'), findsNothing);
  });

  testWidgets('판 결과는 승리 금액과 최종 5장의 출처를 보여 준다', (tester) async {
    final best = [
      card('k', 'diamonds'),
      card('k', 'spades'),
      card('q', 'diamonds'),
      card('9', 'hearts'),
      card('4', 'clubs'),
    ];
    await pump(
      tester,
      playingState(
        phase: 'handResult',
        turnUid: null,
        result: HoldemHandResultModel(
          reason: 'showdown',
          winnerUids: const ['me'],
          awards: const {'me': 1800},
          revealedHands: {
            'me': [card('k', 'diamonds'), card('q', 'diamonds')],
          },
          handCategories: const {'me': 'onePair'},
          bestCards: {'me': best},
        ),
      ),
    );

    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('+1,800'), findsOneWidget);
    expect(find.textContaining('원 페어'), findsNothing);
    expect(find.text('팟을 가져왔어요'), findsOneWidget);
    expect(find.text('내 카드'), findsNWidgets(2));
    expect(find.text('테이블'), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('작은 휴대폰에서도 내 차례·레이즈·결과 화면이 넘치지 않는다', (tester) async {
    const small = Size(360, 640);
    await pump(tester, playingState(legalActions: callOrRaise), size: small);
    await tester.tap(find.bySemanticsLabel('Raise 금액 고르기'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await pump(tester, playingState(turnUid: 'rival'), size: small);
    expect(tester.takeException(), isNull);

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
            'rival': [card('9', 'clubs'), card('9', 'spades')],
          },
          handCategories: const {'rival': 'threeOfAKind'},
          bestCards: {
            'rival': [
              card('9', 'clubs'),
              card('9', 'spades'),
              card('9', 'hearts'),
              card('k', 'spades'),
              card('4', 'clubs'),
            ],
          },
        ),
      ),
      size: small,
    );
    expect(find.text('LOSE'), findsOneWidget);
    expect(find.text('하준 카드'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
