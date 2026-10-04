// [game_liars_poker.dart] 라이어스 포커의 기본 정보와
// 휴대폰·태블릿 보드를 앱의 게임 등록 시스템에 연결하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/widgets.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_liars_poker/phone/phone_board.dart';
import 'package:game_liars_poker/tablet/tablet_board.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:game_liars_poker/game_theme.dart';

// ============================================================

// LiarsPokerGame
// │
// ├─ ① 게임 기본 정보 → id, 이름, 인원, 이미지
// ├─ ② 서버 연결 → 시작·퇴장 명령과 서비스
// └─ ③ 기기별 화면 → phone_board·tablet_board

// ---------------------------------------------------------------------------
// 라이어스포커 플랫폼 연결
// ---------------------------------------------------------------------------
class LiarsPokerGame extends TemplateGame {
  const LiarsPokerGame();

  // ---------------------------------------------------------------------------
  // 게임 목록에 보여줄 기본 정보
  // ---------------------------------------------------------------------------
  @override
  String get id => 'liars_poker';
  @override
  String get title => "Liar's Poker";
  @override
  String get leaveFunctionName => 'game_liars_poker_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitAndLandscape;
  @override
  Color get tableColor => LiarsPokerColors.primary;
  @override
  ImageProvider get tableBackgroundImage =>
      Assets.games.liarsPoker.images.background.background.game.provider();
  @override
  ImageProvider get layoutTableImage =>
      Assets.games.liarsPoker.images.layout.layoutTable.game.provider();
  @override
  ImageProvider get layoutChairImage =>
      Assets.games.liarsPoker.images.layout.layoutChair.game.provider();

  // ---------------------------------------------------------------------------
  // 서버 게임 시작과 상태 구독
  // ---------------------------------------------------------------------------
  /// Cloud Functions의 게임 시작 명령을 호출하는 쓰기 전용 서비스입니다.
  @override
  Future<void> startGame(String roomCode, {Map<String, Object?>? options}) =>
      LiarsPokerService().command.startGame(roomCode: roomCode);

  @override
  Stream<String?> watchStatus(String roomCode) => LiarsPokerService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);

  // ---------------------------------------------------------------------------
  // 휴대폰 게임 화면 연결
  // ---------------------------------------------------------------------------
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
        child: LiarsPokerPhoneGame(
          roomCode: roomCode,
          provider: provider,
          gameService: LiarsPokerService(),
          onExitRoom: onExitRoom,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 태블릿 게임 화면 연결
  // ---------------------------------------------------------------------------
  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) {
    return Builder(
      builder: (context) => CriticalNetworkGuard(
        provider: provider,
        exitLabel: '대기실로',
        onExit: () => Navigator.of(context).maybePop(),
        child: LiarsPokerTabletGame(
          playerLayout: playerLayout,
          provider: provider,
          roomCode: roomCode,
          gameService: LiarsPokerService(),
        ),
      ),
    );
  }
}
