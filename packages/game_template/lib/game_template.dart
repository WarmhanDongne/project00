// game_template.dart: 게임 등록 정보와 두 기기의 board를 연결합니다.
//
// - [Package] : 새 게임 템플릿
// - [GameEntry] : 게임 패키지를 플랫폼에 연결하는 진입 계약을 구현함
//
// 즉, 플랫폼이 게임 목록·화면·서비스를 동일한 방식으로 실행하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_template/phone/phone_board.dart';
import 'package:game_template/tablet/tablet_board.dart';
import 'package:game_template/shared/services/game_service.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_kit/player_layouts/player_layout_model.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_template/game_theme.dart';
// ============================================================

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
  Color get tableColor => TemplateColors.primary;
  @override
  ImageProvider? get tableBackgroundImage => null;

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      TemplateService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => TemplateService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) {
    return TemplatePhoneGame(roomCode: roomCode, onExitRoom: onExitRoom);
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) {
    return TemplateTabletGame(playerLayout: playerLayout, roomCode: roomCode);
  }
}
