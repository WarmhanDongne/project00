import 'package:flutter/widgets.dart';
import 'package:project00/core/layout/app_orientation.dart';
import 'package:project00/games/_game_template/screens/phone_game.dart';
import 'package:project00/games/_game_template/screens/tablet_game.dart';
import 'package:project00/games/_game_template/services/template_service.dart';
import 'package:project00/games/template_game.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 새 게임을 만들 때 복사할 참조 구현입니다.
///
/// 사용법: `games/<my_game>/` 폴더를 이 파일 + `_game_template/services` +
/// `_game_template/screens` 구조 그대로 복사한 뒤 `template`을 게임 id로
/// 바꾸고, [GameRegistry.games]에 새 게임 인스턴스를 추가하세요. 이 클래스
/// 자체는 예시일 뿐이라 레지스트리에 등록하지 않습니다.
class TemplateExampleGame extends TemplateGame {
  const TemplateExampleGame();

  @override
  String get id => 'template_example';
  @override
  String get title => 'Template Example';
  @override
  String get leaveFunctionName => 'game_template_example_leave_game';
  @override
  // 새 게임의 휴대폰 UI가 실제로 지원하는 방향으로 반드시 변경하세요.
  // 태블릿 게임은 이 값과 관계없이 공용 정책에서 항상 가로 고정됩니다.
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitOnly;
  @override
  Color get tableColor => const Color(0xFF808080);
  @override
  ImageProvider? get tableBackgroundImage => null;

  @override
  Future<void> startGame(String roomCode) =>
      TemplateService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => TemplateService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required RoomProvider provider,
    required Future<bool> Function() onExitRoom,
  }) {
    return TemplatePhoneGame(roomCode: roomCode, onExitRoom: onExitRoom);
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required RoomProvider provider,
    required String roomCode,
  }) {
    return TemplateTabletGame(playerLayout: playerLayout, roomCode: roomCode);
  }
}
