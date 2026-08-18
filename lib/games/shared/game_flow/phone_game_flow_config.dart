import 'package:project00/games/shared/game_flow/game_announcement.dart';
import 'package:project00/games/shared/game_flow/game_flow_config.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';

/// 공용 휴대폰 게임 흐름의 클라이언트 연출 시간입니다.
///
/// 서버 턴 제한시간은 이 클래스에 넣지 않습니다. 아래 값을 바꾸면 안내 문구와
/// 공용 상단바가 나타나는 속도만 달라집니다.
abstract final class PhoneGameFlowTiming {
  static const gameStartAnnouncement = Duration(milliseconds: 1700);
  static const roundAnnouncement = Duration(milliseconds: 1900);
  static const controlsEntry = Duration(milliseconds: 920);
}

/// 공용 휴대폰 셸의 단계별 표현 설정을 만듭니다.
///
/// 이 함수의 값은 문구와 클라이언트 연출만 바꿉니다. 서버 `status`/`phase`, 턴,
/// 승패에는 영향을 주지 않습니다. 새 게임은 이 기본값을 그대로 사용하고 게임별로
/// 다른 문구나 시간이 필요한 경우에만 [PhoneGameShell.flowConfig]를 교체하세요.
GameFlowConfig<GameScreenPhase> buildPhoneGameFlowConfig({
  required int roundNumber,
  String closingMessage = GameFlowCopy.insufficientPlayers,
}) {
  return GameFlowConfig<GameScreenPhase>(
    steps: {
      // ======================================================================
      // 1. 서버 데이터 연결 (CONNECTING)
      // ======================================================================
      //
      // 시점/status:
      // - 게임 진입 직후 첫 공개 상태 또는 개인 손패가 아직 도착하지 않은 시점
      //
      // 화면/문구/연출:
      // - 배경만 표시하고 게임 Screen, 상단바, 안내 문구는 표시하지 않음
      // - 별도 Animation, Delay, Scrim 없음
      //
      // 입력/전환:
      // - 아직 조작할 게임 UI가 없으므로 입력 대상도 없음
      // - 클라이언트 타이머로 진행하지 않고 서버 상태 수신을 기다림
      GameScreenPhase.connecting: const GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.connecting,
        showScreen: false,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 2. 게임 시작 안내 (INTRO)
      // ======================================================================
      //
      // 시점/status:
      // - 첫 서버 상태가 준비됐지만 로컬 GAME START 연출은 아직 끝나지 않은 시점
      //
      // 화면:
      // - PhoneGameShell 배경 위에 GameAnnouncementLayer만 표시
      //
      // 안내 문구:
      // - showAnnouncement로 ON/OFF
      // - GameFlowCopy.gameStart의 "GAME START"를 1.7초 표시
      //
      // 애니메이션:
      // - animation.enabled로 PhoneGameStartAnimation ON/OFF
      // - animation.duration과 announcementDuration은 같은 1.7초로 유지
      // - 시간을 늘리면 GAME START가 사라지고 게임 화면이 열리는 시점이 늦어짐
      //
      // 입력/Scrim/전환:
      // - 게임 Screen을 숨겨 입력을 차단하고 Scrim은 사용하지 않음
      // - 연출 완료 콜백이 로컬 intro 완료값만 변경함. 서버 상태는 변경하지 않음
      GameScreenPhase.intro: const GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.intro,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'game-start',
        announcementKind: GameAnnouncementKind.gameStart,
        announcement: GameFlowCopy.gameStart,
        announcementDuration: PhoneGameFlowTiming.gameStartAnnouncement,
        animation: GameFlowAnimationConfig(
          name: 'PhoneGameStartAnimation',
          duration: PhoneGameFlowTiming.gameStartAnnouncement,
        ),
        blocksInteraction: true,
        showScrim: false,
        advancePolicy: GameFlowAdvancePolicy.clientPresentation,
      ),

      // ======================================================================
      // 3. 라운드 시작 안내 (ROUND INTRO)
      // ======================================================================
      //
      // 시점/status:
      // - 서버 round가 바뀌었지만 해당 라운드 안내를 아직 표시하지 않은 시점
      //
      // 화면/문구:
      // - 게임 Screen을 잠시 숨기고 "ROUND N"을 1.9초 표시
      // - showAnnouncement와 announcementDuration으로 ON/OFF·유지시간 조절
      //
      // 애니메이션:
      // - FadeHoldFade를 1.9초 재생. enabled=false면 정적 문구만 같은 시간 표시
      // - 시간을 늘리면 새 라운드 조작 화면이 열리는 시점이 늦어짐
      //
      // 입력/Scrim/전환:
      // - 게임 Screen을 숨겨 입력을 차단하며 Scrim은 없음
      // - 완료 후 로컬 announcedRound만 갱신하고 서버 round는 변경하지 않음
      GameScreenPhase.roundIntro: GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.roundIntro,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'round-$roundNumber',
        announcementKind: GameAnnouncementKind.round,
        announcement: GameFlowCopy.round(roundNumber),
        announcementDuration: PhoneGameFlowTiming.roundAnnouncement,
        animation: const GameFlowAnimationConfig(
          name: 'FadeHoldFade',
          duration: PhoneGameFlowTiming.roundAnnouncement,
        ),
        blocksInteraction: true,
        showScrim: false,
        advancePolicy: GameFlowAdvancePolicy.clientPresentation,
      ),

      // ======================================================================
      // 4. 게임 진행 (PLAYING)
      // ======================================================================
      //
      // 시점/status:
      // - 카드 분배, 플레이어 행동, 판정 대기 등 실제 게임이 진행되는 전체 구간
      //
      // 화면/문구/연출:
      // - 게임별 content와 공용 topBar 표시
      // - 단계 자체의 문구, Animation, Delay, Scrim 없음
      //
      // 입력/전환:
      // - 사용자 입력 허용. 손패가 비어 contentReady=false여도 topBar는 유지
      // - 다음 단계는 서버 상태 또는 게임별 로컬 공개 완료값을 다시 번역해 결정
      GameScreenPhase.playing: const GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.playing,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 5. 최종 결과 (RESULT)
      // ======================================================================
      //
      // 시점/status:
      // - 서버가 정상 승자와 finished 상태를 확정한 뒤 결과 공개가 준비된 시점
      //
      // 화면/문구/연출:
      // - 게임별 result Widget과 topBar 표시
      // - 결과 위젯 자체 연출 외에 셸 문구, Delay, Scrim 없음
      //
      // 입력/전환:
      // - 다시하기/나가기 입력 허용
      // - 서버의 restart 또는 close 결과를 기다림
      GameScreenPhase.result: const GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.result,
        showScreen: true,
        advancePolicy: GameFlowAdvancePolicy.waitsForServer,
      ),

      // ======================================================================
      // 6. 비정상 종료 정리 (CLOSING)
      // ======================================================================
      //
      // 시점/status:
      // - 인원 부족, 중단 투표 만료 등 정상 승부가 아닌 finished 상태
      //
      // 화면/문구:
      // - 게임 Screen을 숨기고 [closingMessage]를 지속 표시
      // - showAnnouncement로 문구 ON/OFF, persistent라 자동 종료시간은 없음
      //
      // 입력/Scrim/전환:
      // - showScrim=true로 배경을 어둡게 표시하고 화면 조작을 제공하지 않음
      // - 실제 라우트 종료는 게임 진입점이 서버 finished 상태를 확인해 수행
      GameScreenPhase.closing: GameFlowStep<GameScreenPhase>(
        stage: GameScreenPhase.closing,
        showScreen: false,
        showAnnouncement: true,
        announcementId: 'closing',
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
