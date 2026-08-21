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
 * 밤 제한시간입니다(확정 2026-08: 최소 3분).
 *
 * 전원이 행동을 끝내도 밤은 이 시간을 채웁니다. 일찍 끝내면 제출 속도로
 * 특수직 수가 드러날 수 있고, 밤의 긴장감도 사라지기 때문입니다.
 */
export const MAFIA_NIGHT_MS = 180000;

/** 낮 자유 토론 제한시간입니다. 시안의 `2m 30s`에서 가져왔습니다. */
export const MAFIA_DAY_MS = 150000;

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
  | "mark" | "expose";

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
  resolvedAt: number;
}

export interface MafiaPublicState {
  gameType: "mafia";
  status: "playing" | "finished";
  finishReason?: "citizenWin" | "mafiaWin" | "manual" | "insufficientPlayers" |
    "interruptionVoteExpired";
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
  /** 이번 밤의 선택입니다. `uid → 대상 uid`. */
  nightActions?: Record<string, string>;
  /** 이번 투표의 표입니다. `uid → 대상 uid`. */
  votes?: Record<string, string>;
  /** 토론 조기 종료에 동의한 사람입니다. `uid → true`. */
  discussionSkipVotes?: Record<string, true>;
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
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: MafiaGameState;
}
