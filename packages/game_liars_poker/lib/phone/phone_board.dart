// [phone_board.dart] 라이어스 포커 휴대폰 화면의 진입부터 종료까지,
// 단계별 화면·문구·애니메이션·연출 시간을 조율하는 파일이다.
// 세부 UI는 phone/screens와 phone/widgets, 서버 상태는 shared에서 관리한다.

library;

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_kit/recovery/widgets/game_connection_led.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/core/layout/app_system_ui.dart';
import 'package:game_kit/game_feedback.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/animations/game_entry_unroll.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/game_recovery_layer.dart';
import 'package:game_kit/shared/widgets/game_route_exit.dart';
import 'package:game_kit/phone/widgets/result_dialog.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/phone/screens/game_screen.dart';
import 'package:game_liars_poker/phone/providers/game_stage.dart';
import 'package:game_liars_poker/phone/widgets/spectator.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/providers/session_provider.dart';
import 'package:game_liars_poker/shared/services/asset_preloader.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
// ============================================================

// LiarsPokerPhoneGame
// │
// ├─ ① Timing → 문구·전환·연출 시간
// ├─ ② Screens → 진행·관전·결과 화면
// ├─ ③ Announcement → 단계별 안내 문구
// └─ ④ board_state → 세션·재접속·종료 상태

part 'src/board_state.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

/// 화면 맨 아래 LED 연결 띠입니다(시안: 타이머와 같은 LED 전광판).
const liarsPokerConnectionLed = GameConnectionLedStyle.classic;

abstract final class LiarsPokerPhoneTiming {
  /// 휴대폰 ROUND N 문구 유지시간입니다. 태블릿 안내와 별도로 조절합니다.
  static const roundAnnouncement = Duration(milliseconds: 1900);

  /// GAME START 연출의 총 시간입니다.
  static const gameStartAnnouncement = Duration(milliseconds: 1700);

  /// 손패 공개 후 상단바와 조작부가 등장하는 시간입니다. 값이 클수록 진입이 느려집니다.
  static const phoneControlsEntry = Duration(milliseconds: 920);

  /// LIAR 판정 문구가 휴대폰 중앙에 유지되는 시간입니다.
  static const phoneVerdictAnnouncement = Duration(milliseconds: 2900);

  /// 판정 문구와 벌칙 프로필 화면 사이의 전환 시간입니다.
  static const phonePenaltyStageSwitch = Duration(milliseconds: 540);

  /// 진행 화면과 관전 화면이 서로 페이드되는 전환 시간입니다.
  static const phoneSpectatorTransition = Duration(milliseconds: 420);
}

/// 실제 화면 생성 함수입니다. 교체할 때 같은 입력을 받는 위젯/함수를 연결하세요.
/// GameFlowStep.screenWidget(Type)은 탐색용 설명이고, 이 생성 함수가 실제 화면을 만듭니다.
abstract final class LiarsPokerPhoneScreens {
  static const playing = LiarsPokerPhoneGameScreen.new;
  static const result = PhoneResultDialog.new;
  static const spectator = PhoneSpectator.new;
}

