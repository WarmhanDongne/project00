/* eslint-disable max-len */

import {PublicGameInterruption, ServerGameInterruption} from "../game-interruption/types.js";

// =========================================================================
// 마피아 상태 정의
//
// 상태는 3분할입니다.
//   public          전원 공개. 신분을 유추할 수 있는 값은 절대 넣지 않습니다.
//   private/{uid}   본인만. 내 역할, 조사 결과, 동료의 선택.
//   server          클라이언트 차단(RTDB 규칙). 역할 배분표, 밤 선택, 표.
//
// **가장 중요한 규칙: public에 "누가" 밤 행동을 했는지 넣지 않습니다.**
// 인원수만 넣습니다(nightSubmittedCount). 누가 냈는지가 보이면 특수직이
// 드러나 게임이 무너집니다. 같은 이유로 투표도 누가 누구를 찍었는지는
// server에만 두고, 개표 결과만 공개합니다.
// =========================================================================

/** 역할 확인 제한시간입니다. 이 안에 전원이 확인해야 합니다(확정: 약 1분). */
export const MAFIA_ROLE_REVEAL_MS = 60000;

/**
 * 밤에 **행동을 고를 수 있는** 시간입니다(확정 2026-08: 1분).
 *
 * 이 시간이 지나면 더 제출할 수 없고, 모두 함께 기다립니다.
 */
export const MAFIA_NIGHT_ACTION_MS = 60000;

/**
 * 행동 시간이 끝난 뒤 **다같이 기다리는** 시간입니다(확정 2026-08: 30초).
 *
 * 전원이 일찍 제출해도 밤을 바로 끝내지 않는 이유와 같습니다 — 끝나는
 * 시점이 제출 속도에 따라 달라지면 특수직 수가 드러납니다.
 */
export const MAFIA_NIGHT_WAIT_MS = 30000;

/** 밤 전체 제한시간입니다(행동 1분 + 대기 30초). */
export const MAFIA_NIGHT_MS = MAFIA_NIGHT_ACTION_MS + MAFIA_NIGHT_WAIT_MS;

/**
 * 낮 자유 토론 제한시간입니다(확정 2026-08: **생존 인원**에 따라 다릅니다).
 *
 * | 생존 | 시간 |
 * |---|---|
 * | 2~3명 | 90초 |
 * | 4명 | 120초 |
 * | 5명 | 150초 |
 * | 6명 | 180초 |
 * | 7명 | 210초 |
 * | 8명 | 240초 |
 * | 9명 이상 | 300초 |
 *
 * 사람이 줄면 할 말도 줄어듭니다. 인원과 무관하게 같은 시간을 주면 적은
 * 인원에서는 침묵이 길어집니다.
 *
 * ⚠️ 이 표가 원본입니다. 연습장(lib/games/mafia/mafia_flow_config.dart)이 같은
 * 값을 따라야 하고, functions/test/mafia-discussion-parity.test.mjs가 그것을
 * 확인합니다.
 *
 * @param {number} aliveCount 지금 살아 있는 사람 수
 * @return {number} 낮 토론에 줄 시간(밀리초)
 */
export function mafiaDiscussionMs(aliveCount: number): number {
  if (aliveCount <= 3) return 90000;
  if (aliveCount >= 9) return 300000;
  return aliveCount * 30000;
}

/** 투표 제한시간입니다. 시안의 `30초`에서 가져왔습니다. */
export const MAFIA_VOTE_MS = 30000;

export type MafiaFactionId = "citizen" | "mafia" | "neutral";

/**
 * 밤 행동의 해결 단계입니다. 값이 작을수록 먼저 처리합니다.
 *
 * Dart `MafiaNightPhase`의 order와 **같아야 합니다.** 순서가 어긋나면 규칙이
 * 깨집니다(차단이 보호보다 먼저, 조사 조작이 조사보다 먼저).
 */
export type MafiaNightPhaseId =
  | "roleblock" | "protect" | "frame" | "convert"
  | "investigate" | "mafiaAttack" | "independentAttack" | "statusEffect";

/** 밤에 대상을 고르는 행동입니다. Dart `MafiaNightAction`과 같아야 합니다. */
export type MafiaNightActionId =
  | "none" | "eliminate" | "protect" | "investigate" | "investigateRole"
  | "roleblock" | "frame" | "convert" | "silence" | "watch" | "track"
  | "mark" | "expose" | "steal";

/**
 * 밤에 고를 수 있는 대상의 범위입니다. Dart `MafiaNightTargetScope`와 같습니다.
 *
 * 영매·도둑만 "dead"입니다. 사망자를 고르는 역할이 있어서, 밤 대상 검증은
 * "살아 있는 사람"으로 고정할 수 없습니다.
 */
