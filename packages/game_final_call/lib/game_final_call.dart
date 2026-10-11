// game_final_call.dart: 게임 등록 정보와 두 기기의 board를 연결합니다.
//
// - [Package] : 파이널콜
// - [GameEntry] : 게임 정보를 플랫폼 공통 계약에 연결함
//
// 즉, 플랫폼이 게임별 내부 구조를 몰라도 시작하고 화면을 생성하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_final_call/phone/phone_board.dart';
import 'package:game_final_call/tablet/tablet_board.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';

// ============================================================

class FinalCallGame extends TemplateGame {
  const FinalCallGame();

  @override
  String get id => 'final_call';
  @override
  String get title => 'Final Call';
  @override
  List<int> get supportedPlayerCounts => const [4, 6];
  @override
  String get leaveFunctionName => 'game_final_call_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.landscapeOnly;
  // 자리 배치 화면은 Party Pop 게임 바탕색으로 테이블과 의자를 그립니다.
  // 게임 화면이 그림 대신 코드로 그리는 배경이라 별도 이미지가 없습니다.
  @override
  Color get tableColor => FinalCallColors.night;
  @override
  ImageProvider? get tableBackgroundImage => null;

  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      FinalCallService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => FinalCallService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) {
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        onExit: () => Navigator.of(context).popUntil((route) => route.isFirst),
        child: FinalCallPhoneGame(
          roomCode: roomCode,
          provider: provider,
          gameService: FinalCallService(),
          onExitRoom: onExitRoom,
        ),
      ),
    );
  }

  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) {
    // Final Call 태블릿 화면은 좌석 배치를 쓰지 않아 playerLayout을 사용하지 않습니다.
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        exitLabel: '대기실로',
        onExit: () => Navigator.of(context).maybePop(),
        child: FinalCallTabletGame(
          roomCode: roomCode,
          gameService: FinalCallService(),
          provider: provider,
        ),
      ),
    );
  }
}
