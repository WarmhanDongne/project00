/// FinalCall 휴대폰 조율판.
///
/// 이 파일에서 단계별 화면 연결, 문구, 애니메이션과 연출 시간을 수정합니다.
/// 세부 화면은 screens/, 세부 연출은 animations/를 열어 수정하세요.
/// 서버 상태 구독과 게임 명령은 shared/providers와 shared/services가 소유합니다.
/// 실제 턴 제한시간·승패 규칙은 서버가 결정하며 연출 시간과 구분합니다.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_kit/recovery/widgets/game_connection_led.dart';
import 'package:flutter/material.dart';
import 'package:game_final_call/game_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_final_call/game_assets.dart';
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_final_call/phone/providers/game_stage.dart';
import 'package:game_final_call/phone/screens/game_screen.dart';
import 'package:game_final_call/phone/widgets/top_bar.dart';
import 'package:game_final_call/phone/widgets/spectator_view.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/providers/game_controller.dart';
import 'package:game_final_call/shared/providers/session_provider.dart';
import 'package:game_final_call/shared/services/asset_preloader.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_final_call/shared/widgets/party_pop.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:game_kit/game_feedback.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/errors/widgets/leave_failure_notice.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/phone/widgets/exit_modal.dart';
import 'package:game_kit/phone/widgets/result_dialog.dart';

part 'src/board_state.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

/// 화면 맨 아래 LED 연결 띠입니다(시안: 게임 남색 잉크 바탕, 숫자는 카드의
/// 빨강·노랑·초록).
const finalCallConnectionLed = GameConnectionLedStyle(
  background: FinalCallColors.ink,
  topLineColor: Color(0x33FFFFFF),
  offColor: FinalCallColors.red,
  retryColor: FinalCallColors.yellow,
  onColor: FinalCallColors.green,
  textColor: Colors.white,
);

abstract final class FinalCallPhoneTiming {
  /// 손패를 처음 받아 펼치는 총 재생시간입니다.
  static const cardReceive = Duration(milliseconds: 2300);

  /// 손패 공개 후 조작부 등장 시간입니다.
  static const controlsEntry = Duration(milliseconds: 920);

  /// CALL 선언자를 휴대폰 화면에 강조해서 보여주는 시간입니다.
  static const callNotice = Duration(milliseconds: 4200);

  /// 선택한 손패 카드가 교체되기 전에 빠지는 로컬 연출 시간입니다.
  static const phoneCardReplace = Duration(milliseconds: 460);
}

/// 표시 시간만 조절합니다. 서버의 round/phase/마감은 바꾸지 않습니다.
abstract final class FinalCallPhoneAnnouncements {
  static const startDuration = Duration(milliseconds: 1700);
  static const roundDuration = Duration(milliseconds: 1900);
}

