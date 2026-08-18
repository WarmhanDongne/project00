import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

/// Liar's Poker 클라이언트 연출에서 직접 조절할 수 있는 시간값입니다.
///
/// 서버 턴 제한시간과 LIAR/FOLD 규칙은 Cloud Functions가 소유합니다. 아래 값을
/// 바꾸면 화면 연출 속도만 달라지며 서버 게임 판정 시간으로 사용하면 안 됩니다.
abstract final class LiarsPokerFlowTiming {
  /// 손패 공개 후 상단바와 조작부가 등장하는 시간입니다.
  static const phoneControlsEntry = Duration(milliseconds: 920);

  /// LIAR 판정 문구가 휴대폰 중앙에 유지되는 시간입니다.
  static const phoneVerdictAnnouncement = Duration(milliseconds: 2900);

  /// 판정 문구와 벌칙 프로필 화면 사이의 전환시간입니다.
  static const phonePenaltyStageSwitch = Duration(milliseconds: 540);

  /// 진행 화면과 관전 화면이 서로 페이드되는 시간입니다.
  ///
  /// 서버 상태 수신 때마다 재생하는 값이 아니라, 실제 화면 단계가 바뀔 때만
  /// 적용됩니다. 값을 늘리면 관전 화면의 등장·퇴장이 더 느리고 부드러워집니다.
  static const phoneSpectatorTransition = Duration(milliseconds: 420);

  /// 게임 화면 매트가 펼쳐지는 시간입니다.
  static const gameEntry = Duration(milliseconds: 900);

  /// 게임 화면 매트를 말아 로비로 돌아가는 시간입니다.
  static const gameExit = Duration(milliseconds: 820);

  /// 생존 플레이어 좌석으로 카드를 분배하는 총 시간입니다.
  static const cardDeal = Duration(milliseconds: 2800);

  /// ROUND N 안내 문구가 유지되는 시간입니다.
  static const roundAnnouncement = Duration(milliseconds: 1900);

  /// 라운드 테이블·잔여 카드·턴 표시가 등장하는 시간입니다.
  static const roundBoardReveal = Duration(milliseconds: 980);

  /// 공개된 카드와 판정을 확인한 뒤 벌칙 룰렛으로 넘어가기 전 유지시간입니다.
  static const revealedCardsHold = Duration(seconds: 3);

  /// 벌칙 룰렛이 나타나고 사라지는 AnimatedSwitcher 시간입니다.
  static const penaltySwitch = Duration(milliseconds: 720);

  /// 인원 부족 안내 후 태블릿 게임 화면을 닫기 전 대기시간입니다.
  static const closingRouteDelay = Duration(seconds: 1);
}

