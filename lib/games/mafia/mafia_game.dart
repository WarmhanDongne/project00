import 'package:flutter/widgets.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/mafia/screens/phone_game.dart';
import 'package:project00/games/mafia/screens/tablet_game.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 마피아를 플랫폼(방 생성·대기·미리보기·퇴장)에 연결합니다.
///
/// `game_registry.dart`에 인스턴스를 넣으면 플랫폼 화면은 수정 없이 이 게임을
/// 인식합니다.
class MafiaGame extends TemplateGame {
  const MafiaGame();

  @override
  String get id => 'mafia';

  @override
  String get title => '마피아';

  // 고정 인원이 아닙니다. 4~12인이며 실제 시작 가능 여부는 서버가 구성표로
  // 확인합니다(`mafiaCompositionFor`).
  @override
  int? get fixedPlayerCount => null;

  @override
  String get leaveFunctionName => 'game_mafia_leave_game';

  /// 시안이 402 × 874 세로 화면입니다.
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitOnly;

  /// 낮 배경의 종이 바탕색입니다.
  @override
  Color get tableColor => const Color(0xFFF2F2F2);

  @override
  ImageProvider get tableBackgroundImage =>
      Assets.games.mafia.images.background.backgroundMorning.game.provider();

  @override
  Future<void> startGame(String roomCode) =>
      MafiaService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => MafiaService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required Future<bool> Function() onExitRoom,
  }) {
    return MafiaPhoneGame(
      roomCode: roomCode,
      gameService: MafiaService(),
      onExitRoom: onExitRoom,
    );
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  }) {
    return MafiaTabletGame(
      roomCode: roomCode,
      gameService: MafiaService(),
      playerLayout: playerLayout,
      provider: provider,
    );
  }
}
