// 룰렛의 회전 속도와 서버 결과 반영을 함께 검증합니다.
// 실제 서버·사운드 없이 레버를 당기고, 화면이 사용하는 회전 각도를 측정합니다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:roulette/roulette.dart';

void main() {
  for (final result in RouletteResult.values) {
    testWidgets('낮춘 시작 속도에서 가속 없이 천천히 감속해 ${result.name} 칸에 멈춘다', (
      tester,
    ) async {
      final prepared = Completer<RouletteResult?>();
      final results = <RouletteResult>[];
      await _mountRoulette(tester, prepared: prepared, onResult: results.add);
      await _pullLever(tester);

      final waitingSpeed = await _sampleSpeed(tester);
      expect(waitingSpeed, closeTo((1 / 0.3) * 2 * math.pi, 0.01));
      expect(results, isEmpty);

      prepared.complete(result);
      await tester.pump();
      await tester.pump();

      var previousSpeed = waitingSpeed;
      for (var frame = 0; frame < 125; frame++) {
        final speed = await _sampleSpeed(tester);
        expect(
          speed,
          lessThanOrEqualTo(previousSpeed + 0.001),
          reason: '서버 응답 직후부터 정지까지 다시 가속하면 안 됩니다: $frame',
        );
        previousSpeed = speed;
        // 마지막 감속을 일찍 끝내거나 멈춘 척 기다리는 연출로 바꾸지 않습니다.
        // 최소 감속이 4초이므로 3초 시점에도 천천히 움직이며 결과는 아직 없습니다.
        if (frame == 59) {
          expect(speed, greaterThan(0.01));
          expect(speed, lessThan(waitingSpeed * 0.3));
          expect(results, isEmpty);
        }
      }
      expect(previousSpeed, closeTo(0, 0.001));
      expect(results, [result]);

      // 포인터 아래의 칸도 서버 결과와 같아야 합니다. 속도 변경이 추첨 결과를
      // 바꾸거나 결과 callback을 두 번 보내는 회귀를 함께 막습니다.
      final roulette = tester.widget<Roulette>(find.byType(Roulette));
      final count = roulette.group.units.length;
      final fraction = (_angle(tester) % (2 * math.pi)) / (2 * math.pi);
      final landedIndex = count - 1 - (fraction * count).floor();
      final landedColor = roulette.group.units[landedIndex].color;
      // 탈락 칸은 빨강, 생존 칸은 두 가지 보라색이 번갈아 칠해져 있습니다.
      expect(
        landedColor,
        result == RouletteResult.eliminated
            ? const Color(0xFFE0243A)
            : isIn(const [Color(0xFF24152E), Color(0xFF34204A)]),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(results, [result]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('서버 응답이 늦어도 먼저 회전하고 결과 수신 후에만 멈춘다', (tester) async {
    final prepared = Completer<RouletteResult?>();
    final results = <RouletteResult>[];
    await _mountRoulette(tester, prepared: prepared, onResult: results.add);
    await _pullLever(tester);

    // 원본 위젯은 실제 Stopwatch로 서버 대기 시간을 잽니다. 가상 pump 시간만
    // 늘리면 최소 감속 시간(4초) 분기를 검증할 수 없어 이 한 사례는 실제로
    // 응답을 6초 넘게 지연시킵니다. 외부 서버나 네트워크는 사용하지 않습니다.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 6100)),
    );
    await tester.pump(const Duration(seconds: 5));
    final waitingSpeed = await _sampleSpeed(tester);
    expect(waitingSpeed, closeTo((1 / 0.3) * 2 * math.pi, 0.01));
    expect(results, isEmpty);

    prepared.complete(RouletteResult.safe);
    await tester.pump();
    await tester.pump();
    var previousSpeed = waitingSpeed;
    for (var frame = 0; frame < 85; frame++) {
      final speed = await _sampleSpeed(tester);
      expect(speed, lessThanOrEqualTo(previousSpeed + 0.001));
      previousSpeed = speed;
      if (frame < 75) expect(results, isEmpty);
    }
    expect(previousSpeed, closeTo(0, 0.001));
    expect(results, [RouletteResult.safe]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('서버 결과가 없으면 임의 결과를 보내지 않고 레버를 다시 사용할 수 있다', (tester) async {
    final prepared = Completer<RouletteResult?>();
    final results = <RouletteResult>[];
    await _mountRoulette(tester, prepared: prepared, onResult: results.add);
    await _pullLever(tester);
    prepared.complete(null);
    await tester.pumpAndSettle();

    expect(await _sampleSpeed(tester), closeTo(0, 0.001));
    expect(results, isEmpty);
    final detector = _leverFinder();
    final pointerGuard = tester.widget<IgnorePointer>(
      find.ancestor(of: detector, matching: find.byType(IgnorePointer)).first,
    );
    expect(pointerGuard.ignoring, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _mountRoulette(
  WidgetTester tester, {
  required Completer<RouletteResult?> prepared,
  required ValueChanged<RouletteResult> onResult,
}) async {
  tester.view.physicalSize = const Size(1300, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PenaltyRoulette(
          attemptCount: 0,
          onPrepareResult: () => prepared.future,
          onResult: onResult,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _leverFinder() => find.byWidgetPredicate(
  (widget) => widget is GestureDetector && widget.onVerticalDragStart != null,
);

Future<void> _pullLever(WidgetTester tester) async {
  final rect = tester.getRect(_leverFinder());
  // 레버 터치 영역 안에서 빨간 손잡이의 처음 중심을 잡고, 손잡이가 끝까지
  // 내려가는 거리보다 조금 더 끌어내립니다(영역 크기에 비례).
  final scale = rect.height / RouletteWheel.leverGestureHeight;
  final gesture = await tester.startGesture(
    rect.topLeft +
        Offset(
          rect.width / 2,
          (RouletteWheel.leverHeadTop + RouletteWheel.leverHeadSize / 2) *
              scale,
        ),
  );
  await gesture.moveBy(const Offset(0, 20));
  await gesture.moveBy(Offset(0, RouletteWheel.leverTravel * scale * 1.2));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

double _angle(WidgetTester tester) {
  final builder = tester.widget<AnimatedBuilder>(
    find.descendant(
      of: find.byType(Roulette),
      matching: find.byType(AnimatedBuilder),
    ),
  );
  return (builder.animation as Animation<double>).value;
}

Future<double> _sampleSpeed(WidgetTester tester) async {
  final before = _angle(tester);
  await tester.pump(const Duration(milliseconds: 50));
  final delta = (_angle(tester) - before) % (2 * math.pi);
  return delta / 0.05;
}
