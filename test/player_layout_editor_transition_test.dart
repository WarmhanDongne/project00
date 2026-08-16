import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/player_layouts/player_layout_editor.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';

void main() {
  testWidgets('서버 준비 중에는 Scrim 없이 테이블 화면을 유지한다', (tester) async {
    final preparation = Completer<bool>();
    final navigatorKey = GlobalKey<NavigatorState>();
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: PlayerLayoutEditor(
          initialLayout: const PlayerLayoutModel(
            players: [
              PlayerLayoutPlayer(
                uid: 'one',
                nickname: 'One',
                profileImageUrl: '',
                seatIndex: 0,
              ),
              PlayerLayoutPlayer(
                uid: 'two',
                nickname: 'Two',
                profileImageUrl: '',
                seatIndex: 1,
              ),
            ],
          ),
          tableColor: const Color(0xFF6E2A82),
          onPrepare: (_) => preparation.future,
          onComplete: (_) {
            completed = true;
            navigatorKey.currentState!.pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => const ColoredBox(
                  key: Key('game-screen'),
                  color: Color(0xFF6E2A82),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('설정 완료'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1601));
    await tester.pump(const Duration(milliseconds: 1001));
    await tester.pump();

    expect(find.text('게임을 준비하고 있습니다.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(completed, isFalse);

    preparation.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(find.byKey(const Key('game-screen')), findsOneWidget);
    expect(find.byType(PlayerLayoutEditor), findsNothing);
  });
}
