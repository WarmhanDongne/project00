import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/tablet/animations/card_deal_animation.dart';

void main() {
  testWidgets('첫 분배는 기다려도 자동 시작하지 않고 탭 이후 한 번 완료된다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(completed, 0);
    key.currentState!.play();
    key.currentState!.play();
    await tester.pumpAndSettle();
    expect(completed, 1);
    key.currentState!.play();
    await tester.pumpAndSettle();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('beforeDelay와 afterDelay를 지킨 뒤 서버 완료 콜백을 보낸다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++, delays: true));
    await tester.pumpAndSettle();
    key.currentState!.play();
    await tester.pump(const Duration(milliseconds: 900));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // 마지막 프레임의 부동소수점 경계를 넘겨 afterDelay 타이머를 시작합니다.
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 999));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('지연 중 화면을 떠나면 완료 콜백을 호출하지 않는다', (tester) async {
    final key = GlobalKey<CardDealAnimationState>();
    var completed = 0;
    await tester.pumpWidget(_scene(key, () => completed++, delays: true));
    await tester.pumpAndSettle();
    key.currentState!.play();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(completed, 0);
  });
}

Widget _scene(
  GlobalKey<CardDealAnimationState> key,
  VoidCallback onCompleted, {
  bool delays = false,
}) => MaterialApp(
  home: Scaffold(
    body: CardDealAnimation(
      key: key,
      playerCount: 2,
      cardsPerPlayer: 1,
      duration: const Duration(milliseconds: 200),
      beforeDelay: delays ? const Duration(seconds: 1) : Duration.zero,
      afterDelay: delays ? const Duration(seconds: 1) : Duration.zero,
      cardBuilder: (_, _, _) => const ColoredBox(color: Colors.red),
      onCompleted: onCompleted,
    ),
  ),
);
