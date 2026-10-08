import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/update/shorebird_patch_gate.dart';

void main() {
  testWidgets('개발 빌드에서는 Shorebird 엔진 경고 없이 앱을 바로 표시한다', (tester) async {
    final printedLines = <String>[];

    await runZoned(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ShorebirdPatchGate(child: Text('MOSIGAME'))),
        );
        await tester.pump();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printedLines.add(line),
      ),
    );

    expect(find.text('MOSIGAME'), findsOneWidget);
    expect(
      printedLines.where(
        (line) => line.contains('Shorebird Updater is unavailable'),
      ),
      isEmpty,
    );
  });
}