/// Liar's Poker 태블릿의 단계별 화면·문구·애니메이션 설정입니다.
GameFlowConfig<LiarsPokerTabletStage> buildLiarsPokerTabletFlowConfig({
  required int roundNumber,
}) {
  return GameFlowConfig<LiarsPokerTabletStage>(
    steps: {
      // ======================================================================
      // 1. 서버 데이터 연결 (WAITING)
      // ======================================================================
      // - status/phase: 첫 game/public 상태를 아직 받지 못한 시점
      // - 화면: 배경 + "게임을 준비하고 있습니다" 지속 문구
      // - Animation/Delay/Scrim: 없음
      // - 입력: 조작 화면 없음
      // - 다음 단계: 서버 dealing 또는 현재 phase 수신을 기다림
      LiarsPokerTabletStage.waiting: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.waiting,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'liars-poker-preparing',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.preparingGame,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 2. 카드 분배 (DEALING)
      // ======================================================================
      // - status/phase: 서버 phase == dealing
      // - 화면: 생존 좌석 기준 CardDealAnimation
      // - 1라운드: 중앙 덱 탭으로 시작 / 2라운드부터: ROUND N 후 자동 시작
      // - 문구: 2라운드부터 "ROUND N", roundAnnouncement 동안 표시
      // - 입력: 문구 중 차단, 첫 라운드에는 덱 탭만 허용
      // - 다음 단계: 완료 후 completeDealing callable, 서버 상태를 기다림
      LiarsPokerTabletStage.dealing: GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.dealing,
        showScreen: true,
        showAnnouncement: roundNumber > 1,
        announcementId: 'liars-poker-round-$roundNumber',
        announcementKind: GameAnnouncementKind.round,
        announcement: GameFlowCopy.round(roundNumber),
        announcementDuration: LiarsPokerFlowTiming.roundAnnouncement,
        animation: const GameFlowAnimationConfig(
          name: 'CardDealAnimation',
          duration: LiarsPokerFlowTiming.cardDeal,
        ),
        blocksInteraction: roundNumber > 1,
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 3. 라운드 보드 등장 (ROUND STARTING)
      // ======================================================================
      // - status/phase: 분배 완료 후 로컬 보드 공개 단계
      // - 화면: 테이블 랭크, 잔여 카드, 현재 턴 조명
      // - 문구/Scrim/Delay: 없음
      // - Animation: RoundStartReveal, roundBoardReveal 동안 재생
      // - 입력: 표시 전용 레이어라 포인터를 받지 않음
      // - 다음 단계: 완료 콜백이 로컬 stage만 playing으로 변경
      LiarsPokerTabletStage.roundStarting:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.roundStarting,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              name: 'RoundStartReveal',
              duration: LiarsPokerFlowTiming.roundBoardReveal,
            ),
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.clientPresentation,
          ),

      // ======================================================================
      // 4. 플레이 (PLAYING)
      // ======================================================================
      // - status/phase: 서버 playing 또는 lastCardChallenge
      // - 화면: 테이블, 잔여 카드, 턴 조명, 사이드바
      // - 단계 고정 문구/Animation/Delay/Scrim: 없음
      // - 입력: 휴대폰에서 제출/LIAR/FOLD 명령 가능
      // - 다음 단계: 서버 제출 이벤트, LIAR 판정 또는 다음 round를 기다림
      LiarsPokerTabletStage.playing: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.playing,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 5. 제출 카드 이동 (CARDS PLAYING)
      // ======================================================================
      // - status/event: 새 public cardPlayEvent 수신
      // - 화면: 제출 좌석에서 중앙 카드 더미로 카드 이동
      // - 문구/Scrim: 없음
      // - 다음 단계: 이동 완료 후 로컬 stage를 playing으로 복원
      LiarsPokerTabletStage.cardsPlaying:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.cardsPlaying,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              name: 'LiarsPokerTabletCardPlayAnimation',
              duration: Duration(milliseconds: 540),
            ),
            advancePolicy: GameFlowAdvancePolicy.clientPresentation,
          ),

      // ======================================================================
      // 6. LIAR 카드 공개 (CARDS REVEALING)
      // ======================================================================
      // - status/event: LIAR 판정과 실제 카드 랭크 수신
      // - 화면: 마지막 제출 카드를 뒤집어 진실/거짓 공개
      // - Animation: 카드 공개 0.9초, 이후 revealedCardsHold 동안 결과 유지
      // - 입력: 판정 확인 단계라 게임 명령을 제공하지 않음
      // - 다음 단계: 서버가 penalty면 룰렛, 아니면 playing
      LiarsPokerTabletStage.cardsRevealing:
          const GameFlowStep<LiarsPokerTabletStage>(
            stage: LiarsPokerTabletStage.cardsRevealing,
            showScreen: true,
            animation: GameFlowAnimationConfig(
              name: 'LiarsPokerTabletCardRevealAnimation',
              duration: Duration(milliseconds: 900),
            ),
            afterDelay: LiarsPokerFlowTiming.revealedCardsHold,
            blocksInteraction: true,
            advancePolicy: GameFlowAdvancePolicy.waitsForServer,
          ),

      // ======================================================================
      // 7. 벌칙 룰렛 (PENALTY)
      // ======================================================================
      // - status/phase: 서버 phase == penalty
      // - 화면: 기본 테이블을 숨기고 LiarsPokerTabletGamePenalty 표시
      // - Animation: penaltySwitch 시간으로 룰렛 진입/퇴장
      // - 입력: 태블릿 룰렛 입력만 허용
      // - 다음 단계: 룰렛 결과 callable 후 서버 dealing/result를 기다림
      LiarsPokerTabletStage.penalty: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.penalty,
        showScreen: true,
        animation: GameFlowAnimationConfig(
          name: 'PenaltyRouletteAnimatedSwitcher',
          duration: LiarsPokerFlowTiming.penaltySwitch,
        ),
        advancePolicy: GameFlowAdvancePolicy.clientCallbackThenServer,
      ),

      // ======================================================================
      // 8. 최종 결과 (RESULT)
      // ======================================================================
      // - status: 정상 승자가 확정된 finished
      // - 화면: 우승자 프로필, 다시하기, HOME
      // - 문구/Delay/Scrim: 결과 위젯 자체 연출 외에는 없음
      // - 다음 단계: restart/end callable의 서버 결과를 기다림
      LiarsPokerTabletStage.result: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.result,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 9. 게임 종료 안내 (FINISHED)
      // ======================================================================
      // - status: 결과 화면 이외의 종료 표현이 필요한 로컬 단계
      // - 화면: "게임이 종료되었습니다" 지속 문구
      // - Animation/Delay/Scrim: 없음
      // - 다음 단계: 상위 화면의 종료/라우트 처리를 기다림
      LiarsPokerTabletStage.finished: const GameFlowStep<LiarsPokerTabletStage>(
        stage: LiarsPokerTabletStage.finished,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'liars-poker-finished',
        announcementKind: GameAnnouncementKind.persistent,
        announcement: GameFlowCopy.gameFinished,
        animation: GameFlowAnimationConfig.disabled(),
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),
    },
  );
}
