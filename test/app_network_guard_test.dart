import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/network/app_network_guard.dart';
import 'package:project00/core/network/network_unavailable_modal.dart';

void main() {
  testWidgets('연결이 끊기면 지연 후 앱 전체 모달을 띄우고 재연결 시 닫는다', (tester) async {
    final connectionChanges = StreamController<bool>();
    var backgroundPresses = 0;
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppNetworkGuard(
          connectionChanges: connectionChanges.stream,
          showDelay: const Duration(seconds: 1),
          onRetry: () async {
            retries += 1;
          },
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => backgroundPresses += 1,
                child: const Text('뒤 화면'),
              ),
            ),
          ),
        ),
      ),
    );

    connectionChanges.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(NetworkUnavailableModal.cardKey), findsOneWidget);

    await tester.tap(find.text('뒤 화면'), warnIfMissed: false);
    expect(backgroundPresses, 0);

    await tester.tap(find.byKey(NetworkUnavailableModal.retryButtonKey));
    await tester.pump();
    expect(retries, 1);

    connectionChanges.add(true);
    await tester.pump();
    expect(find.byKey(NetworkUnavailableModal.cardKey), findsNothing);

    await connectionChanges.close();
  });

  testWidgets('태블릿에서는 휴대폰보다 큰 같은 모달을 사용한다', (tester) async {
    Future<Size> renderAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NetworkUnavailableModal(onRetry: () {})),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byKey(NetworkUnavailableModal.cardKey));
    }

    final phoneSize = await renderAt(const Size(390, 844));
    final tabletSize = await renderAt(const Size(1194, 834));

    expect(phoneSize.width, 350);
    expect(tabletSize.width, 720);
    expect(tabletSize.height, greaterThan(phoneSize.height));
    expect(find.text('네트워크에 접속할 수 없습니다.'), findsOneWidget);
    expect(find.text('네트워크 연결 상태를 확인해주세요.'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('가로 휴대폰의 낮은 화면에서도 모달 내용이 잘리지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NetworkUnavailableModal(onRetry: () {})),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(NetworkUnavailableModal.retryButtonKey), findsOneWidget);
    expect(
      tester
          .getBottomRight(find.byKey(NetworkUnavailableModal.retryButtonKey))
          .dy,
      lessThanOrEqualTo(390),
    );

    await tester.binding.setSurfaceSize(null);
  });
}
