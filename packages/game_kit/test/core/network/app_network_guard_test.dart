// 실제 서버 없이 연결 신호와 복구 응답을 조절하는 회귀 테스트입니다.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/network/app_network_guard.dart';
import 'package:game_kit/core/network/network_unavailable_modal.dart';

void main() {
  testWidgets('3초 미만 단절은 안내 없이 복구하고 그동안 입력을 막는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var taps = 0;
    var recoveries = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          recoveries++;
        },
        child: TextButton(onPressed: () => taps++, child: const Text('카드 제출')),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('카드 제출'), warnIfMissed: false);
    expect(taps, 0);
    expect(find.text('연결 확인 중…'), findsNothing);
    expect(find.byType(NetworkUnavailableModal), findsNothing);
    expect(recoveries, 0, reason: '오프라인에는 복구 callable을 호출하지 않는다');
    connection.add(true);
    await tester.pump();
    await tester.tap(find.text('카드 제출'));
    expect(recoveries, 1);
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('3초 배너, 10초 모달을 표시하고 끊김 반복으로 시간을 초기화하지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('연결 확인 중…'), findsOneWidget);
    expect(find.byType(NetworkUnavailableModal), findsNothing);
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(find.byType(NetworkUnavailableModal), findsOneWidget);
    expect(find.text('연결 확인 중…'), findsNothing);
    expect(find.text('게임 화면'), findsOneWidget);
    expect(
      tester
          .widget<NetworkUnavailableModal>(find.byType(NetworkUnavailableModal))
          .retryEnabled,
      isFalse,
    );
    connection.add(true);
    await tester.pump();
    expect(find.byType(NetworkUnavailableModal), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('연결 신호만 돌아와도 세션 복구가 끝나기 전에는 입력을 풀지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final recovery = Completer<void>();
    var taps = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => recovery.future,
        child: TextButton(onPressed: () => taps++, child: const Text('CALL')),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('연결 확인 중…'), findsOneWidget);
    await tester.tap(find.text('CALL'), warnIfMissed: false);
    expect(taps, 0);
    recovery.complete();
    await tester.pump();
    await tester.tap(find.text('CALL'));
    expect(taps, 1);
    expect(find.text('연결 확인 중…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('복구 실패는 1, 2, 4, 8초 간격으로 재시도하고 성공 후 멈춘다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var attempts = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          attempts++;
          if (attempts < 6) throw StateError('일시적 복구 실패');
        },
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    expect(attempts, 1);
    var expected = 1;
    for (final seconds in [1, 2, 4, 8, 8]) {
      await tester.pump(Duration(milliseconds: seconds * 1000 - 1));
      expect(attempts, expected);
      await tester.pump(const Duration(milliseconds: 1));
      expect(attempts, ++expected);
    }
    await tester.pump(const Duration(seconds: 30));
    expect(attempts, 6);
    expect(find.byType(NetworkUnavailableModal), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('재단절 전의 늦은 복구 응답은 새 연결의 입력을 풀지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final first = Completer<void>();
    final second = Completer<void>();
    var calls = 0;
    var taps = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => ++calls == 1 ? first.future : second.future,
        child: TextButton(onPressed: () => taps++, child: const Text('카드 제출')),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    expect(calls, 1, reason: '진행 중 복구와 동시에 새 요청을 보내지 않는다');
    first.complete();
    await tester.pump();
    await tester.tap(find.text('카드 제출'), warnIfMissed: false);
    expect(taps, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    second.complete();
    await tester.pump();
    await tester.tap(find.text('카드 제출'));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('중첩 가드는 복구 요청을 중복하지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    var outer = 0;
    var inner = 0;
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () async {
          outer++;
        },
        child: AppNetworkGuard(
          connectionChanges: connection.stream,
          onRetry: () async {
            inner++;
          },
          child: const Text('게임 화면'),
        ),
      ),
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('연결 확인 중…'), findsOneWidget);
    connection.add(true);
    await tester.pump();
    expect(outer, 1);
    expect(inner, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dispose 이후 늦은 복구 완료가 새 타이머를 만들지 않는다', (tester) async {
    final connection = StreamController<bool>.broadcast();
    addTearDown(connection.close);
    final recovery = Completer<void>();
    await _mount(
      tester,
      AppNetworkGuard(
        connectionChanges: connection.stream,
        onRetry: () => recovery.future,
        child: const Text('게임 화면'),
      ),
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    recovery.completeError(StateError('늦은 실패'));
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    MaterialApp(
      home: DefaultAssetBundle(
        bundle: _TestAssets(),
        child: Scaffold(body: child),
      ),
    ),
  );
}

// 모달 이미지가 실제 번들 다운로드 상태에 의존하지 않도록 테스트용 PNG를 사용합니다.
class _TestAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png')) {
      return ByteData.sublistView(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    }
    return rootBundle.load(key);
  }
}
