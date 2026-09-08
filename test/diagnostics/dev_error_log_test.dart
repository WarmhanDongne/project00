import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/diagnostics/dev_error_log.dart';
import 'package:game_kit/core/diagnostics/dev_error_overlay.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

//=======================개발용 오류 표시==============================
// 일반 오류 원문은 숨기고 게임 통신 타임라인만 개발 화면에 표시합니다.
void main() {
  setUp(() {
    DevErrorLog.instance.clear();
    GameCommunicationLog.instance.clear();
  });
  tearDown(() {
    DevErrorLog.instance.clear();
    GameCommunicationLog.instance.clear();
  });

  void addError(String message, {String? context}) {
    DevErrorLog.instance.add(
      error: message,
      stack: StackTrace.fromString(
        '#0      something (package:flutter/src/widgets/framework.dart:1)\n'
        '#1      MafiaThing.build (package:game_mafia/x.dart:42)',
      ),
      context: context ?? '시험',
      time: DateTime(2026, 8, 21, 9, 30, 15),
    );
  }

  group('기록', () {
    test('최근 오류가 앞에 오고 개수 상한을 지킨다', () {
      for (var i = 0; i < DevErrorLog.maxEntries + 5; i += 1) {
        addError('오류 $i');
      }

      final entries = DevErrorLog.instance.entries;
      expect(entries.length, DevErrorLog.maxEntries);
      expect(
        entries.first.summary,
        contains('오류 ${DevErrorLog.maxEntries + 4}'),
      );
    });

    test('우리 코드의 첫 스택 줄을 뽑아 준다', () {
      addError('빨간 화면');

      // 프레임워크 줄이 먼저 나와도 workspace package 줄을 찾아야 고칠 곳이 보입니다.
      expect(
        DevErrorLog.instance.entries.first.firstProjectFrame,
        contains('games/mafia/x.dart:42'),
      );
    });

    test('확인하면 새 오류 표시가 사라진다', () {
      addError('하나');
      addError('둘');
      expect(DevErrorLog.instance.unseenCount, 2);

      DevErrorLog.instance.markSeen();
      expect(DevErrorLog.instance.unseenCount, 0);
      // 확인해도 기록 자체는 남습니다.
      expect(DevErrorLog.instance.entries.length, 2);
    });
  });

  group('화면 표시', () {
    testWidgets('휴대폰과 아이패드 모두 오른쪽 아래에 진단 버튼을 표시한다', (tester) async {
      for (final size in [const Size(390, 844), const Size(1194, 834)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          const MaterialApp(home: DevErrorOverlay(child: Text('게임 화면'))),
        );

        final button = find.byKey(DevErrorOverlay.diagnosticsButtonKey);
        expect(button, findsOneWidget);
        final rect = tester.getRect(button);
        expect(size.width - rect.right, lessThanOrEqualTo(20));
        expect(size.height - rect.bottom, lessThanOrEqualTo(40));
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('버튼을 누르면 통신 상태와 타임라인을 연다', (tester) async {
      GameCommunicationLog.instance.add(
        level: GameCommunicationLevel.failure,
        title: '카드 제출 요청 실패',
        detail: '서버 응답 시간초과',
        operation: 'game_liars_poker_submit_cards',
        traceId: 'cards_test',
      );
      await tester.pumpWidget(
        const MaterialApp(home: DevErrorOverlay(child: Text('게임 화면'))),
      );

      expect(find.text('게임 화면'), findsOneWidget);
      await tester.tap(find.byKey(DevErrorOverlay.diagnosticsButtonKey));
      await tester.pump();

      expect(find.byKey(DevErrorOverlay.diagnosticsSheetKey), findsOneWidget);
      expect(find.text('게임 통신 진단'), findsOneWidget);
      expect(find.text('카드 제출 요청 실패'), findsOneWidget);
      expect(find.textContaining('서버 응답 시간초과'), findsOneWidget);
    });

    testWidgets('일반 오류가 쌓여도 원문은 진단 화면에 나타나지 않는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DevErrorOverlay(child: Text('게임 화면'))),
      );
      addError('밤 제출이 터졌습니다');
      await tester.pump();
      await tester.tap(find.byKey(DevErrorOverlay.diagnosticsButtonKey));
      await tester.pump();

      expect(find.textContaining('밤 제출이 터졌습니다'), findsNothing);
    });

    testWidgets('위젯 오류 원문과 파일 위치도 화면에 보이지 않는다', (tester) async {
      // 테스트 프레임워크가 본문이 끝나는 시점에 ErrorWidget.builder가
      // 되돌려졌는지 확인하므로, tearDown이 아니라 본문에서 되돌립니다.
      final previousBuilder = ErrorWidget.builder;
      installDevErrorWidgetBuilder();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) => throw StateError('여기서 터집니다')),
        ),
      );

      expect(find.textContaining('여기서 터집니다'), findsNothing);
      expect(find.textContaining('package:project00'), findsNothing);
      expect(find.textContaining('package:mosigame_'), findsNothing);
      expect(find.textContaining('package:game_'), findsNothing);
      expect(DevErrorLog.instance.entries, isNotEmpty);
      ErrorWidget.builder = previousBuilder;
      // 위젯 오류는 테스트 프레임워크에도 보고되므로 확인 처리합니다.
      expect(tester.takeException(), isStateError);
    });
  });
}