export type MafiaNightTargetScopeId = "alive" | "dead";

/**
 * 승리 조건입니다. Dart `MafiaWinCondition`과 같습니다.
 *
 * "faction"이 아닌 역할은 진영 승패와 **별도로** 판정합니다.
 */
export type MafiaWinConditionId =
  | "faction" | "lynchedSelf" | "lynchTarget" | "surviveToEnd"
  | "lastStanding" | "factionDominance";

/** 조사에 어떻게 보이는지입니다. */
export type MafiaInvestigationAppearanceId = "actual" | "asMafia" | "asCitizen";

export type MafiaPhase =
  | "roleReveal" | "night" | "morning" | "day" | "voting" | "voteResult"
  | "finished";

export interface MafiaPublicPlayer {
  uid: string;
  nickname: string;
  profileImageUrl: string;
  seatIndex: number;
  status: "alive" | "dead";
  /**
   * 사망 사유입니다. 살아 있는 동안에는 없습니다.
   *
   * 신분은 여기 넣지 않습니다. 신분 공개는 [MafiaPublicState.revealedRoles]가
   * 담당합니다.
   */
  deathCause?: "nightAttack" | "execution" | "left";
  /** 사망한 라운드입니다. */
  diedRound?: number;
}

/** 아침 발표에 쓰는 밤 결과입니다. */
export interface MafiaMorningResult {
  /** 밤에 사망한 uid입니다. 비어 있으면 아무도 죽지 않았습니다. */
  deadUids: string[];
  /**
   * 보호로 살아난 사람이 있었는지입니다.
   *
   * 누가 살렸는지·누가 살아났는지는 넣지 않습니다. 의사와 대상이 드러납니다.
   */
  savedCount: number;
  /**
   * 이 발표가 끝나면 게임이 끝나는지입니다(발표 연출용 힌트).
   *
   * 판정은 발표가 끝날 때 서버가 다시 합니다. 이 값은 태블릿이 **다음 단계
   * 안내를 띄우지 않도록** 미리 알려 주기 위한 것입니다. 이미 이겼는데
   * '토론을 시작합니다'가 떠오르면 게임이 계속되는 것처럼 보입니다.
   */
  endsGame?: boolean;
  resolvedAt: number;
}

/** 개표 결과입니다. */
export interface MafiaVoteResult {
  /** `대상 uid → 득표수`입니다. 누가 찍었는지는 넣지 않습니다. */
  tally: Record<string, number>;
  /** 처형된 사람입니다. 동표로 무처형이면 null입니다. */
  executedUid: string | null;
  /** 동표로 무처형인지입니다. */
  tie: boolean;
  /** 기권(미투표) 인원입니다. */
  abstainCount: number;
  /**
   * 이 처형으로 게임이 끝나는지입니다(발표 연출용 힌트).
   *
   * 판정은 발표가 끝날 때 서버가 다시 합니다. 이 값은 태블릿이 **'밤이
   * 되었습니다' 안내를 띄우지 않도록** 미리 알려 주기 위한 것입니다.
   */
  endsGame?: boolean;
  resolvedAt: number;
}

/**
 * 밤 행동이 **제출된 순간** 태블릿이 낼 소리 신호입니다.
 *
 * 확정(2026-08): 총성 같은 직업 효과음은 밤이 시작될 때 자동으로 울리지 않고,
 * 그 직업이 **선택을 완료한 순간** 방 가운데 태블릿에서 울립니다.
 *
 * **누가 했는지는 넣지 않습니다.** 행동의 종류만 넣습니다. 소리는 어차피 모두가
 * 함께 듣는 연출이지만, uid가 들어가면 그 사람의 신분이 그대로 드러납니다.
 */
export interface MafiaNightActionCue {
  /**
   * 신호 번호입니다. 이 값이 바뀔 때만 태블릿이 소리를 냅니다.
   *
   * 마감 전에 대상을 바꿔 다시 제출해도 **그 밤에 한 번만** 올라갑니다.
   */
  id: number;
  action: MafiaNightActionId;
}

export interface MafiaPublicState {
  gameType: "mafia";
  status: "playing" | "finished";
  finishReason?: "citizenWin" | "mafiaWin" | "neutralWin" | "manual" |
    "insufficientPlayers" | "interruptionVoteExpired";
  phase: MafiaPhase;
  /** 밤/낮 한 바퀴를 1로 셉니다. */
  round: number;
  revision: number;
  /**
   * 현재 단계 마감 시각입니다. 단계에 제한시간이 없으면 null입니다.
   *
   * 마피아는 턴제가 아니라 단계제지만 이름을 `turnDeadlineAt`으로 둡니다.
   * 공용 중단 모듈(`game-interruption`)이 **이 이름의 필드를 찾아** 연결이
   * 끊긴 동안 타이머를 멈추고 복귀 시 남은 시간을 되돌려 줍니다. 이름을 바꾸면
   * 그 기능이 조용히 동작하지 않습니다.
   */
  turnDeadlineAt: number | null;
  players: Record<string, MafiaPublicPlayer>;