/// 연결 → 시작 안내 → 라운드 안내 → 플레이 → 결과/종료.
/// showScreen은 같은 화면 인스턴스를 유지하면서 표시만 제어합니다.
/// 문구를 끄더라도 셸의 완료 콜백으로 다음 로컬 단계가 열립니다.
GameFlowConfig<FinalCallPhoneStage> buildFinalCallPhoneFlowConfig({
  required int roundNumber,
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) => GameFlowConfig(
  steps: {
    // 1. 첫 서버 상태 대기: 배경만 표시. 서버가 준비될 때까지 기다립니다.
    FinalCallPhoneStage.connecting: const GameFlowStep(
      stage: FinalCallPhoneStage.connecting,
      description: '서버 데이터 연결',
      showScreen: false,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 카드 분배는 태블릿 연출과 새 private 손패를 기다립니다.
    FinalCallPhoneStage.dealing: const GameFlowStep(
      stage: FinalCallPhoneStage.dealing,
      description: '태블릿 카드 분배와 새 손패를 기다린다',
      showScreen: false,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 2. GAME START: 문구/연출 ON/OFF와 시간을 아래에서 조절합니다.
    // 입력 차단, Scrim 없음. 완료 콜백은 로컬 안내 완료값만 바꿉니다.
    FinalCallPhoneStage.gameStart: const GameFlowStep(
      stage: FinalCallPhoneStage.gameStart,
      description: '게임 시작 안내',
      showScreen: false,
      showAnnouncement: true,
      announcementId: 'game-start',
      announcementKind: GameAnnouncementKind.gameStart,
      announcement: GameFlowCopy.gameStart,
      announcementDuration: FinalCallPhoneAnnouncements.startDuration,
      animation: GameFlowAnimationConfig(
        name: 'GameStartAnimation',
        duration: FinalCallPhoneAnnouncements.startDuration,
      ),
      blocksInteraction: true,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    // 3. 새 라운드: 서버 분배 완료와 새 손패를 확인한 뒤 표시합니다.
    // 안내시간이 길면 조작 화면이 늦게 열립니다. 서버 round는 변경하지 않습니다.
    FinalCallPhoneStage.roundIntro: GameFlowStep(
      stage: FinalCallPhoneStage.roundIntro,
      description: '라운드 시작 안내',
      showScreen: false,
      showAnnouncement: true,
      announcementId: 'round-$roundNumber',
      announcementKind: GameAnnouncementKind.round,
      announcement: GameFlowCopy.round(roundNumber),
      announcementDuration: FinalCallPhoneAnnouncements.roundDuration,
      animation: const GameFlowAnimationConfig(
        name: 'FadeHoldFade',
        duration: FinalCallPhoneAnnouncements.roundDuration,
      ),
      blocksInteraction: true,
      phoneRegions: const PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    // 손패 카드팩을 펼치는 동안에는 손패만 표시하고 상단 조작부는 감춥니다.
    FinalCallPhoneStage.handReveal: const GameFlowStep(
      stage: FinalCallPhoneStage.handReveal,
      description: '새 손패를 받아 펼친다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showHand: true),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    // 4. 손패·조작: 실제 화면 연결은 아래 Screens의 생성 함수를 사용합니다.
    FinalCallPhoneStage.playing: const GameFlowStep(
      stage: FinalCallPhoneStage.playing,
      description: '게임 진행 및 판정 대기',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    FinalCallPhoneStage.spectating: const GameFlowStep(
      stage: FinalCallPhoneStage.spectating,
      description: '탈락한 팀은 최종 승부까지 관전한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    FinalCallPhoneStage.finalSelection: const GameFlowStep(
      stage: FinalCallPhoneStage.finalSelection,
      description: '최종 점수에 사용할 카드를 선택한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    FinalCallPhoneStage.roundResultWaiting: const GameFlowStep(
      stage: FinalCallPhoneStage.roundResultWaiting,
      description: '태블릿의 마지막 카드 공개와 결과 연출을 기다린다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 5. 서버가 정상 승부를 확정하고 필요한 공개 연출을 마친 뒤 표시합니다.
    FinalCallPhoneStage.result: const GameFlowStep(
      stage: FinalCallPhoneStage.result,
      description: '최종 결과',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 6. 수동 종료·인원 부족: Scrim 위 문구. 라우트 종료는 서버 상태를 따릅니다.
    FinalCallPhoneStage.closing: GameFlowStep(
      stage: FinalCallPhoneStage.closing,
      description: '승부 없이 종료',
      showScreen: false,
      showAnnouncement: true,
      announcementId: 'closing',
      announcementKind: GameAnnouncementKind.persistent,
      announcement: closingMessage,
      blocksInteraction: true,
      showScrim: true,
      phoneRegions: const PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
  },
);

/// 실제 화면 생성 함수입니다. 교체할 때 같은 입력을 받는 위젯/함수를 연결하세요.
/// GameFlowStep.screenWidget(Type)은 탐색용 설명이고, 이 생성 함수가 실제 화면을 만듭니다.
abstract final class FinalCallPhoneScreens {
  static const playing = FinalCallPhoneGameScreen.new;
  static const result = PhoneResultDialog.new;
}

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class FinalCallPhoneGame extends ConsumerStatefulWidget {
  const FinalCallPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final GameRoomContext provider;
  final FinalCallService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<FinalCallPhoneGame> createState() => _FinalCallPhoneGameState();
}
