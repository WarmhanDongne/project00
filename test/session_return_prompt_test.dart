import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';
import 'package:project00/platform/home/phone/widgets/session_return_prompt.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

//=======================비정상 종료 후 복귀 선택 (P-01)==============================
// 지금까지는 복원에 성공하면 **묻지 않고** 대기 화면과 게임 화면을 곧바로
// 열었습니다. 게임을 그만두려고 앱을 껐어도 다시 켜면 그 방으로 끌려
// 들어갑니다. 진행 중인 방은 15분 동안 유지되므로(C-03) 그 사이 매번입니다.

void main() {
  Future<void> pumpPrompt(
    WidgetTester tester, {
    required RestorableSession session,
    bool isBusy = false,
    VoidCallback? onReturn,
    VoidCallback? onDecline,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: SessionReturnPrompt(
          session: session,
          isBusy: isBusy,
          onReturn: onReturn ?? () {},
          onDecline: onDecline ?? () {},
        ),
      ),
    );
  }

  testWidgets('진행 중인 게임은 게임 다시 참여를 보여 준다', (tester) async {
    await pumpPrompt(tester, session: RestorableSession.activeGame);

    expect(find.text('진행 중인 게임이 있어요'), findsOneWidget);
    expect(find.text('게임 다시 참여'), findsOneWidget);
    expect(find.text('그룹 다시 참여'), findsNothing);
    expect(find.text('나중에'), findsOneWidget);
  });

  testWidgets('대기실은 그룹 다시 참여를 보여 준다', (tester) async {
    await pumpPrompt(tester, session: RestorableSession.waitingRoom);

    expect(find.text('참여 중인 그룹이 있어요'), findsOneWidget);
    expect(find.text('그룹 다시 참여'), findsOneWidget);
    expect(find.text('게임 다시 참여'), findsNothing);
  });

  testWidgets('복귀와 거절이 각각 한 번씩 전달된다', (tester) async {
    var returned = 0;
    var declined = 0;
    await pumpPrompt(
      tester,
      session: RestorableSession.waitingRoom,
      onReturn: () => returned += 1,
      onDecline: () => declined += 1,
    );

    await tester.tap(find.text('그룹 다시 참여'));
    await tester.pump();
    expect(returned, 1);
    expect(declined, 0);

    await tester.tap(find.text('나중에'));
    await tester.pump();
    expect(declined, 1);
  });

  testWidgets('요청이 날아가 있는 동안 두 버튼이 모두 잠긴다', (tester) async {
    var taps = 0;
    await pumpPrompt(
      tester,
      session: RestorableSession.activeGame,
      isBusy: true,
      onReturn: () => taps += 1,
      onDecline: () => taps += 1,
    );

    await tester.tap(find.text('게임 다시 참여'), warnIfMissed: false);
    await tester.tap(find.text('나중에'), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('고르는 화면에서는 기다림 표시를 쓰지 않는다', (tester) async {
    // 재접속 대기 화면은 20초 뒤 `홈으로` 버튼을 띄우는 타이머를 겁니다.
    // 고르는 화면은 기다리는 화면이 아니므로 그 타이머가 돌면 안 됩니다.
    await pumpPrompt(tester, session: RestorableSession.waitingRoom);

    await tester.pump(const Duration(seconds: 25));

    expect(find.text('홈으로'), findsNothing);
    expect(find.text('그룹 다시 참여'), findsOneWidget);
  });

  testWidgets('태블릿 재접속 화면의 기존 동작은 그대로다', (tester) async {
    // actions를 넘기지 않으면 기다림 표시와 20초 뒤 나가기 버튼이 그대로여야
    // 합니다(ControllerReconnectGuard가 쓰는 경로).
    await tester.pumpWidget(
      const MaterialApp(
        home: GameReconnectScreen(title: '태블릿에 다시 연결하는 중', homeLabel: '게임 나가기'),
      ),
    );

    expect(find.text('게임 나가기'), findsNothing);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('게임 나가기'), findsOneWidget);
  });

  testWidgets('좁은 화면에서도 버튼이 넘치지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await pumpPrompt(tester, session: RestorableSession.activeGame);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
