/// Template 휴대폰 조율판.
///
/// 이 파일에서 단계별 화면 연결, 문구, 애니메이션과 연출 시간을 수정합니다.
/// 세부 화면은 screens/, 세부 연출은 animations/를 열어 수정하세요.
/// 서버 상태 구독과 게임 명령은 shared/providers와 shared/services가 소유합니다.
/// 실제 턴 제한시간·승패 규칙은 서버가 결정하며 연출 시간과 구분합니다.
library;

import 'package:flutter/material.dart';
import 'package:game_kit/game_flow/game_announcement.dart';
import 'package:game_kit/game_flow/game_flow_config.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/game_flow/phone_game_shell.dart';
import 'package:game_template/phone/providers/game_stage.dart';

part 'src/board_state.dart';

// ============================================================================
// 화면 흐름·연출 설정
// ============================================================================

/// 표시 시간만 조절합니다. 서버의 round/phase/마감은 바꾸지 않습니다.
abstract final class TemplatePhoneAnnouncements {
  static const startDuration = Duration(milliseconds: 1700);
  static const roundDuration = Duration(milliseconds: 1900);
}

/// 연결 → 시작 안내 → 라운드 안내 → 플레이 → 결과/종료.
/// 마피아는 시작/라운드 안내를 건너뛰며 역할·밤·낮 안내는 진행 화면이 담당합니다.
/// showScreen은 같은 화면 인스턴스를 유지하면서 표시만 제어합니다.
/// 문구를 끄더라도 셸의 완료 콜백으로 다음 로컬 단계가 열립니다.
GameFlowConfig<TemplatePhoneStage> buildTemplatePhoneFlowConfig({
  required int roundNumber,
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) => GameFlowConfig(
  steps: {
    // 1. 첫 서버 상태 대기: 배경만 표시. 서버가 준비될 때까지 기다립니다.
    TemplatePhoneStage.connecting: const GameFlowStep(
      stage: TemplatePhoneStage.connecting,
      description: '서버 데이터 연결',
      showScreen: false,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 2. GAME START: 문구/연출 ON/OFF와 시간을 아래에서 조절합니다.
    // 입력 차단, Scrim 없음. 완료 콜백은 로컬 안내 완료값만 바꿉니다.
    TemplatePhoneStage.gameStart: const GameFlowStep(
      stage: TemplatePhoneStage.gameStart,
      description: '게임 시작 안내',
      showScreen: false,
      showAnnouncement: true,
      announcementId: 'game-start',
      announcementKind: GameAnnouncementKind.gameStart,
      announcement: GameFlowCopy.gameStart,
      announcementDuration: TemplatePhoneAnnouncements.startDuration,
      animation: GameFlowAnimationConfig(
        name: 'GameStartAnimation',
        duration: TemplatePhoneAnnouncements.startDuration,
      ),
      blocksInteraction: true,
      phoneRegions: PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    // 3. 새 라운드: 서버 분배 완료와 새 손패를 확인한 뒤 표시합니다.
    // 안내시간이 길면 조작 화면이 늦게 열립니다. 서버 round는 변경하지 않습니다.
    TemplatePhoneStage.roundIntro: GameFlowStep(
      stage: TemplatePhoneStage.roundIntro,
      description: '라운드 시작 안내',
      showScreen: false,
      showAnnouncement: true,
      announcementId: 'round-$roundNumber',
      announcementKind: GameAnnouncementKind.round,
      announcement: GameFlowCopy.round(roundNumber),
      announcementDuration: TemplatePhoneAnnouncements.roundDuration,
      animation: const GameFlowAnimationConfig(
        name: 'FadeHoldFade',
        duration: TemplatePhoneAnnouncements.roundDuration,
      ),
      blocksInteraction: true,
      phoneRegions: const PhoneGameRegions(),
      advancePolicy: GameFlowAdvancePolicy.clientPresentation,
    ),
    // 4. 손패·조작/관전: 실제 화면 연결은 아래 Screens의 생성 함수를 사용합니다.
    TemplatePhoneStage.playing: const GameFlowStep(
      stage: TemplatePhoneStage.playing,
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
    // 5. 서버가 정상 승부를 확정하고 필요한 공개 연출을 마친 뒤 표시합니다.
    TemplatePhoneStage.result: const GameFlowStep(
      stage: TemplatePhoneStage.result,
      description: '최종 결과',
      showScreen: true,
      phoneRegions: PhoneGameRegions(showTopBar: true),
      advancePolicy: GameFlowAdvancePolicy.waitsForServer,
    ),
    // 6. 수동 종료·인원 부족: Scrim 위 문구. 라우트 종료는 서버 상태를 따릅니다.
    TemplatePhoneStage.closing: GameFlowStep(
      stage: TemplatePhoneStage.closing,
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

// ============================================================================
// 게임 화면 진입점
// ============================================================================

class TemplatePhoneGame extends StatefulWidget {
  const TemplatePhoneGame({
    super.key,
    required this.roomCode,
    required this.onExitRoom,
  });

  final String roomCode;
  final Future<bool> Function() onExitRoom;

  @override
  State<TemplatePhoneGame> createState() => _TemplatePhoneGameState();
}
