import 'package:project00/games/_game_template/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

/// 새 게임의 클라이언트 연출 시간 예시입니다.
///
/// 서버 턴 제한시간은 이 클래스에 넣지 마세요. 화면에서 보이는 문구, 카드 이동,
/// 결과 유지시간처럼 서버 판정과 독립적인 값만 둡니다.
abstract final class TemplateFlowTiming {
  static const cardDeal = Duration(milliseconds: 2800);
  static const roundResult = Duration(milliseconds: 2400);
  static const penalty = Duration(milliseconds: 1800);
}

/// 새 태블릿 게임이 복사해서 시작할 단계별 표현 설정입니다.
///
/// 각 단계 주석에는 다음 내용을 남기세요.
/// - 대응 서버 status/phase와 게임 시점
/// - 표시 Screen/Widget과 문구
/// - 문구·Animation ON/OFF 및 Duration
/// - before/after Delay, 입력 차단, Scrim
/// - 다음 단계 조건과 서버/클라이언트 책임
GameFlowConfig<TemplateTabletStage> buildTemplateTabletFlowConfig({
  required int roundNumber,
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) {
  return GameFlowConfig<TemplateTabletStage>(
    steps: {
      // ======================================================================
      // 1. 서버 데이터 연결 (CONNECTING)
      // ======================================================================
      // - status/phase: 첫 공개 상태를 아직 받지 못함
      // - 화면: 배경과 준비 문구만 표시
      // - Animation/Delay/Scrim: 없음
      // - 다음 단계: 서버 상태 수신을 기다림
      TemplateTabletStage.connecting: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.connecting,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'template-preparing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.preparingGame,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 2. 카드 분배 (DEALING)
      // ======================================================================
      // - status/phase: 서버 phase == dealing
      // - 화면: CardDealAnimation
      // - 문구/Scrim/Delay: 게임 규칙에 맞춰 추가
      // - Animation: cardDeal 값으로 재생시간 조절
      // - 다음 단계: 완료 callable 후 서버 상태를 기다림
      TemplateTabletStage.dealing: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.dealing,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: 'CardDealAnimation',
          duration: TemplateFlowTiming.cardDeal,
        ),
        blocksInteraction: true,
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 3. 플레이 (PLAYING)
      // ======================================================================
      // - status/phase: 실제 턴 진행 상태
      // - 화면: 게임 보드와 플레이어 조작 UI
      // - 단계 고정 문구/Animation/Delay/Scrim: 없음
      // - 다음 단계: 서버의 행동·판정 상태를 기다림
      TemplateTabletStage.playing: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.playing,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 4. 라운드 판정 (ROUND RESULT)
      // ======================================================================
      // - status/phase: 서버 roundResult
      // - 화면: 제출 카드/점수/판정 결과
      // - Animation: roundResult 시간 동안 재생
      // - 입력: 판정 중 차단
      // - 다음 단계: 연출 완료 callable 후 서버 next round/result를 기다림
      TemplateTabletStage.roundResult: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.roundResult,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: 'TODO: RoundResultAnimation',
          duration: TemplateFlowTiming.roundResult,
        ),
        blocksInteraction: true,
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 5. 벌칙 (PENALTY)
      // ======================================================================
      // - status/phase: 서버 penalty
      // - 화면: 게임별 벌칙 Widget
      // - Animation: penalty 시간, 필요하면 Scrim 설정
      // - 다음 단계: 벌칙 결과 callable 후 서버 상태를 기다림
      TemplateTabletStage.penalty: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.penalty,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: 'TODO: PenaltyAnimation',
          duration: TemplateFlowTiming.penalty,
        ),
        blocksInteraction: true,
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 6. 최종 결과 (RESULT)
      // ======================================================================
      // - status: 정상 승자가 확정된 finished
      // - 화면: 승자와 다시하기/HOME
      // - 다음 단계: 사용자 명령과 서버 결과를 기다림
      TemplateTabletStage.result: const GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.result,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 7. 비정상 종료 (CLOSING)
      // ======================================================================
      // - status: 인원 부족 등 정상 승부가 아닌 finished
      // - 화면: 게임 UI를 숨기고 [closingMessage]를 Scrim 위에 지속 표시
      // - 다음 단계: 상위 라우트 종료 로직이 서버 상태를 확인해 처리
      TemplateTabletStage.closing: GameFlowStep<TemplateTabletStage>(
        stage: TemplateTabletStage.closing,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'template-closing-$roundNumber',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: closingMessage,
        animation: const GameFlowAnimationConfig.disabled(),
        blocksInteraction: true,
        showScrim: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),
    },
  );
}
