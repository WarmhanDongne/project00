/// Mafia 휴대폰 조율판.
///
/// 이 파일에서 단계별 화면 연결, 문구, 애니메이션과 연출 시간을 수정합니다.
/// 세부 화면은 screens/, 세부 연출은 animations/를 열어 수정하세요.
/// 서버 상태 구독과 게임 명령은 shared/providers와 shared/services가 소유합니다.
/// 실제 턴 제한시간·승패 규칙은 서버가 결정하며 연출 시간과 구분합니다.
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/game_flow/leave_failure_notice.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:game_kit/widgets/game_request_notice.dart';
import 'package:game_kit/widgets/game_connecting_overlay.dart';
import 'package:game_mafia/shared/models/presentation_timing.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/widgets/game_interruption_layer.dart';
import 'package:game_kit/widgets/game_route_exit.dart';
import 'package:game_kit/widgets/phone_exit_modal.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/phone/providers/game_stage.dart';
import 'package:game_mafia/phone/screens/game_screen.dart';
import 'package:game_mafia/phone/widgets/game_layout.dart';
import 'package:game_mafia/phone/widgets/result_sequence.dart';
import 'package:game_mafia/phone/widgets/top_bar.dart';
import 'package:game_mafia/shared/models/game_state.dart';
import 'package:game_mafia/shared/providers/game_controller.dart';
import 'package:game_mafia/shared/providers/session_provider.dart';
import 'package:game_mafia/shared/services/asset_preloader.dart';
import 'package:game_mafia/shared/services/game_service.dart';

part 'src/board_state.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

/// 마피아 휴대폰의 모든 화면 단계와 표시 영역입니다.
///
/// 역할 확인·밤·아침·낮·투표·처형의 실제 규칙은 서버와 Controller가 결정합니다.
/// 여기서는 각 단계에서 상단바·타이머·조작 영역을 보여 줄지만 수정합니다.
GameFlowConfig<MafiaPhoneStage> buildMafiaPhoneFlowConfig({
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) => GameFlowConfig(
  steps: {
    MafiaPhoneStage.connecting: const GameFlowStep(
      stage: MafiaPhoneStage.connecting,
      description: '서버 데이터 연결',
      showScreen: false,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.roleReveal: const GameFlowStep(
      stage: MafiaPhoneStage.roleReveal,
      description: '내 역할 카드를 확인한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.night: const GameFlowStep(
      stage: MafiaPhoneStage.night,
      description: '밤 역할 행동을 선택하고 제출한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.morning: const GameFlowStep(
      stage: MafiaPhoneStage.morning,
      description: '밤 결과와 아침 발표를 확인한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.day: const GameFlowStep(
      stage: MafiaPhoneStage.day,
      description: '낮 토론과 토론 종료 투표를 진행한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.voting: const GameFlowStep(
      stage: MafiaPhoneStage.voting,
      description: '처형 대상에게 투표한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.voteResult: const GameFlowStep(
      stage: MafiaPhoneStage.voteResult,
      description: '처형 결과와 공개 역할을 확인한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.spectator: const GameFlowStep(
      stage: MafiaPhoneStage.spectator,
      description: '탈락 후 생존자와 공개 역할을 관전한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.result: const GameFlowStep(
      stage: MafiaPhoneStage.result,
      description: '최종 결과',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    MafiaPhoneStage.closing: GameFlowStep(
      stage: MafiaPhoneStage.closing,
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
abstract final class MafiaPhoneScreens {
  static const playing = MafiaPhoneGameScreen.new;
  static const result = MafiaPhoneResultSequence.new;
}

/// 휴대폰 전용 연출 시간입니다. 서버 토론/밤 제한시간은 여기에 두지 않습니다.
abstract final class MafiaPhoneTiming {
  static const executionAnnouncement = MafiaPresentationTiming.executionName;
  static const closingRouteDelay = MafiaPresentationTiming.closing;
  static const backgroundTransition = Duration(milliseconds: 400);
}

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class MafiaPhoneGame extends ConsumerStatefulWidget {
  const MafiaPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final GameRoomContext provider;
  final MafiaService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<MafiaPhoneGame> createState() => _MafiaPhoneGameState();
}
