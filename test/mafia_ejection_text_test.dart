import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/ejection_text.dart';

import 'support/ejection_beats.dart';

//=======================내려찍는 안내 문구==============================
// 확정(2026-08): 마피아의 안내 문구는 어몽어스 추방 발표처럼 크고 넓게
// 벌어진 채 들어와 제자리로 **내려찍힙니다.** 너무 긴 문장은 두 박자로
// 나눠 띄웁니다.
void main() {
  const style = TextStyle(fontSize: 40, fontWeight: FontWeight.w700);

  Future<void> pumpText(
    WidgetTester tester,
    List<String> beats, {
    Duration beatHold = MafiaEjectionText.defaultBeatHold,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: MafiaEjectionText(
            beats: beats,
            style: style,
            beatHold: beatHold,
          ),
        ),
      ),
    );
  }

  double? trackingOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.letterSpacing;

  testWidgets('한 박자는 찍힌 뒤 그 자리에 남는다', (tester) async {
    await pumpText(tester, const ['밤이 되었습니다']);

    expect(find.text('밤이 되었습니다'), findsOneWidget);

    // 부모가 걷어 갈 때까지 스스로 물러나지 않습니다.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('밤이 되었습니다'), findsOneWidget);
  });

  testWidgets('벌어진 글자가 제자리 자간으로 좁혀 들어온다', (tester) async {
    await pumpText(tester, const ['가나']);

    // 첫 프레임은 아직 벌어져 있습니다.
    expect(trackingOf(tester, '가나'), greaterThan(0));

    // 찍히고 흔들림까지 끝나면 시안 자간(0)입니다.
    await tester.pump(
      MafiaEjectionText.slamDuration + MafiaEjectionText.impactDuration,
    );
    expect(trackingOf(tester, '가나'), moreOrLessEquals(0, epsilon: 0.01));
  });

  testWidgets('긴 문구는 두 박자로 나눠 차례로 찍는다', (tester) async {
    await pumpText(tester, const ['가나님은', '밤을 넘기지 못했습니다']);

    // 첫 박자만 보입니다. 두 문구가 겹쳐 있으면 안 됩니다.
    expect(find.text('가나님은'), findsOneWidget);
    expect(find.text('밤을 넘기지 못했습니다'), findsNothing);

    // 첫 박자가 물러나고 두 번째가 그 자리에 찍힙니다.
    await pumpUntilText(tester, '밤을 넘기지 못했습니다');
    expect(find.text('가나님은'), findsNothing);

    // 마지막 박자는 남습니다.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('밤을 넘기지 못했습니다'), findsOneWidget);
  });

  testWidgets('문구가 갈리면 처음 박자부터 다시 찍는다', (tester) async {
    await pumpText(tester, const ['가나님은', '밤을 넘기지 못했습니다']);
    await pumpUntilText(tester, '밤을 넘기지 못했습니다');

    // 닉네임이 바뀌는 경우입니다(다음 밤의 발표).
    await pumpText(tester, const ['다라님은', '밤을 넘기지 못했습니다']);
    expect(find.text('다라님은'), findsOneWidget);
  });

  testWidgets('나눠 찍는 문구는 한 박자보다 빠르게 찍힌다', (tester) async {
    // 같은 시점에 자간이 더 좁혀져 있으면 더 빨리 찍히는 중입니다.
    const at = Duration(milliseconds: 150);

    await pumpText(tester, const ['가나님은', '밤을 넘기지 못했습니다']);
    await tester.pump(at);
    final twoBeats = trackingOf(tester, '가나님은')!;

    await pumpText(tester, const ['가나님은']);
    await tester.pump(at);
    final oneBeat = trackingOf(tester, '가나님은')!;

    expect(twoBeats, lessThan(oneBeat));
  });

  test('박자 시간은 부모가 주는 발표 시간 안에 들어간다', () {
    // 두 박자가 다 찍히기 전에 발표가 걷히면 마지막 말이 잘립니다.
    final total = MafiaEjectionText.totalCycle(
      2,
      MafiaEjectionText.defaultBeatHold,
    );
    // 나눠 찍을 때는 1.25배 빠르게 지나갑니다.
    expect(
      total.inMilliseconds,
      ((300 + 180 + 1500 + 240 + 300 + 180) / 1.25).round(),
    );
    // 아침 사망자 발표는 8초를 줍니다.
    expect(total, lessThan(const Duration(seconds: 8)));
  });

  test('한 박자짜리 문구의 속도는 그대로다', () {
    expect(
      MafiaEjectionText.totalCycle(
        1,
        MafiaEjectionText.defaultBeatHold,
      ).inMilliseconds,
      300 + 180,
    );
    expect(
      MafiaEjectionText.scaledFor(const Duration(milliseconds: 1000), 1),
      const Duration(milliseconds: 1000),
    );
    expect(
      MafiaEjectionText.scaledFor(const Duration(milliseconds: 1000), 2),
      const Duration(milliseconds: 800),
    );
  });
}
