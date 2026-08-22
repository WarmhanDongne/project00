import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/games/shared/widgets/tablet_game_settings_dialog.dart';
import 'package:project00/platform/home/gamelist/service/game_list_service.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/room/services/room_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

//=======================태블릿 설정 다이얼로그==============================
// 확정된 규약: **다이얼로그는 버튼을 누른 순간 스스로 닫고** 나서 콜백을
// 부릅니다. 그래서 게임 화면 쪽 콜백은 절대 다시 pop 하지 않아야 합니다.
//
// 마피아가 콜백에서 한 번 더 pop 해서, 설정에서 재시작·종료를 누르면 게임
// 화면까지 닫히며 튕겼습니다(2026-08). 그 회귀를 여기서 막습니다.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  RoomProvider buildRoom() =>
      RoomProvider(service: _FakeRoomService(), gameService: _FakeGameService())
        ..roomCode = 'AB12'
        ..players = [
          for (var i = 0; i < 6; i += 1)
            RoomPlayer(
              uid: 'u$i',
              nickname: '플레이어$i',
              characterId: 'frog',
              isConnected: true,
              seatIndex: i,
              role: 'player',
              status: 'ready',
              penaltyAttemptCount: 0,
            ),
        ];

  /// 게임 화면 위에 설정 다이얼로그를 띄운 상태를 만듭니다.
  ///
  /// 돌려주는 목록에 눌린 버튼이 순서대로 쌓입니다.
  Future<List<String>> pumpGameWithSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pressed = <String>[];
    final room = buildRoom();

    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: SoundProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TabletGameSettingsDialog(
                      provider: room,
                      // 게임 화면(마피아·LP·FC)이 넘기는 것과 같은 모양입니다.
                      onRestartGame: () => pressed.add('restart'),
                      onEndGame: () => pressed.add('end'),
                    ),
                  ),
                  child: const Text('게임 화면'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('게임 화면'));
    await tester.pumpAndSettle();
    return pressed;
  }

  testWidgets('게임 재시작을 누르면 다이얼로그만 닫히고 게임 화면은 남는다', (tester) async {
    final pressed = await pumpGameWithSettings(tester);
    expect(find.text('설정'), findsOneWidget);

    await tester.tap(find.text('게임 재시작'));
    await tester.pumpAndSettle();

    // 다이얼로그는 닫혔고, 게임 화면은 그대로 있어야 합니다.
    expect(find.text('설정'), findsNothing);
    expect(find.text('게임 화면'), findsOneWidget);
    // 콜백은 정확히 한 번 옵니다.
    expect(pressed, ['restart']);
  });

  testWidgets('게임 종료도 다이얼로그만 닫는다', (tester) async {
    final pressed = await pumpGameWithSettings(tester);

    await tester.tap(find.text('게임 종료'));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsNothing);
    expect(find.text('게임 화면'), findsOneWidget);
    expect(pressed, ['end']);
  });

  testWidgets('닫기는 다이얼로그만 닫고 아무 동작도 하지 않는다', (tester) async {
    final pressed = await pumpGameWithSettings(tester);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsNothing);
    expect(find.text('게임 화면'), findsOneWidget);
    expect(pressed, isEmpty);
  });

  testWidgets('showDialog로 띄워도 음량 슬라이더가 그려진다', (tester) async {
    // 회귀 방지: 공용 모달 프레임에 Material이 없어 Slider가 터졌습니다.
    await pumpGameWithSettings(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Slider), findsWidgets);
  });
}

class _FakeRoomService implements RoomService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeGameService implements GameService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
