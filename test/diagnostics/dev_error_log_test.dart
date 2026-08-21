import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/diagnostics/dev_error_log.dart';
import 'package:project00/core/diagnostics/dev_error_overlay.dart';

//=======================개발용 오류 표시==============================
// 개발 중 시뮬레이터에서 오류를 화면으로 바로 확인하기 위한 장치입니다.
void main() {
  setUp(DevErrorLog.instance.clear);
  tearDown(DevErrorLog.instance.clear);

  void addError(String message, {String? context}) {
    DevErrorLog.instance.add(
      error: message,
      stack: StackTrace.fromString(
        '#0      something (package:flutter/src/widgets/framework.dart:1)\n'
        '#1      MafiaThing.build (package:project00/games/mafia/x.dart:42)',
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

      // 프레임워크 줄이 먼저 나와도 project00 줄을 찾아야 고칠 곳이 보입니다.
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
    testWidgets('오류가 없으면 아무것도 보이지 않는다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DevErrorOverlay(child: Text('게임 화면'))),
      );

      expect(find.text('게임 화면'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report), findsNothing);
    });

    testWidgets('오류가 쌓이면 표시가 뜨고 눌러서 내용을 본다', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DevErrorOverlay(child: Text('게임 화면'))),
      );
      addError('밤 제출이 터졌습니다');
      await tester.pump();

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
      expect(find.textContaining('오류 1'), findsOneWidget);

      // 눌러 목록을 열면 오류 내용이 보이고, 펼치면 복사할 수 있습니다.
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pumpAndSettle();
      expect(find.textContaining('밤 제출이 터졌습니다'), findsWidgets);

      await tester.tap(find.textContaining('밤 제출이 터졌습니다').first);
      await tester.pumpAndSettle();
      expect(find.text('복사'), findsOneWidget);
    });

    testWidgets('빌드가 터진 자리에는 오류와 파일 위치가 보인다', (tester) async {
      // 테스트 프레임워크가 본문이 끝나는 시점에 ErrorWidget.builder가
      // 되돌려졌는지 확인하므로, tearDown이 아니라 본문에서 되돌립니다.
      final previousBuilder = ErrorWidget.builder;
      installDevErrorWidgetBuilder();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) => throw StateError('여기서 터집니다')),
        ),
      );

      expect(find.textContaining('여기서 터집니다'), findsOneWidget);
      // 터진 오류도 목록에 함께 쌓입니다.
      expect(DevErrorLog.instance.entries, isNotEmpty);
      ErrorWidget.builder = previousBuilder;
      // 위젯 오류는 테스트 프레임워크에도 보고되므로 확인 처리합니다.
      expect(tester.takeException(), isStateError);
    });
  });
}
