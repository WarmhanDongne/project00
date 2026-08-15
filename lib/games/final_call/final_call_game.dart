import 'package:flutter/widgets.dart';
import 'package:project00/games/_game_template/template_game.dart';
import 'package:project00/games/final_call/screens/phone_game.dart';
import 'package:project00/games/final_call/screens/tablet_game.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class FinalCallGame extends TemplateGame {
  const FinalCallGame();

  @override
  String get id => 'final_call';
  @override
  String get title => 'Final Call';
  @override
  String get leaveFunctionName => 'leaveFinalCallGame';

  @override
  Future<void> startGame(String roomCode) =>
      FinalCallService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => FinalCallService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required Future<bool> Function() onExitRoom,
  }) {
    return PhoneGame(
      roomCode: roomCode,
      gameService: FinalCallService(),
      onExitRoom: onExitRoom,
    );
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  }) {
    // Final Call 태블릿 화면은 좌석 배치를 쓰지 않아 playerLayout을 사용하지 않습니다.
    return FinalCallTabletGameEntry(
      roomCode: roomCode,
      gameService: FinalCallService(),
      provider: provider,
    );
  }
}
