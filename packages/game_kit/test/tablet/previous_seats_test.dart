import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/player_layouts/services/player_layout_factory.dart';
import 'package:game_kit/player_layouts/widgets/player_layout_editor.dart';

class _Player implements GameRoomPlayer {
  const _Player(this.uid, this.seatIndex);

  @override
  final String uid;
  @override
  final int seatIndex;
  @override
  String get nickname => uid;
  @override
  String get characterId => 'bear';
  @override
  bool get isConnected => true;
  @override
  String get role => 'player';
  @override
  String get status => 'active';
  @override
  bool get isPlayer => true;
  @override
  bool get isActive => true;
}

void main() {
  group('PlayerLayoutFactory.fromSavedSeats', () {
    test('지난 게임 자리를 참가자 순서 그대로 다시 만든다', () {
      final layout = PlayerLayoutFactory.fromSavedSeats(const [
        _Player('a', 2),
        _Player('b', 0),
        _Player('c', 1),
      ]);
      expect(layout?.players.map((player) => player.uid), ['a', 'b', 'c']);
      expect(layout?.seatIndexes, [2, 0, 1]);
    });

    test('누가 나가 번호가 비면 남은 사람 순서만 유지해 다시 매긴다', () {
      final layout = PlayerLayoutFactory.fromSavedSeats(const [
        _Player('a', 3),
        _Player('b', 0),
        _Player('c', 1),
      ]);
      expect(layout?.seatIndexes, [2, 0, 1]);
    });

    test('새로 들어온 사람이 있거나 번호가 겹치면 불러오지 않는다', () {
      expect(
        PlayerLayoutFactory.fromSavedSeats(const [
          _Player('a', 0),
          _Player('b', -1),
        ]),
        isNull,
      );
      expect(
        PlayerLayoutFactory.fromSavedSeats(const [
          _Player('a', 1),
          _Player('b', 1),
        ]),
        isNull,
      );
    });
  });

  group('PlayerLayoutEditor 이전 자리', () {
    const players = [_Player('a', 2), _Player('b', 0), _Player('c', 1)];
    final initial = PlayerLayoutFactory.create(players);
    final previous = PlayerLayoutFactory.fromSavedSeats(players);

    Future<List<PlayerLayoutModel>> pumpEditor(
      WidgetTester tester, {
      PlayerLayoutModel? previousLayout,
    }) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prepared = <PlayerLayoutModel>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerLayoutEditor(
            initialLayout: initial,
            previousLayout: previousLayout,
            tableColor: Colors.green,
            onPrepare: (layout) async {
              prepared.add(layout);
              return false;
            },
            onComplete: (_) {},
            onCancel: () async => true,
          ),
        ),
      );
      await tester.pump();
      return prepared;
    }

    testWidgets('이전 자리를 누르면 지난 게임 배치로 시작하고, 새로 배치할 수도 있다', (tester) async {
      final prepared = await pumpEditor(tester, previousLayout: previous);
      final button = find.widgetWithText(MosiButton, '이전 자리');
      expect(button, findsOneWidget);
      expect(find.widgetWithText(MosiButton, '섞기'), findsOneWidget);

      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<MosiButton>(button).onPressed, isNull);

      await tester.tap(find.widgetWithText(MosiButton, '설정 완료'));
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 300));
      expect(prepared.single.seatIndexes, [2, 0, 1]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('불러올 배치가 없으면 버튼을 보이지 않는다', (tester) async {
      await pumpEditor(tester);
      expect(find.widgetWithText(MosiButton, '이전 자리'), findsNothing);
      expect(find.widgetWithText(MosiButton, '섞기'), findsOneWidget);
    });
  });
}