  /** 역할 확인을 마친 인원입니다. 누가 마쳤는지는 공개해도 무해합니다. */
  roleRevealedUids: string[];

  /**
   * 밤 행동을 제출한 인원수입니다. **누가 냈는지는 넣지 않습니다.**
   * 특수직이 드러나기 때문입니다.
   */
  nightSubmittedCount: number;
  /** 이번 밤에 행동해야 하는 인원수입니다. */
  nightActorCount: number;

  /**
   * 방금 제출된 밤 행동의 소리 신호입니다([MafiaNightActionCue]).
   *
   * 아직 아무도 제출하지 않았으면 없습니다.
   */
  nightActionCue?: MafiaNightActionCue;

  /**
   * 토론 조기 종료에 동의한 인원수입니다(확정 규칙: 과반수 투표).
   *
   * 휴대폰 버튼이 `n/m`으로 실시간 표시합니다. 누가 눌렀는지는 넣지 않습니다.
   */
  discussionSkipCount: number;

  /** 투표를 마친 인원수입니다. */
  voteSubmittedCount: number;

  /**
   * 투표를 마친 사람의 uid 목록입니다(**표를 어디에 냈는지는 없습니다**).
   *
   * 태블릿이 그 사람 좌석에서 투표지가 날아가는 연출을 그리는 데 씁니다.
   * 실제 게임에서도 누가 투표함에 넣었는지는 모두가 보므로 공개해도 무해합니다.
   * 밤 행동은 사정이 달라 [nightSubmittedCount]처럼 **수만** 공개합니다 —
   * 누가 행동했는지가 드러나면 특수직이 노출됩니다.
   */
  voteSubmittedUids: string[];
  /** 이번 투표에 참여할 수 있는 인원수입니다. */
  voteEligibleCount: number;

  morningResult?: MafiaMorningResult;
  voteResult?: MafiaVoteResult;

  /**
   * **모두에게** 공개된 신분입니다. `uid → 역할 id`.
   *
   * 여기 들어오는 경로는 세 가지뿐입니다.
   *   1. 처형된 사람 (확정 규칙)
   *   2. 기자가 지목해 아침에 공개된 사람 — **살아 있어도 들어옵니다**
   *   3. 게임 종료 (전원 공개)
   *
   * 그 밖의 경우에 살아 있는 사람의 신분을 넣으면 게임이 무너집니다. 특히 밤에
   * 죽은 사람은 여기 넣지 않습니다(공개 여부 미확정). 관전자가 보는 전원
   * 신분표는 public이 아니라 `private/{uid}.spectatorRoles`입니다.
   */
  revealedRoles?: Record<string, string>;

  /**
   * 승리 진영입니다. 아직 끝나지 않았으면 null입니다.
   *
   * 중립의 **개별 승리**(광대·처형자·연쇄살인마·교단)도 "neutral"로 보냅니다.
   * 누가 이겼는지는 [winnerUids]에 있고, 끝나는 순간 전원 신분이 공개되므로
   * 화면이 "광대 승리"처럼 이름을 붙일 수 있습니다.
   */
  winner: MafiaFactionId | null;
  winnerUids: string[];
  startedAt: number;
  updatedAt: number;
  finishedAt?: number;
  interruption?: PublicGameInterruption;
}

/** 경찰·정보원의 조사 기록 한 건입니다. */
export interface MafiaInvestigationRecord {
  round: number;
  targetUid: string;
  /** 서버가 계산한 결과 문구입니다. 클라이언트가 다시 계산하지 않습니다. */
  verdict: string;
}

