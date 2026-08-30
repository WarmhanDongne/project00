import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';
import 'package:project00/games/shared/widgets/game_interruption_layer.dart';

//=======================인원 부족 즉시 종료 (C-11)==============================
// 계속할 수 없는 중단에서 60초를 기다리지 않고 끝낼 수 있는지, 그리고 계속할 수
// 있는 중단의 기존 투표·제외 흐름이 그대로인지 확인합니다.
//
// ⚠️ 이 위젯은 Timer.periodic(1초)를 계속 돌리므로 pumpAndSettle을 쓰면
// 타임아웃으로 실패합니다. tester.pump(Duration(seconds: 1))을 명시적으로
// 반복하세요.

void main() {
  setUp(() {
    // 서버 시각 보정을 0으로 고정해 deadlineAt 계산이 기기 시각과 같아지게 합니다.
    ServerClock.debugSetOffset(0);
  });

  GameInterruption interruption({
    required bool canContinue,
    int remainingMs = 60000,
    String id = 'gone-1000',
    List<String> eligibleVoterUids = const ['phone-a', 'phone-b'],
    Set<String> voterUids = const {},
  }) {
    return GameInterruption(
      id: id,
      playerUid: 'gone',
      playerNickname: '나간사람',
      playerCharacterId: 'frog',
      reason: GameInterruptionReason.left,
      startedAt: 0,
      deadlineAt: DateTime.now().millisecondsSinceEpoch + remainingMs,
      eligibleVoterUids: eligibleVoterUids,
      requiredVotes: canContinue ? 2 : 0,
      voterUids: voterUids,
      remainingPlayerCount: canContinue ? 3 : 1,
      minimumPlayerCount: 2,
      canContinue: canContinue,
    );
  }

  /// 레이어는 Positioned.fill을 돌려주므로 반드시 Stack 안에 넣어야 합니다.
  Future<void> pumpLayer(
    WidgetTester tester, {
    required GameInterruption? value,
    GameInterruptionPresentation presentation =
        GameInterruptionPresentation.player,
    String currentUid = 'phone-a',
    Future<bool> Function()? onFinishNow,
    Future<bool> Function()? onExpired,
    Future<void> Function()? onVote,
    Future<bool> Function()? onContinue,
    String? failureMessage,
    bool isSubmitting = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: ColoredBox(
                key: ValueKey('background'),
                color: Colors.blue,
              ),
            ),
            GameInterruptionLayer(
              interruption: value,
              currentUid: currentUid,
              presentation: presentation,
              onVote: onVote,
              onContinue: onContinue,
              onFinishNow: onFinishNow,
              onExpired: onExpired,
              failureMessage: failureMessage,
              isSubmitting: isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  /// 남아 있는 주기 타이머를 정리합니다.
  Future<void> unmount(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  /// 서버 시각을 [millis]만큼 앞으로 밀어 마감이 지난 상태를 만듭니다.
  ///
  /// 위젯은 `ServerClock`(= 실제 `DateTime.now()` + 보정값)으로 남은 시간을
  /// 계산합니다. `tester.pump`가 움직이는 것은 타이머·애니메이션용 가짜 시계라
  /// 그것만으로는 카운트다운이 줄지 않습니다. 보정값을 밀고 주기 타이머를 한 번
  /// 돌려야 화면이 다시 계산합니다.
  Future<void> advanceServerClock(WidgetTester tester, int millis) async {
    ServerClock.debugSetOffset(millis);
    await tester.pump(const Duration(seconds: 1));
  }

  bool isEnabled(WidgetTester tester, String label) {
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, label),
    );
    return button.onPressed != null;
  }

  //=======================계속할 수 없는 중단==============================

  testWidgets('휴대폰은 계속할 수 없는 중단에서 즉시 종료 버튼만 본다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => true,
    );

    expect(find.text('게임 종료하기'), findsOneWidget);
    expect(find.text('제외하고 계속하기'), findsNothing);
    expect(find.textContaining('동의'), findsNothing);
    expect(find.text('남은 인원이 부족해 게임을 계속할 수 없습니다.'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('태블릿은 비활성 제외하고 계속하기 대신 즉시 종료 버튼을 본다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      presentation: GameInterruptionPresentation.tabletController,
      currentUid: 'tablet',
      onContinue: () async => true,
      onFinishNow: () async => true,
    );

    expect(find.text('게임 종료하기'), findsOneWidget);
    expect(find.text('제외하고 계속하기'), findsNothing);
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await unmount(tester);
  });

  testWidgets('버튼을 누르면 바로 끝내지 않고 남은 복귀 시간을 확인한다', (tester) async {
    var calls = 0;
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async {
        calls += 1;
        return true;
      },
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();

    expect(calls, 0, reason: '확인 전에는 서버로 보내지 않습니다');
    expect(find.textContaining('돌아올 수 있는'), findsOneWidget);
    expect(find.textContaining('60초가 사라집니다'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('취소하면 원래 버튼으로 돌아가고 아무것도 보내지 않는다', (tester) async {
    var calls = 0;
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async {
        calls += 1;
        return true;
      },
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('취소'));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('게임 종료하기'), findsOneWidget);
    expect(find.textContaining('돌아올 수 있는'), findsNothing);

    await unmount(tester);
  });

  testWidgets('종료를 확인하면 한 번만 보내고 연속 탭을 막는다', (tester) async {
    var calls = 0;
    final gate = Completer<bool>();
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () {
        calls += 1;
        return gate.future;
      },
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();
    // 응답이 오기 전에 한 번 더 누릅니다.
    await tester.tap(find.text('종료'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    expect(isEnabled(tester, '종료'), isFalse);

    gate.complete(true);
    await tester.pump();
    await unmount(tester);
  });

  //=======================자동 만료와의 경합==============================

  testWidgets('종료 요청이 날아간 동안에는 자동 만료를 겹쳐 보내지 않는다', (tester) async {
    var expired = 0;
    final gate = Completer<bool>();
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () => gate.future,
      onExpired: () async {
        expired += 1;
        return true;
      },
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();

    // 응답을 기다리는 사이에 마감이 지나갑니다.
    for (var i = 0; i < 3; i++) {
      await advanceServerClock(tester, 61000 + i);
    }

    expect(find.text('0초'), findsOneWidget);
    expect(expired, 0, reason: '같은 결과를 만드는 명령을 두 번 보낼 이유가 없습니다');

    gate.complete(true);
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('종료가 실패하면 버튼을 되살리고 자동 만료가 이어받는다', (tester) async {
    var expired = 0;
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => false,
      onExpired: () async {
        expired += 1;
        return true;
      },
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();

    // 실패했으므로 확인 상태가 풀리고 다시 누를 수 있어야 합니다.
    expect(find.text('게임 종료하기'), findsOneWidget);
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await advanceServerClock(tester, 61000);
    expect(expired, greaterThanOrEqualTo(1), reason: '0초 화면에 갇히면 안 됩니다');

    await unmount(tester);
  });

  testWidgets('0초가 지난 뒤에도 즉시 종료 버튼은 활성으로 남는다', (tester) async {
    // 자동 만료가 계속 실패하는 상황에서 이 버튼이 유일한 탈출구입니다.
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => true,
      onExpired: () async => false,
    );

    await advanceServerClock(tester, 61000);

    expect(find.text('0초'), findsOneWidget);
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await unmount(tester);
  });

  //=======================비활성 조건==============================

  testWidgets('다른 명령이 진행 중이면 즉시 종료를 누를 수 없다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => true,
      isSubmitting: true,
    );

    expect(isEnabled(tester, '게임 종료하기'), isFalse);
    await unmount(tester);
  });

  testWidgets('콜백이 배선되지 않으면 버튼은 비활성이고 탭해도 안전하다', (tester) async {
    await pumpLayer(tester, value: interruption(canContinue: false));

    expect(isEnabled(tester, '게임 종료하기'), isFalse);
    await tester.tap(find.text('게임 종료하기'), warnIfMissed: false);
    await tester.pump();
    expect(find.textContaining('돌아올 수 있는'), findsNothing);

    await unmount(tester);
  });

  //=======================회귀: 계속할 수 있는 중단==============================

  testWidgets('태블릿 진행자의 제외하고 계속하기는 그대로다', (tester) async {
    var continued = 0;
    await pumpLayer(
      tester,
      value: interruption(canContinue: true),
      presentation: GameInterruptionPresentation.tabletController,
      currentUid: 'tablet',
      onContinue: () async {
        continued += 1;
        return true;
      },
      onFinishNow: () async => true,
    );

    expect(find.text('게임 종료하기'), findsNothing);
    expect(isEnabled(tester, '제외하고 계속하기'), isTrue);

    await tester.tap(find.text('제외하고 계속하기'));
    await tester.pump();
    expect(continued, 1);

    await unmount(tester);
  });

  testWidgets('휴대폰 투표 흐름은 그대로다', (tester) async {
    var votes = 0;
    await pumpLayer(
      tester,
      value: interruption(canContinue: true),
      onVote: () async => votes += 1,
      onFinishNow: () async => true,
    );

    expect(find.text('게임 종료하기'), findsNothing);
    expect(find.text('동의 0 / 2'), findsOneWidget);

    await tester.tap(find.text('제외하고 계속하기'));
    await tester.pump();
    expect(votes, 1);

    await unmount(tester);
  });

  testWidgets('투표권이 없는 참가자 화면은 대기 문구를 유지한다', (tester) async {
    // ⚠️ 마피아 태블릿은 더 이상 이 경로를 쓰지 않습니다. 이제 세 게임 모두
    // presentation: tabletController를 넘겨 진행자 분기로 갑니다(C-11).
    // 이 시험이 지키는 것은 '투표권이 없는 참가자'의 화면입니다.
    await pumpLayer(
      tester,
      value: interruption(canContinue: true),
      currentUid: 'tablet',
      onVote: () async {},
      onFinishNow: () async => true,
    );

    expect(find.text('다른 플레이어의 투표를 기다리고 있습니다.'), findsOneWidget);
    expect(find.text('게임 종료하기'), findsNothing);

    await unmount(tester);
  });

  testWidgets('중단이 없으면 Stack이 0×0으로 붕괴하지 않는다', (tester) async {
    await pumpLayer(tester, value: null, onFinishNow: () async => true);

    // 형제 배경이 화면을 그대로 채워야 합니다. Positioned.fill이 아닌
    // SizedBox.shrink를 돌려주면 느슨한 Stack이 통째로 0×0이 됩니다.
    final size = tester.getSize(find.byKey(const ValueKey('background')));
    expect(size.width, greaterThan(0));
    expect(size.height, greaterThan(0));

    await unmount(tester);
  });

  //=======================실패 안내 (C-11)==============================
  // 이 레이어는 Positioned.fill + scrim으로 화면 전체를 덮습니다. 그래서 그 아래에
  // 그린 오류 표시는 사용자에게 보이지 않고, 실패한 종료 요청이 아무 흔적도
  // 남기지 않은 채 사라졌습니다.

  testWidgets('즉시 종료가 실패하면 레이어 안에 문구가 남는다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => false,
      failureMessage: '만료된 태블릿 세션입니다. 방을 다시 연결해주세요.',
    );

    expect(find.text('만료된 태블릿 세션입니다. 방을 다시 연결해주세요.'), findsNothing);

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();

    expect(find.text('만료된 태블릿 세션입니다. 방을 다시 연결해주세요.'), findsOneWidget);
    // 다시 시도할 수 있어야 합니다.
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await unmount(tester);
  });

  testWidgets('제외하고 계속하기가 실패해도 같은 자리에 문구가 남는다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: true),
      presentation: GameInterruptionPresentation.tabletController,
      currentUid: 'tablet',
      onContinue: () async => false,
      failureMessage: '남은 인원이 최소 인원보다 적습니다.',
    );

    await tester.tap(find.text('제외하고 계속하기'));
    await tester.pump();

    expect(find.text('남은 인원이 최소 인원보다 적습니다.'), findsOneWidget);
    expect(isEnabled(tester, '제외하고 계속하기'), isTrue);

    await unmount(tester);
  });

  testWidgets('failureMessage가 없으면 실패해도 아무것도 표시하지 않는다', (tester) async {
    // 라이어스 포커 태블릿은 SnackBar로 이미 알리므로 중복 표시를 막습니다.
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () async => false,
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();

    expect(find.byType(Semantics), findsWidgets);
    expect(find.textContaining('실패'), findsNothing);
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await unmount(tester);
  });

  testWidgets('다시 시도를 시작하면 이전 실패 문구를 지운다', (tester) async {
    var attempt = 0;
    final gate = Completer<bool>();
    await pumpLayer(
      tester,
      value: interruption(canContinue: false),
      onFinishNow: () {
        attempt += 1;
        return attempt == 1 ? Future.value(false) : gate.future;
      },
      failureMessage: '게임을 종료하지 못했습니다.',
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();
    expect(find.text('게임을 종료하지 못했습니다.'), findsOneWidget);

    // 두 번째 시도를 시작하는 순간 지워져야 합니다. 남겨 두면 성공하는 중에도
    // 실패 문구가 함께 떠 있습니다.
    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();
    expect(find.text('게임을 종료하지 못했습니다.'), findsNothing);

    gate.complete(true);
    await tester.pump();
    await unmount(tester);
  });

  testWidgets('새 중단은 이전 중단의 실패 문구를 물려받지 않는다', (tester) async {
    await pumpLayer(
      tester,
      value: interruption(canContinue: false, id: 'gone-1000'),
      onFinishNow: () async => false,
      failureMessage: '게임을 종료하지 못했습니다.',
    );

    await tester.tap(find.text('게임 종료하기'));
    await tester.pump();
    await tester.tap(find.text('종료'));
    await tester.pump();
    expect(find.text('게임을 종료하지 못했습니다.'), findsOneWidget);

    await pumpLayer(
      tester,
      value: interruption(canContinue: false, id: 'gone-2000'),
      onFinishNow: () async => false,
      failureMessage: '게임을 종료하지 못했습니다.',
    );

    expect(find.text('게임을 종료하지 못했습니다.'), findsNothing);
    expect(isEnabled(tester, '게임 종료하기'), isTrue);

    await unmount(tester);
  });

  testWidgets('제외하고 계속하기 연타는 한 번만 보낸다', (tester) async {
    var calls = 0;
    final gate = Completer<bool>();
    await pumpLayer(
      tester,
      value: interruption(canContinue: true),
      presentation: GameInterruptionPresentation.tabletController,
      currentUid: 'tablet',
      onContinue: () {
        calls += 1;
        return gate.future;
      },
    );

    await tester.tap(find.text('제외하고 계속하기'));
    await tester.pump();
    await tester.tap(find.text('제외하고 계속하기'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    expect(isEnabled(tester, '제외하고 계속하기'), isFalse);

    gate.complete(true);
    await tester.pump();
    await unmount(tester);
  });
}
