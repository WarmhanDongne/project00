import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:game_kit/game_flow/game_presentation_sequence.dart';
import 'package:game_kit/recovery/widgets/game_request_notice.dart';

void main() {
  testWidgets(
    'pause preserves remaining time; overlapping reasons must all clear',
    (tester) async {
      final clock = GamePresentationClock(now: tester.binding.clock.now);
      var calls = 0;
      clock.schedule(const Duration(seconds: 4), () => calls++);
      await tester.pump(const Duration(seconds: 1));
      clock.setPaused('network', true);
      clock.setPaused('interruption', true);
      await tester.pump(const Duration(seconds: 20));
      clock.setPaused('network', false);
      await tester.pump(const Duration(seconds: 20));
      expect(calls, 0);
      clock.setPaused('interruption', false);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
      clock.dispose();
    },
  );

  testWidgets(
    'new paused timers do not run; cancelled/disposed timers never fire',
    (tester) async {
      final clock = GamePresentationClock(now: tester.binding.clock.now);
      clock.setPaused('pause', true);
      var calls = 0;
      final cancelled = clock.schedule(Duration.zero, () => calls++);
      cancelled.cancel();
      clock.schedule(const Duration(seconds: 1), () => calls++);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 0);
      clock.setPaused('pause', false);
      clock.dispose();
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 0);
    },
  );

  testWidgets(
    'sequence waits during interruption and retains last scene after completion',
    (tester) async {
      final clock = GamePresentationClock(now: tester.binding.clock.now);
      final connection = StreamController<bool>.broadcast();
      Widget screen(bool interrupted) => MaterialApp(
        home: GamePresentationBoundary(
          clock: clock,
          connectionChanges: connection.stream,
          interrupted: interrupted,
          child: const GamePresentationSequence(
            beats: [
              GamePresentationBeat(
                hold: Duration(seconds: 4),
                child: Text('개표'),
              ),
              GamePresentationBeat(
                hold: Duration(seconds: 4),
                child: Text('처형 발표'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(screen(false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(screen(true));
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('개표'), findsOneWidget);
      expect(find.text('처형 발표'), findsNothing);
      await tester.pumpWidget(screen(false));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('처형 발표'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(find.text('처형 발표'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
      await connection.close();
    },
  );

  testWidgets('network and background both pause the presentation boundary', (
    tester,
  ) async {
    final clock = GamePresentationClock(now: tester.binding.clock.now);
    final connection = StreamController<bool>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: GamePresentationBoundary(
          clock: clock,
          connectionChanges: connection.stream,
          interrupted: false,
          child: const SizedBox(),
        ),
      ),
    );
    connection.add(false);
    await tester.pump();
    expect(clock.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    connection.add(true);
    await tester.pump();
    expect(clock.paused, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(clock.paused, isFalse);
    await tester.pumpWidget(const SizedBox());
    clock.dispose();
    await connection.close();
  });

  testWidgets(
    'animation resumes from its saved position instead of jumping to the end',
    (tester) async {
      final clock = GamePresentationClock(now: tester.binding.clock.now);
      final key = GlobalKey<_AnimatedProbeState>();
      final stream = const Stream<bool>.empty();
      await tester.pumpWidget(
        MaterialApp(
          home: GamePresentationBoundary(
            clock: clock,
            connectionChanges: stream,
            interrupted: false,
            child: _AnimatedProbe(key: key),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final before = key.currentState!.animation.value;
      expect(before, greaterThan(0));
      clock.setPaused('pause', true);
      await tester.pump(const Duration(seconds: 20));
      expect(key.currentState!.animation.value, before);
      clock.setPaused('pause', false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(key.currentState!.animation.value, closeTo(before + .4, .02));
      await tester.pumpAndSettle();
      expect(key.currentState!.animation.value, 1);
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy notice never offers a duplicate retry; failure does', (
    tester,
  ) async {
    var retries = 0;
    Widget notice(bool busy) => MaterialApp(
      home: Scaffold(
        body: GameRequestNotice(
          busy: busy,
          message: '전송하지 못했습니다.',
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pumpWidget(notice(true));
    expect(find.text('재시도'), findsNothing);
    await tester.pumpWidget(notice(false));
    await tester.tap(find.text('재시도'));
    expect(retries, 1);
    expect(find.text('전송하지 못했습니다.'), findsOneWidget);
  });
}

class _AnimatedProbe extends StatefulWidget {
  const _AnimatedProbe({super.key});
  @override
  State<_AnimatedProbe> createState() => _AnimatedProbeState();
}

class _AnimatedProbeState extends State<_AnimatedProbe>
    with SingleTickerProviderStateMixin, GamePresentationState {
  late final AnimationController animation;
  @override
  Iterable<AnimationController> get presentationAnimations => [animation];
  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }
}