export interface MafiaPrivatePlayer {
  /** 내 역할 id입니다. */
  roleId: string;
  /** 같은 편 uid입니다(마피아·메이슨). 서로 알고 시작하는 역할만 채웁니다. */
  allyUids?: string[];
  /** 내가 이번 밤에 고른 대상입니다. */
  nightTargetUid?: string;
  /**
   * 동료가 고른 대상입니다. `동료 uid → 대상 uid`.
   *
   * 마피아가 서로의 선택을 실시간으로 보기 위한 값입니다. public에 두면 전원에게
   * 보이므로 각자의 private에 복사합니다.
   */
  allySelections?: Record<string, string>;
  /** 조사 기록입니다. 라운드별로 누적합니다. */
  investigations?: Record<string, MafiaInvestigationRecord>;
  /** 내가 투표한 대상입니다. */
  voteTargetUid?: string;
  /**
   * 처형자에게 지정된 목표입니다. 처형자 본인에게만 넣습니다.
   *
   * 목표가 **낮 투표로** 처형되면 그 자리에서 처형자가 단독 승리합니다.
   */
  executionerTargetUid?: string;
  /**
   * 남은 능력 사용 횟수입니다. 제한이 있는 역할(자경단원)에만 넣습니다.
   *
   * 0이면 더 쓸 수 없습니다. 밤 화면이 이 값으로 버튼을 잠급니다.
   */
  abilityUsesLeft?: number;
  /**
   * 이번 낮에 투표할 수 없는지입니다(마담에게 유혹당함).
   *
   * 밤 해결에서 정해지고, 그 낮의 투표가 시작될 때 본인에게만 알려 줍니다.
   */
  voteBanned?: boolean;
  /**
   * 지난밤 결과로 내 신분이 바뀌었는지입니다(도둑의 절도, 교주의 전향).
   *
   * 바뀐 신분 자체는 [roleId]에 이미 반영돼 있습니다. 이 값은 화면이 "당신은
   * 이제 ○○입니다" 안내를 띄울지 판단하는 데만 씁니다.
   */
  roleChangedRound?: number;
  /** 토론 조기 종료에 동의했는지입니다. 재접속해도 버튼 상태가 유지됩니다. */
  discussionSkipVoted?: boolean;
  /**
   * 관전자에게 공개하는 **전원의 신분**입니다. `uid → 역할 id`.
   *
   * 사망한 순간에 그 사람의 private에만 씁니다. public에 두면 살아 있는
   * 사람의 클라이언트도 읽을 수 있어 게임이 무너집니다. 시안 P8(관전자 정보)이
   * 이 값을 씁니다.
   */
  spectatorRoles?: Record<string, string>;
}

export interface MafiaProcessedCommand {
  uid: string;
  type: string;
  createdAt: number;
  result: Record<string, unknown>;
}

export interface MafiaServerState {
  /** 역할 배분표입니다. `uid → 역할 id`. 클라이언트는 읽을 수 없습니다. */
  roles: Record<string, string>;
  /**
   * 이 판을 만들 때 쓴 역할 구성입니다(`역할 id → 인원수`).
   *
   * **다시하기에서 그대로 다시 씁니다.** 태블릿이 역할 배치 화면에서 고른
   * 구성은 그 판의 규칙이므로, 다시하기 때 추천 표로 되돌아가면 안 됩니다.
   * 인원이 바뀌어 합이 맞지 않으면 추천 표로 돌아갑니다.
   */
  composition?: Record<string, number>;
  /** 이번 밤의 선택입니다. `uid → 대상 uid`. */
  nightActions?: Record<string, string>;
  /** 이번 투표의 표입니다. `uid → 대상 uid`. */
  votes?: Record<string, string>;
  /** 토론 조기 종료에 동의한 사람입니다. `uid → true`. */
  discussionSkipVotes?: Record<string, true>;
  /**
   * 능력을 쓴 횟수입니다. `uid → 횟수`. 제한이 있는 역할만 쌓입니다.
   *
   * 실제로 **효과가 발생한** 밤만 셉니다. 차단당해 불발된 밤은 세지 않습니다.
   */
  abilityUses?: Record<string, number>;
  /** 자기 방어를 이미 쓴 사람입니다(군인). `uid → true`. */
  defenseUsed?: Record<string, true>;
  /**
   * 다음 낮에 투표할 수 없는 사람입니다(마담에게 유혹당함). `uid → true`.
   *
   * 그 낮의 투표가 시작될 때 소모하고 지웁니다.
   */
  voteBans?: Record<string, true>;
  /** 처형자의 목표입니다. `처형자 uid → 목표 uid`. */
  executionerTargets?: Record<string, string>;
  /**
   * 처형으로 확정된 단독 승리자입니다(광대·처형자).
   *
   * 처형이 정해지는 순간 예약하고, 태블릿의 처형 발표 연출이 끝난 뒤에 게임을
   * 끝냅니다. 즉시 끝내면 처형 장면을 보여 주지 못하고 결과 화면으로 튕깁니다.
   */
  pendingNeutralWinUids?: string[];
  processedCommands?: Record<string, MafiaProcessedCommand>;
  interruption?: ServerGameInterruption;
}

export interface MafiaGameState {
  public: MafiaPublicState;
  private: Record<string, MafiaPrivatePlayer>;
  server: MafiaServerState;
}

export interface MafiaRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: MafiaGameState;
}