/// 라이어스 포커 휴대폰의 모든 화면 단계를 한곳에서 조절하는 설정입니다.
///
/// `phoneRegions`는 화면 영역의 표시 여부만 바꿉니다. 카드 제출 가능 여부,
/// LIAR/FOLD 조건과 승패는 Controller·Cloud Functions의 검사를 그대로 따릅니다.
GameFlowConfig<LiarsPokerPhoneStage> buildLiarsPokerPhoneFlowConfig({
  required int roundNumber,
  required String tableCardValue,
  String? statusMessage,
  String? waitingMessage,
  String? verdictMessage,
  String? lastPlayId,
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) => GameFlowConfig(
  steps: {
    LiarsPokerPhoneStage.connecting: const GameFlowStep(
      stage: LiarsPokerPhoneStage.connecting,
      description: '서버 공개 상태와 개인 손패를 기다린다',
      showScreen: false,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.gameStart: const GameFlowStep(
      stage: LiarsPokerPhoneStage.gameStart,
      description: '첫 손패가 준비된 뒤 게임 시작 문구를 표시한다',
      showScreen: true,
      showAnnouncement: true,
      announcementId: 'game-start',
      announcementKind: GameAnnouncementKind.gameStart,
      announcement: GameFlowCopy.gameStart,
      announcementDuration: LiarsPokerPhoneTiming.gameStartAnnouncement,
      animation: GameFlowAnimationConfig(
        name: 'GameStartAnimation',
        duration: LiarsPokerPhoneTiming.gameStartAnnouncement,
      ),
      blocksInteraction: true,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    LiarsPokerPhoneStage.dealing: const GameFlowStep(
      stage: LiarsPokerPhoneStage.dealing,
      description: '태블릿 카드 분배 완료와 새 개인 손패를 기다린다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.roundIntro: GameFlowStep(
      stage: LiarsPokerPhoneStage.roundIntro,
      description: '새 라운드 번호를 표시한다',
      showScreen: true,
      showAnnouncement: true,
      announcementId: 'phone-round-$roundNumber',
      announcementKind: GameAnnouncementKind.round,
      announcement: GameFlowCopy.round(roundNumber),
      announcementDuration: LiarsPokerPhoneTiming.roundAnnouncement,
      animation: const GameFlowAnimationConfig(
        name: 'FadeHoldFade',
        duration: LiarsPokerPhoneTiming.roundAnnouncement,
      ),
      blocksInteraction: true,
      phoneRegions: const PhoneGameRegions(showHand: true),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    LiarsPokerPhoneStage.tableIntro: GameFlowStep(
      stage: LiarsPokerPhoneStage.tableIntro,
      description: '이번 라운드의 기준 카드 값을 표시한다',
      showScreen: true,
      showAnnouncement: true,
      announcementId: 'phone-table-$roundNumber-$tableCardValue',
      announcement: LiarsPokerCopy.table(tableCardValue),
      blocksInteraction: true,
      phoneRegions: const PhoneGameRegions(showHand: true),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    LiarsPokerPhoneStage.handReveal: const GameFlowStep(
      stage: LiarsPokerPhoneStage.handReveal,
      description: '새 손패를 받아 펼친다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showHand: true),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    LiarsPokerPhoneStage.playing: GameFlowStep(
      stage: LiarsPokerPhoneStage.playing,
      description: '카드를 선택·제출하거나 LIAR를 선언한다',
      showScreen: true,
      showAnnouncement: waitingMessage != null || statusMessage != null,
      announcementId: waitingMessage != null
          ? 'waiting-$roundNumber-$lastPlayId-$waitingMessage'
          : statusMessage == null
          ? null
          : 'status-$statusMessage',
      announcementKind: waitingMessage == null
          ? GameAnnouncementKind.persistent
          : GameAnnouncementKind.transient,
      announcement: waitingMessage ?? statusMessage,
      phoneRegions: const PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.lastCardChallenge: const GameFlowStep(
      stage: LiarsPokerPhoneStage.lastCardChallenge,
      description: '마지막 잔여카드 보유자가 LIAR 또는 FOLD를 선택한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(
        showTopBar: true,
        showHand: true,
        showTimer: true,
        showActions: true,
      ),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.verdict: GameFlowStep(
      stage: LiarsPokerPhoneStage.verdict,
      description: '직전 LIAR 선언의 진실·거짓 판정을 표시한다',
      showScreen: true,
      showAnnouncement: verdictMessage != null,
      announcementId: verdictMessage == null
          ? null
          : 'verdict-$lastPlayId-$verdictMessage',
      announcement: verdictMessage,
      announcementTone: verdictMessage == null
          ? GameAnnouncementTone.neutral
          : LiarsPokerCopy.verdictTone(verdictMessage),
      announcementDuration: LiarsPokerPhoneTiming.phoneVerdictAnnouncement,
      blocksInteraction: true,
      phoneRegions: const PhoneGameRegions(showTopBar: true, showHand: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.penalty: const GameFlowStep(
      stage: LiarsPokerPhoneStage.penalty,
      description: '벌칙 대상과 벌칙 결과를 표시한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.spectator: const GameFlowStep(
      stage: LiarsPokerPhoneStage.spectator,
      description: '탈락 후 생존 플레이어를 관전한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.result: const GameFlowStep(
      stage: LiarsPokerPhoneStage.result,
      description: '최종 승자를 표시한다',
      showScreen: true,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    LiarsPokerPhoneStage.closing: GameFlowStep(
      stage: LiarsPokerPhoneStage.closing,
      description: '승부 없이 종료한다',
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

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class LiarsPokerPhoneGame extends ConsumerStatefulWidget {
  const LiarsPokerPhoneGame({
    super.key,
    required this.roomCode,
    required this.provider,
    required this.gameService,
    required this.onExitRoom,
  });

  final String roomCode;
  final GameRoomContext provider;
  final LiarsPokerService gameService;
  final Future<bool> Function() onExitRoom;

  @override
  ConsumerState<LiarsPokerPhoneGame> createState() =>
      _LiarsPokerPhoneGameState();
}
