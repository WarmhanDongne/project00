import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/dev_error_overlay.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

void main() {
  testWidgets('build 중 통신 로그가 추가돼도 setState 예외가 나지 않는다', (tester) async {
    final log = GameCommunicationLog.instance;
    log.clear();
    var hasLoggedDuringBuild = false;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DevErrorOverlay(child: child!),
        home: Builder(
          builder: (context) {
            if (!hasLoggedDuringBuild) {
              hasLoggedDuringBuild = true;
              log.add(
                level: GameCommunicationLevel.info,
                title: '게임 함수 예열',
                detail: '빌드 중 통신 로그',
              );
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    log.clear();
  });
}
