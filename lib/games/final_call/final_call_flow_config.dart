import 'package:project00/games/final_call/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

/// Final Call 화면 연출에서 직접 조절할 수 있는 시간값입니다.
///
/// 서버의 턴 제한시간이나 게임 규칙 시간은 이 클래스에 두지 않습니다. 아래 값은
/// 카드 이동·공개 및 화면 전환 속도만 바꾸며 승패 계산에는 영향을 주지 않습니다.
abstract final class FinalCallFlowTiming {
  /// CALL 선언자를 휴대폰 화면에 강조해서 보여주는 시간입니다.
  static const callNotice = Duration(milliseconds: 4200);

  /// 선택한 손패 카드가 교체되기 전에 빠지는 로컬 연출 시간입니다.
  static const phoneCardReplace = Duration(milliseconds: 460);

  /// 중앙 덱에서 생존 좌석으로 카드가 분배되는 총 시간입니다.
  static const cardDeal = Duration(milliseconds: 2800);

  /// 라운드 결과 공개를 마친 뒤 `nextRound` 명령 전까지 결과를 유지하는 시간입니다.
  static const roundResultAfterDelay = Duration(milliseconds: 900);

  /// 인원 부족 종료 문구를 보여준 뒤 태블릿 게임 화면을 닫기 전 대기시간입니다.
  static const closingRouteDelay = Duration(seconds: 1);

  /// 결과 카드가 움직이기 전 모든 뒷면 카드를 확인하는 시간입니다.
  static const roundResultInitialHold = Duration(milliseconds: 900);

  /// 공개할 한 플레이어의 손패를 확대하는 시간입니다.
  static const roundResultFocus = Duration(milliseconds: 520);

  /// 한 장씩 공개할 때 다음 카드까지의 간격입니다.
  static const roundResultCardStep = Duration(milliseconds: 900);

  /// 카드 한 장의 뒤집기 애니메이션 시간입니다.
  static const roundResultCardFlip = Duration(milliseconds: 680);

  /// 한 플레이어의 손패 공개 후 원래 크기로 돌아오는 시간입니다.
  static const roundResultSettle = Duration(milliseconds: 520);

  /// 패배 플레이어의 하트가 깨지는 연출 시간입니다.
  static const roundResultHeartLoss = Duration(milliseconds: 1500);
}

/// Final Call 태블릿의 서버 상태를 화면 표현 설정으로 변환합니다.
///
/// `FinalCallTabletGame._resolveStage`가 서버 상태를 typed stage로 번역하고,
/// 이 설정은 해당 stage에서 무엇을 보여줄지만 결정합니다.
GameFlowConfig<FinalCallTabletStage> buildFinalCallTabletFlowConfig({
  required String closingMessage,
}) {
  return GameFlowConfig<FinalCallTabletStage>(
    steps: {
      // ======================================================================
      // 1. 서버 데이터 연결 (CONNECTING)
      // ======================================================================
      // - status/phase: 첫 public game 상태를 아직 받지 못한 시점
      // - 화면: 배경 + "게임을 준비하고 있습니다" 문구
      // - 문구: persistent라 시간 제한 없이 서버 상태가 올 때까지 유지
      // - Animation/Delay/Scrim: 없음
      // - 입력: 게임 Screen을 그리지 않아 조작할 수 없음
      // - 다음 단계: 서버 phase 수신을 기다림
      FinalCallTabletStage.connecting: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.connecting,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'final-call-preparing',
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
      // - 문구/Scrim/Delay: 없음
      // - Animation: cardDeal 시간 동안 생존 좌석에만 카드 분배
      // - 입력: 첫 라운드는 중앙 덱 탭, 2라운드부터 자동 시작
      // - 다음 단계: 애니메이션 완료 후 completeDealing callable을 보내고
      //   서버가 다음 phase를 확정할 때까지 기다림
      FinalCallTabletStage.dealing: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.dealing,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: 'CardDealAnimation',
          duration: FinalCallFlowTiming.cardDeal,
        ),
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 3. 플레이 (PLAYING)
      // ======================================================================
      // - status/phase: draw, callerSubmit, finalTurns, finalSubmit 등 진행 상태
      // - 화면: 중앙 카드, 팀별 하트, CALL/버림 애니메이션, 공용 사이드바
      // - 단계 고정 문구/Delay/Scrim: 없음
      // - 입력: 휴대폰 명령을 허용하며 태블릿은 서버 상태를 표현
      // - 다음 단계: 서버 phase 또는 roundResult 수신
      FinalCallTabletStage.playing: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.playing,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 4. 라운드 판정 (ROUND RESULT)
      // ======================================================================
      // - status/phase: roundResult 데이터가 존재하거나 phase == roundResult
      // - 화면: 전원 제출 카드 순차 공개, 점수 계산, 패배 팀 하트 소멸
      // - 문구/Scrim: 없음
      // - Animation: 플레이어·카드 수에 따라 총 시간이 달라지는 OneShotTimeline
      // - 종료 후 Delay: roundResultAfterDelay 뒤 nextRound callable 전송
      // - 입력: 결과 확인 단계라 게임 행동을 제공하지 않음
      // - 다음 단계: 연출 완료 후 서버가 next round 또는 finished를 확정
      FinalCallTabletStage.roundResult:
          const GameFlowStep<FinalCallTabletStage>(
            stage: FinalCallTabletStage.roundResult,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              name: 'FinalCallRoundResultTimeline',
              // 실제 총 시간은 공개 플레이어·카드 수에 따라 동적으로 계산됩니다.
              duration: Duration.zero,
            ),
            afterDelay: FinalCallFlowTiming.roundResultAfterDelay,
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
          ),

      // ======================================================================
      // 5. 최종 결과 (RESULT)
      // ======================================================================
      // - status: 정상 승자 또는 무승부가 확정된 finished
      // - 화면: FinalCallResultOverlay(승리 팀, 닉네임, 다시하기, HOME)
      // - 문구/Animation/Delay/Scrim: 결과 위젯 자체 연출 외에는 없음
      // - 입력: 다시하기·HOME 허용, 각 버튼의 callable 결과를 기다림
      FinalCallTabletStage.result: const GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.result,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 6. 인원 부족 종료 (CLOSING)
      // ======================================================================
      // - status: insufficientPlayers/interruptionVoteExpired로 끝난 finished
      // - 화면: 게임 Screen을 숨기고 [closingMessage]만 표시
      // - 문구: persistent, 별도 유지시간 없이 라우트 종료까지 유지
      // - Scrim: ON, 사용자 게임 입력 없음
      // - 다음 단계: closingRouteDelay 후 태블릿 게임 라우트를 닫음
      FinalCallTabletStage.closing: GameFlowStep<FinalCallTabletStage>(
        stage: FinalCallTabletStage.closing,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'final-call-closing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: closingMessage,
        animation: const GameFlowAnimationConfig.disabled(),
        afterDelay: FinalCallFlowTiming.closingRouteDelay,
        blocksInteraction: true,
        showScrim: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),
    },
  );
}
