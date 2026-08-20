import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/core/network/network_unavailable_modal.dart';
import 'package:project00/core/network/realtime_connection_monitor.dart';

void main() {
  group('AppNetworkGuard', () {
    testWidgets('연결 스트림이 없는 앱 루트에서는 모달을 띄우지 않는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppNetworkGuard(child: Scaffold(body: SizedBox.expand())),
        ),
      );

      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);
    });

    testWidgets('기본 유예 시간은 Firebase 재연결을 위해 10초를 보장한다', (tester) async {
      final connectionChanges = StreamController<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: AppNetworkGuard(
            connectionChanges: connectionChanges.stream,
            onRetry: () async {},
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );

      connectionChanges.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 9999));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);
      await connectionChanges.close();
    });

    testWidgets('필수 화면의 최초 false가 지연 시간 동안 유지되면 모달을 띄운다', (tester) async {
      final connectionChanges = StreamController<bool>();
      await _pumpGuard(tester, connectionChanges.stream);

      connectionChanges.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);
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

    testWidgets('표시된 모달은 재연결 복구 콜백이 성공한 뒤 닫힌다', (tester) async {
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

      connectionChanges.add(true);
      await tester.pump();
      expect(retries, 1);
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);
      await connectionChanges.close();
    });

    testWidgets('연결이 끊긴 동안 재시도는 복구 콜백을 실행하고 모달을 유지한다', (tester) async {
      final connectionChanges = StreamController<bool>();
      var retries = 0;
      await _pumpGuard(
        tester,
        connectionChanges.stream,
        onRetry: () async => retries += 1,
      );

      connectionChanges.add(false);
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(NetworkUnavailableModal.retryButtonKey));
      await tester.pump();

      expect(retries, 1);
      expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);
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
