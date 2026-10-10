import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';

const _labels = MosiConnectionBandLabels(
  lost: '연결이 끊겼어요',
  reconnecting: '다시 연결하는 중',
  restored: '다시 연결됐어요',
);

void main() {
  late StreamController<bool> connection;

  setUp(() => connection = StreamController<bool>.broadcast());
  tearDown(() => connection.close());

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: MosiConnectionBandHost(
        connectionChanges: connection.stream,
        labels: _labels,
        child: const Scaffold(body: Text('로비')),
      ),
    ),
  );

  Finder bandWith(String text) => find.descendant(
    of: find.byType(MosiConnectionBand),
    matching: find.text(text),
  );

  testWidgets('잠깐 흔들렸다 돌아오면 띠를 띄우지 않는다', (tester) async {
    await pumpHost(tester);
    connection.add(false);
    await tester.pump(const Duration(milliseconds: 800));
    connection.add(true);
    await tester.pump(const Duration(seconds: 5));
    final band = tester.widget<MosiConnectionBand>(
      find.byType(MosiConnectionBand),
    );
    // 띠는 숨은 채로 있고(아래로 밀려 있음), 복구 문구도 나오지 않습니다.
    expect(band.phase, isNot(MosiConnectionBandPhase.restored));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1.1),
    );
  });

  testWidgets('끊김 → 다시 연결 중 → 복구 순서로 바뀐 뒤 사라진다', (tester) async {
    await pumpHost(tester);
    connection.add(false);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(bandWith('연결이 끊겼어요'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(bandWith('다시 연결하는 중'), findsOneWidget);

    connection.add(true);
    await tester.pump();
    expect(bandWith('다시 연결됐어요'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1.1),
    );
    expect(find.text('로비'), findsOneWidget);
  });

  testWidgets('방 구독이 없는 유휴 로비는 90초 뒤에도 연결 장애로 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MosiConnectionBandHost(
          connectionChanges: null,
          labels: _labels,
          child: const Scaffold(body: Text('로비')),
        ),
      ),
    );
    connection.add(
      false,
    ); // SDK idle false exists, but this lobby needs no room transport.
    await tester.pump(const Duration(seconds: 90));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1.1),
    );
  });

  testWidgets('단절된 방에서 빈 로비로 바뀌면 이전 재연결 타이머를 정리한다', (tester) async {
    await pumpHost(tester);
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<MosiConnectionBand>(find.byType(MosiConnectionBand)).phase,
      MosiConnectionBandPhase.reconnecting,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MosiConnectionBandHost(
          connectionChanges: null,
          labels: _labels,
          child: const Scaffold(body: Text('로비')),
        ),
      ),
    );
    connection.add(false);
    await tester.pump(const Duration(seconds: 90));
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1.1),
    );
    // Adopting a room later re-enables genuine transport loss protection.
    await pumpHost(tester);
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(seconds: 3));
    expect(
      tester.widget<MosiConnectionBand>(find.byType(MosiConnectionBand)).phase,
      MosiConnectionBandPhase.reconnecting,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
