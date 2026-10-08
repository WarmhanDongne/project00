import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/widgets/game_exit_route.dart';

void main() {
  for (final instantEntry in [false, true]) {
    testWidgets('game exit covers the old screen then reveals the destination '
        '(${instantEntry ? 'instant' : 'material'} entry)', (tester) async {
      late NavigatorState navigator;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              navigator = Navigator.of(context);
              return const Scaffold(body: Center(child: Text('lobby')));
            },
          ),
        ),
      );

      final Route<void> route = instantEntry
          ? GameExitInstantPageRoute<void>(
              pageBuilder: (_, _, _) =>
                  const Scaffold(body: Center(child: Text('game'))),
            )
          : GameExitMaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Center(child: Text('game'))),
            );
      navigator.push(route);
      await tester.pumpAndSettle();
      expect(find.text('game'), findsOneWidget);
      expect(find.byKey(const Key('game-exit-pattern')), findsNothing);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byKey(const Key('game-exit-pattern')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('game-exit-old-screen')))
            .opacity,
        1,
      );

      await tester.pump(const Duration(milliseconds: 330));
      expect(find.byKey(const Key('game-exit-pattern')), findsOneWidget);
      expect(
        tester
            .widget<Opacity>(find.byKey(const Key('game-exit-old-screen')))
            .opacity,
        0,
      );

      await tester.pumpAndSettle();
      expect(find.text('lobby'), findsOneWidget);
      expect(find.byKey(const Key('game-exit-pattern')), findsNothing);
    });
  }
}
