import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/theme/platform_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('플랫폼 $brightness 테마가 assertion 없이 렌더링된다', (tester) async {
      final theme = brightness == Brightness.light
          ? PlatformTheme.light()
          : PlatformTheme.dark();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Column(
              children: [
                Text('본문'),
                Text('제목', style: TextStyle(fontSize: 22)),
                FilledButton(onPressed: null, child: Text('버튼')),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('본문'), findsOneWidget);
    });
  }
}
