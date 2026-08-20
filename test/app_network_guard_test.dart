import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/core/network/network_unavailable_modal.dart';
import 'package:project00/core/network/realtime_connection_monitor.dart';

void main() {
  group('AppNetworkGuard', () {
    testWidgets('최초 false는 연결 초기화 상태로 보고 모달을 띄우지 않는다', (tester) async {
      final connectionChanges = StreamController<bool>();
      await _pumpGuard(tester, connectionChanges.stream);

      connectionChanges.add(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);
      await connectionChanges.close();
    });

    testWidgets('연결된 뒤 false가 지연 시간 동안 유지되면 모달을 띄운다', (tester) async {
      final connectionChanges = StreamController<bool>();
      await _pumpGuard(tester, connectionChanges.stream);

      connectionChanges.add(true);
      await tester.pump();
      connectionChanges.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);
      await connectionChanges.close();
    });

    testWidgets('지연 시간 안에 재연결되면 모달 예약을 취소한다', (tester) async {
      final connectionChanges = StreamController<bool>();
      await _pumpGuard(tester, connectionChanges.stream);

      connectionChanges.add(true);
      await tester.pump();
      connectionChanges.add(false);
      await tester.pump(const Duration(milliseconds: 500));
      connectionChanges.add(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);
      await connectionChanges.close();
    });

    testWidgets('표시된 모달은 재연결 시 닫히고 재시도 콜백을 호출한다', (tester) async {
      final connectionChanges = StreamController<bool>();
      var retries = 0;
      await _pumpGuard(
        tester,
        connectionChanges.stream,
        onRetry: () async => retries += 1,
      );

      connectionChanges.add(true);
      await tester.pump();
      connectionChanges.add(false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);

      await tester.tap(find.byKey(NetworkUnavailableModal.retryButtonKey));
      await tester.pump();
      expect(retries, 1);

      connectionChanges.add(true);
      await tester.pump();
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);
      await connectionChanges.close();
    });
  });

  test('서로 다른 연결 소스는 구독과 최신 상태를 공유하지 않는다', () async {
    final monitor = RealtimeConnectionMonitor.forTesting();
    final firstIdentity = Object();
    final secondIdentity = Object();
    var firstSourceListens = 0;
    var firstSourceCancels = 0;
    var secondSourceListens = 0;
    final firstSource = StreamController<bool>.broadcast(
      sync: true,
      onListen: () => firstSourceListens += 1,
      onCancel: () => firstSourceCancels += 1,
    );
    final secondSource = StreamController<bool>.broadcast(
      sync: true,
      onListen: () => secondSourceListens += 1,
    );

    final firstValues = <bool>[];
    final repeatedFirstValues = <bool>[];
    final secondValues = <bool>[];
    final firstSubscription = monitor
        .watchConnectionSource(firstIdentity, () => firstSource.stream)
        .listen(firstValues.add);
    final repeatedFirstSubscription = monitor
        .watchConnectionSource(firstIdentity, () => firstSource.stream)
        .listen(repeatedFirstValues.add);
    final secondSubscription = monitor
        .watchConnectionSource(secondIdentity, () => secondSource.stream)
        .listen(secondValues.add);

    expect(firstSourceListens, 1);
    expect(secondSourceListens, 1);
    expect(firstSourceCancels, 0);

    firstSource.add(true);
    secondSource.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(firstValues, [true]);
    expect(repeatedFirstValues, [true]);
    expect(secondValues, [false]);

    final lateFirstValues = <bool>[];
    final lateFirstSubscription = monitor
        .watchConnectionSource(firstIdentity, () => firstSource.stream)
        .listen(lateFirstValues.add);
    await Future<void>.delayed(Duration.zero);
    expect(lateFirstValues, [true]);
    expect(firstSourceListens, 1);

    secondSource.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(firstValues, [true]);
    expect(secondValues, [false, true]);

    await firstSubscription.cancel();
    await repeatedFirstSubscription.cancel();
    await lateFirstSubscription.cancel();
    await secondSubscription.cancel();
    await monitor.dispose();
    await firstSource.close();
    await secondSource.close();
  });
}

Future<void> _pumpGuard(
  WidgetTester tester,
  Stream<bool> connectionChanges, {
  Future<void> Function()? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AppNetworkGuard(
        connectionChanges: connectionChanges,
        onRetry: onRetry ?? () async {},
        showDelay: const Duration(seconds: 1),
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
}
