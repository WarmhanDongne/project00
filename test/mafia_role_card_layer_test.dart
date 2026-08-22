import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/mafia_flip_card.dart';
import 'package:project00/games/mafia/widgets/phone/role_card_layer.dart';

//=======================내 신분 카드 (확정 2026-08)==============================
// 처음: 화면 위 → 가운데 뒷면(미세하게 떠 있음) → 누르면 열림 → 0.3초 뒤 문구
//       → 1분 뒤 아래로.
// 그 뒤: 아래 카드를 누르면 올라와 열림 → 10초 뒤(또는 한 번 더 누르면) 아래로.
void main() {
  const design = Size(402, 874);
  const centerTop = 208.0;
  const storedTop = 776.0;

  Future<void> pumpLayer(
    WidgetTester tester, {
    bool isFirstReveal = false,
    String phaseKey = 'roleReveal',
    Duration entranceDelay = Duration.zero,
    VoidCallback? onRevealed,
  }) async {
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaPhoneRoleCardLayer(
          role: MafiaRoles.find('mafia'),
          phaseKey: phaseKey,
          isFirstReveal: isFirstReveal,
          entranceDelay: entranceDelay,
          onRevealed: onRevealed,
        ),
      ),
    );
  }

  /// 연출 한 단계를 끝까지 돌립니다.
  ///
  /// 애니메이션은 시작 프레임에서 0부터 세기 시작하고, 끝난 뒤 상태가
  /// 전달되는 데 한 프레임이 더 듭니다. 그래서 세 번 나눠 돌립니다.
  Future<void> runStep(WidgetTester tester, Duration duration) async {
    await tester.pump();
    await tester.pump(duration);
    await tester.pump(const Duration(milliseconds: 16));
  }

  double cardTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(MafiaFlipCard)).dy;

  /// 아래에 놓인 카드는 위쪽 일부만 보이므로 그 부분을 누릅니다.
  Future<void> tapStored(WidgetTester tester) =>
      tester.tapAt(const Offset(201, 820));

  /// 가운데로 올라온 카드를 누릅니다.
  Future<void> tapCenter(WidgetTester tester) =>
      tester.tapAt(const Offset(201, 400));

  testWidgets('처음에는 화면 위에서 내려와 가운데에 뒷면으로 선다', (tester) async {
    await pumpLayer(tester, isFirstReveal: true);

    // 시작 순간에는 화면 위(음수)에 있습니다.
    await tester.pump();
    expect(cardTop(tester), lessThan(0));

    // 내려오면 가운데 자리입니다(미세하게 떠 있어 오차를 둡니다).
    await tester.pump(MafiaPhoneRoleCardLayer.travelDuration);
    expect(cardTop(tester), closeTo(centerTop, 8));

    // 아직 뒷면이라 문구가 없습니다.
    expect(find.textContaining('입니다'), findsNothing);
  });

  testWidgets('누르면 열리고 0.3초 뒤에 문구가 떠오른다', (tester) async {
    var revealed = 0;
    await pumpLayer(
      tester,
      isFirstReveal: true,
      onRevealed: () => revealed += 1,
    );
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);

    await tapCenter(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    // 열린 순간 확인이 서버로 한 번 갑니다.
    expect(revealed, 1);

    // 문구는 아직 보이지 않습니다(0.3초 기다립니다).
    final text = find.textContaining('입니다');
    expect(text, findsOneWidget);
    expect(
      tester
          .widgetList<Opacity>(
            find.ancestor(of: text, matching: find.byType(Opacity)),
          )
          .first
          .opacity,
      0,
    );

    // 0.3초 뒤부터 부드럽게 떠오릅니다.
    await tester.pump(MafiaPhoneRoleCardLayer.textDelay);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widgetList<Opacity>(
            find.ancestor(of: text, matching: find.byType(Opacity)),
          )
          .first
          .opacity,
      1,
    );
  });

  testWidgets('처음 확인 뒤 1분이 지나면 다시 뒤집혀 내려간다', (tester) async {
    await pumpLayer(tester, isFirstReveal: true, onRevealed: () {});
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    await tapCenter(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    expect(cardTop(tester), closeTo(centerTop, 8));

    // 1분 뒤: 되돌아 뒤집힌 다음 아래로 내려갑니다.
    await tester.pump(MafiaPhoneRoleCardLayer.firstRevealHold);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    expect(cardTop(tester), closeTo(storedTop, 1));
    expect(find.textContaining('입니다'), findsNothing);
  });

  testWidgets('평소에는 아래 카드를 눌러 열고 10초 뒤 저절로 내려간다', (tester) async {
    await pumpLayer(tester, phaseKey: 'day');
    await tester.pump();
    expect(cardTop(tester), closeTo(storedTop, 1));

    await tapStored(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    expect(cardTop(tester), closeTo(centerTop, 1));

    await tester.pump(MafiaPhoneRoleCardLayer.textDelay);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('입니다'), findsOneWidget);

    // 10초 뒤 자동 복귀입니다.
    await tester.pump(MafiaPhoneRoleCardLayer.peekHold);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    expect(cardTop(tester), closeTo(storedTop, 1));
  });

  testWidgets('열린 카드를 한 번 더 누르면 기다리지 않고 내려간다', (tester) async {
    await pumpLayer(tester, phaseKey: 'voting');
    await tester.pump();
    await tapStored(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);

    await tapCenter(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    expect(cardTop(tester), closeTo(storedTop, 1));
  });

  testWidgets('단계가 바뀌면 열린 카드가 다음 화면을 가리지 않게 내려간다', (tester) async {
    await pumpLayer(tester, phaseKey: 'day');
    await tester.pump();
    await tapStored(tester);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    expect(cardTop(tester), closeTo(centerTop, 1));

    // 낮 → 투표로 넘어갑니다.
    await pumpLayer(tester, phaseKey: 'voting');
    await runStep(tester, MafiaPhoneRoleCardLayer.flipDuration);
    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    expect(cardTop(tester), closeTo(storedTop, 1));
  });

  //=======================분배가 끝난 뒤에 들어옵니다==============================
  // 확정(2026-08): 태블릿에서 카드가 아직 날아가는 중인데 휴대폰에 이미 카드가
  // 있으면 카드를 건네받는 느낌이 사라집니다.
  testWidgets('분배가 끝날 때까지는 카드가 화면에 없다', (tester) async {
    await pumpLayer(
      tester,
      isFirstReveal: true,
      entranceDelay: const Duration(milliseconds: 900),
    );

    // 기다리는 동안에는 아래에 놓인 카드조차 없습니다.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MafiaFlipCard), findsNothing);

    // 분배가 끝나면 화면 위에서 들어옵니다.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MafiaFlipCard), findsOneWidget);
    final top = tester.getTopLeft(find.byType(MafiaFlipCard)).dy;
    expect(top, lessThan(centerTop), reason: '화면 위에서 내려와야 합니다');

    await runStep(tester, MafiaPhoneRoleCardLayer.travelDuration);
    expect(
      tester.getTopLeft(find.byType(MafiaFlipCard)).dy,
      moreOrLessEquals(centerTop, epsilon: 1),
    );
  });

  testWidgets('기다릴 시간이 없으면 곧바로 들어온다', (tester) async {
    // 재접속처럼 이미 분배가 끝난 경우입니다.
    await pumpLayer(tester, isFirstReveal: true);
    await tester.pump();
    expect(find.byType(MafiaFlipCard), findsOneWidget);
  });
}
