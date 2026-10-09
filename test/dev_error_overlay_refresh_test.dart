import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/dev_error_overlay.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

void main() {
  testWidgets('Navigator 위에서도 진단 창 열기·복사·지우기·닫기가 동작한다', (tester) async {
    final log = GameCommunicationLog.instance;
    log.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DevErrorOverlay(child: child!),
        home: const SizedBox.expand(),
      ),
    );
    await tester.tap(find.byKey(DevErrorOverlay.diagnosticsButtonKey));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(DevErrorOverlay.diagnosticsSheetKey), findsOneWidget);
    log.add(
      level: GameCommunicationLevel.info,
      title: '준비 확인',
      detail: '테스트 기록',
    );
    await tester.pump();
    expect(find.text('준비 확인'), findsOneWidget);
    await tester.tap(find.byTooltip('기록 복사'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('기록 지우기'));
    await tester.pump();
    expect(find.text('아직 기록된 게임 통신이 없습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('닫기'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(DevErrorOverlay.diagnosticsButtonKey), findsOneWidget);
    await tester.tap(find.byKey(DevErrorOverlay.diagnosticsButtonKey));
    await tester.pump();
    expect(find.byKey(DevErrorOverlay.diagnosticsSheetKey), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    log.clear();
  });

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
