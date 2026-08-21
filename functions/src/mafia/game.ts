/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {randomInt} from "node:crypto";

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  actsAtNight,
  MAFIA_NIGHT_PHASE_ORDER,
  mafiaCompositionFor,
  mafiaRole,
} from "./roles.js";
import {
  MAFIA_DAY_MS,
  MAFIA_NIGHT_MS,
  MAFIA_ROLE_REVEAL_MS,
  MAFIA_VOTE_MS,
  MafiaFactionId,
  MafiaGameState,
  MafiaPrivatePlayer,
  MafiaPublicPlayer,
  MafiaRoom,
} from "./types.js";

// =========================================================================
// 마피아 진행 엔진
//
// 역할 이름으로 분기하지 않습니다. 밤 해결은 `nightAction`과 `nightPhase`만
// 보고 처리하므로, 역할을 추가할 때 이 파일을 고칠 필요가 없습니다.
// =========================================================================

/** 로비 참가자를 마피아 공개 플레이어로 변환합니다. */
export async function createMafiaPlayers(
  roomPlayers: MafiaRoom["players"],
): Promise<Record<string, MafiaPublicPlayer>> {
  if (!roomPlayers) {
    throw new HttpsError("failed-precondition", "참가 플레이어가 없습니다.");
  }

  const profileUrls = new Map<string, string>();
  await Promise.all(Object.entries(roomPlayers).map(async ([uid, value]) => {
    const roomUrl = typeof value.profileImageUrl === "string" ?
      value.profileImageUrl.trim() : "";
    if (roomUrl) {
      profileUrls.set(uid, roomUrl);
      return;
    }
    try {
      const snapshot = await getFirestore().collection("users").doc(uid).get();
      const url = snapshot.data()?.profileImageUrl;
      if (typeof url === "string") profileUrls.set(uid, url.trim());
    } catch (error) {
      console.warn("Mafia profile lookup failed", error);
    }
  }));

  const players: Record<string, MafiaPublicPlayer> = {};
  for (const [uid, value] of Object.entries(roomPlayers)) {
    if (value.role !== "player" || value.status !== "active") continue;
    if (!Number.isInteger(value.seatIndex)) {
      throw new HttpsError(
        "failed-precondition",
        "모든 플레이어의 자리를 먼저 지정해주세요.",
      );
    }
    players[uid] = {
      uid,
      nickname: typeof value.nickname === "string" ? value.nickname : "Player",
      profileImageUrl: profileUrls.get(uid) ?? "",
      seatIndex: value.seatIndex as number,
      status: "alive",
    };
  }
  assertValidSeats(players);
  return players;
}

function assertValidSeats(players: Record<string, MafiaPublicPlayer>): void {
  const seats = Object.values(players).map((player) => player.seatIndex);
  if (new Set(seats).size !== seats.length) {
    throw new HttpsError("failed-precondition", "중복된 자리가 있습니다.");
  }
}

/** 좌석 순서대로 정렬한 플레이어입니다. */
export function orderedPlayers(
  players: Record<string, MafiaPublicPlayer>,
): MafiaPublicPlayer[] {
  return Object.values(players)
    .sort((left, right) => left.seatIndex - right.seatIndex);
}

export function alivePlayers(
  players: Record<string, MafiaPublicPlayer>,
): MafiaPublicPlayer[] {
  return orderedPlayers(players).filter((player) => player.status === "alive");
}

/** 배열을 제자리에서 섞습니다. */
function shuffle<T>(items: T[]): T[] {
  for (let index = items.length - 1; index > 0; index -= 1) {
    const swapIndex = randomInt(index + 1);
    [items[index], items[swapIndex]] = [items[swapIndex], items[index]];
  }
  return items;
}

/**
 * 인원수에 맞는 구성으로 역할을 무작위 배분합니다.
 *
 * 구성표에 없는 인원이거나 구현되지 않은 역할이 섞여 있으면 시작을 막습니다.
 * 정의만 있는 역할이 배분되면 그 사람은 밤에 아무것도 할 수 없어 게임이
 * 멈춥니다.
 */
export function assignMafiaRoles(
  players: Record<string, MafiaPublicPlayer>,
): Record<string, string> {
  const uids = orderedPlayers(players).map((player) => player.uid);
  const composition = mafiaCompositionFor(uids.length);
  if (!composition) {
    throw new HttpsError(
      "failed-precondition",
      `${uids.length}명으로는 아직 시작할 수 없습니다.`,
    );
  }

  const pool: string[] = [];
  for (const [roleId, count] of Object.entries(composition)) {
    for (let index = 0; index < count; index += 1) pool.push(roleId);
  }
  if (pool.length !== uids.length) {
    throw new HttpsError("internal", "역할 구성이 인원과 맞지 않습니다.");
  }

  shuffle(pool);
  const roles: Record<string, string> = {};
  uids.forEach((uid, index) => {
    roles[uid] = pool[index];
  });
  return roles;
}

/** 서로를 아는 역할끼리 동료 목록을 만듭니다(마피아 등). */
function allyUidsFor(
  uid: string,
  roles: Record<string, string>,
): string[] | undefined {
  const role = mafiaRole(roles[uid]);
  if (!role?.knowsAllies) return undefined;
  const allies = Object.entries(roles)
    .filter(([otherUid, otherRoleId]) => {
      if (otherUid === uid) return false;
      const other = mafiaRole(otherRoleId);
      // 같은 진영이고, 서로 아는 역할끼리만 묶습니다.
      return other?.knowsAllies === true && other.faction === role.faction;
    })
    .map(([otherUid]) => otherUid);
  return allies.length > 0 ? allies : undefined;
}

/** 새 게임의 초기 상태입니다. 역할 확인 단계로 시작합니다. */
export function createInitialMafiaGame(
  players: Record<string, MafiaPublicPlayer>,
  now: number,
): MafiaGameState {
  const roles = assignMafiaRoles(players);
  const privateState: Record<string, MafiaPrivatePlayer> = {};
  for (const uid of Object.keys(roles)) {
    const allies = allyUidsFor(uid, roles);
    privateState[uid] = allies ?
      {roleId: roles[uid], allyUids: allies} :
      {roleId: roles[uid]};
  }

  return {
    public: {
      gameType: "mafia",
      status: "playing",
      phase: "roleReveal",
      round: 1,
      revision: 1,
      // 전원 확인까지 기다리되 무한정은 아닙니다(확정: 약 1분). 시간이 지나면
      // 태블릿이 completeRoleReveal로 진행합니다.
      turnDeadlineAt: now + MAFIA_ROLE_REVEAL_MS,
      players,
      roleRevealedUids: [],
      nightSubmittedCount: 0,
      nightActorCount: 0,
      discussionSkipCount: 0,
      voteSubmittedCount: 0,
      voteSubmittedUids: [],
      voteEligibleCount: 0,
      winner: null,
      winnerUids: [],
      startedAt: now,
      updatedAt: now,
    },
    private: privateState,
    server: {roles},
  };
}

// ===== 단계 전환 =====

/** 밤을 시작합니다. 지난 밤의 선택을 모두 지웁니다. */
export function beginMafiaNight(game: MafiaGameState, now: number): void {
  const actors = alivePlayers(game.public.players)
    .filter((player) => actsAtNight(game.server.roles[player.uid]));

  game.public.phase = "night";
  game.public.turnDeadlineAt = now + MAFIA_NIGHT_MS;
  game.public.nightSubmittedCount = 0;
  game.public.nightActorCount = actors.length;
  delete game.public.morningResult;
  delete game.public.voteResult;
  delete game.server.nightActions;
  delete game.server.votes;

  for (const entry of Object.values(game.private)) {
    delete entry.nightTargetUid;
    delete entry.allySelections;
    delete entry.voteTargetUid;
  }
  touch(game, now);
}

/** 낮 토론을 시작합니다. 지난 낮의 조기 종료 동의를 지웁니다. */
export function beginMafiaDay(game: MafiaGameState, now: number): void {
  game.public.phase = "day";
  game.public.turnDeadlineAt = now + MAFIA_DAY_MS;
  game.public.discussionSkipCount = 0;
  delete game.server.discussionSkipVotes;
  for (const entry of Object.values(game.private)) {
    delete entry.discussionSkipVoted;
  }
  touch(game, now);
}

/** 투표를 시작합니다. */
export function beginMafiaVoting(game: MafiaGameState, now: number): void {
  game.public.phase = "voting";
  game.public.turnDeadlineAt = now + MAFIA_VOTE_MS;
  game.public.voteSubmittedCount = 0;
  game.public.voteSubmittedUids = [];
  game.public.voteEligibleCount = alivePlayers(game.public.players).length;
  delete game.server.votes;
  for (const entry of Object.values(game.private)) {
    delete entry.voteTargetUid;
  }
  touch(game, now);
}

function touch(game: MafiaGameState, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}

// ===== 밤 해결 =====

/**
 * 조사 결과 문구입니다.
 *
 * **실제 진영을 그대로 쓰지 않습니다.** 밀러는 시민인데 마피아로, 마피아 보스는
 * 마피아인데 시민으로 보여야 합니다. 조작(프레이머)까지 반영합니다.
 */
export function mafiaInvestigationVerdict(
  targetRoleId: string,
  framed: boolean,
): string {
  if (framed) return "마피아";
  const role = mafiaRole(targetRoleId);
  if (!role) return "시민";
  switch (role.investigationAppearance) {
  case "asMafia":
    return "마피아";
  case "asCitizen":
    return "시민";
  default:
    return role.faction === "mafia" ? "마피아" : "시민";
  }
}

/** 조사·추적 결과를 본인 private에만 남깁니다. */
function recordInvestigation(
  game: MafiaGameState,
  actorUid: string,
  targetUid: string,
  verdict: string,
  round: number,
): void {
  const actorPrivate = game.private[actorUid];
  if (!actorPrivate) return;
  actorPrivate.investigations ??= {};
  actorPrivate.investigations[`r${round}`] = {round, targetUid, verdict};
}

/**
 * 제출한 순간 조사·추적 결과를 본인 private에 기록합니다.
 *
 * 확정 흐름이 "선택 완료 → 결과 → 확인"이라 결과를 밤이 끝날 때까지 기다릴 수
 * 없습니다. 다만 이 시점에는 프레이머 조작이나 대상의 최종 행동을 알 수 없어
 * **잠정값**이고, 밤 해결 때 같은 자리(`r{round}`)에 최종값을 덮어씁니다.
 */
export function recordImmediateInvestigation(
  game: MafiaGameState,
  actorUid: string,
  targetUid: string,
  now: number,
): void {
  const role = mafiaRole(game.server.roles[actorUid]);
  if (role === null) return;
  const round = game.public.round;
  switch (role.nightAction) {
  case "investigate":
  case "investigateRole": {
    const verdict = mafiaInvestigationVerdict(
      game.server.roles[targetUid],
      false,
    );
    recordInvestigation(game, actorUid, targetUid, verdict, round);
    break;
  }
  case "track": {
    const visitedUid = game.server.nightActions?.[targetUid];
    const verdict = visitedUid ?
      game.public.players[visitedUid]?.nickname ?? "알 수 없음" :
      "방문 없음";
    recordInvestigation(game, actorUid, targetUid, verdict, round);
    break;
  }
  default:
    break;
  }
  // touch는 호출부(제출 트랜잭션)가 이미 합니다. now는 서명 일관성용입니다.
  void now;
}

/** 표를 세어 최다 득표 대상을 고릅니다. */
function tallyVotes(votes: Record<string, string>): {
  tally: Record<string, number>;
  leaders: string[];
} {
  const tally: Record<string, number> = {};
  for (const targetUid of Object.values(votes)) {
    tally[targetUid] = (tally[targetUid] ?? 0) + 1;
  }
  let best = 0;
  for (const count of Object.values(tally)) best = Math.max(best, count);
  const leaders = Object.entries(tally)
    .filter(([, count]) => count === best)
    .map(([uid]) => uid);
  return {tally, leaders: best === 0 ? [] : leaders};
}

/**
 * 밤 행동을 해결하고 아침 결과를 만듭니다.
 *
 * 반드시 [MAFIA_NIGHT_PHASE_ORDER] 순서로 처리합니다. 순서가 어긋나면 규칙이
 * 깨집니다(차단이 보호보다 먼저, 조사 조작이 조사보다 먼저).
 */
export function resolveMafiaNight(game: MafiaGameState, now: number): void {
  const actions = game.server.nightActions ?? {};
  const roles = game.server.roles;
  const round = game.public.round;

  const blockedUids = new Set<string>();
  const protectedUids = new Set<string>();
  const framedUids = new Set<string>();
  const deadUids = new Set<string>();
  let savedCount = 0;

  // 살아 있는 사람의 행동만, 단계 순서대로 처리합니다.
  // flatMap으로 걸러 role·phase가 null이 아닌 것만 남기면 아래에서 단정(!)이
  // 필요하지 않습니다.
  const ordered = Object.entries(actions)
    .filter(([actorUid]) => game.public.players[actorUid]?.status === "alive")
    .flatMap(([actorUid, targetUid]) => {
      const role = mafiaRole(roles[actorUid]);
      if (!role || role.nightPhase === null) return [];
      return [{actorUid, targetUid, role, phase: role.nightPhase}];
    })
    .sort((left, right) =>
      MAFIA_NIGHT_PHASE_ORDER[left.phase] -
      MAFIA_NIGHT_PHASE_ORDER[right.phase]);

  // 마피아 진영의 제거는 한 명만 죽이므로 표로 모아 마지막에 판정합니다.
  const mafiaAttackVotes: Record<string, string> = {};

  for (const entry of ordered) {
    const role = entry.role;
    // 차단된 사람의 능력은 무효입니다.
    if (blockedUids.has(entry.actorUid)) continue;
    // 이미 죽은 대상에게는 아무 일도 일어나지 않습니다.
    if (game.public.players[entry.targetUid]?.status !== "alive") continue;

    switch (role.nightAction) {
    case "roleblock":
      blockedUids.add(entry.targetUid);
      break;
    case "protect":
      protectedUids.add(entry.targetUid);
      break;
    case "frame":
      framedUids.add(entry.targetUid);
      break;
    case "investigate":
    case "investigateRole": {
      const verdict = mafiaInvestigationVerdict(
        roles[entry.targetUid],
        framedUids.has(entry.targetUid),
      );
      recordInvestigation(game, entry.actorUid, entry.targetUid, verdict, round);
      break;
    }
    case "track": {
      // 대상이 이 밤에 누구를 골랐는지 알려 줍니다. 이름은 짧게 담아야
      // 결과 화면(36px 한 줄)에서 넘치지 않습니다.
      const visitedUid = actions[entry.targetUid];
      const verdict = visitedUid ?
        game.public.players[visitedUid]?.nickname ?? "알 수 없음" :
        "방문 없음";
      recordInvestigation(game, entry.actorUid, entry.targetUid, verdict, round);
      break;
    }
    case "expose":
      // 기자입니다. 경찰과 달리 **모두가** 보므로 public에 씁니다.
      game.public.revealedRoles ??= {};
      game.public.revealedRoles[entry.targetUid] = roles[entry.targetUid];
      break;
    case "eliminate":
      if (role.faction === "mafia") {
        // 마피아는 다수결로 한 명만 죽입니다.
        mafiaAttackVotes[entry.actorUid] = entry.targetUid;
      } else if (!protectedUids.has(entry.targetUid)) {
        // 자경단원·연쇄살인마 등 독립 공격은 각자 처리합니다.
        deadUids.add(entry.targetUid);
      } else {
        savedCount += 1;
      }
      break;
    default:
      // 아직 처리하지 않는 행동입니다(전향·침묵·감시·추적·표식).
      break;
    }
  }

  // 마피아 공격 판정 — 다수결, 동표면 무작위(확정 규칙).
  const attack = tallyVotes(mafiaAttackVotes);
  if (attack.leaders.length > 0) {
    const targetUid = attack.leaders.length === 1 ?
      attack.leaders[0] :
      attack.leaders[randomInt(attack.leaders.length)];
    if (protectedUids.has(targetUid)) {
      savedCount += 1;
    } else {
      deadUids.add(targetUid);
    }
  }

  for (const uid of deadUids) {
    killMafiaPlayer(game, uid, "nightAttack", now);
  }

  game.public.morningResult = {
    deadUids: [...deadUids],
    savedCount,
    resolvedAt: now,
  };
  game.public.phase = "morning";
  // 아침 발표는 태블릿 연출이 끝나면 넘어갑니다. 제한시간을 두지 않습니다.
  game.public.turnDeadlineAt = null;
  delete game.server.nightActions;
  touch(game, now);
}

// ===== 투표 해결 =====

/**
 * 표를 세어 처형자를 정합니다. **동표면 무처형**입니다(확정 규칙).
 *
 * 밤의 마피아 지목과 다릅니다. 마피아 지목은 동표면 무작위입니다.
 */
export function resolveMafiaVoting(game: MafiaGameState, now: number): void {
  const votes = game.server.votes ?? {};
  const {tally, leaders} = tallyVotes(votes);
  const aliveCount = alivePlayers(game.public.players).length;
  const tie = leaders.length > 1;
  const executedUid = leaders.length === 1 ? leaders[0] : null;

  if (executedUid) {
    killMafiaPlayer(game, executedUid, "execution", now);
    // 처형자 신분은 공개합니다(확정 규칙).
    game.public.revealedRoles ??= {};
    game.public.revealedRoles[executedUid] = game.server.roles[executedUid];
  }

  game.public.voteResult = {
    tally,
    executedUid,
    tie,
    abstainCount: Math.max(0, aliveCount - Object.keys(votes).length),
    resolvedAt: now,
  };
  game.public.phase = "voteResult";
  // 개표·처형 발표는 태블릿 연출이 끝나면 넘어갑니다.
  game.public.turnDeadlineAt = null;
  delete game.server.votes;
  touch(game, now);
}

// ===== 사망 처리 =====

/**
 * 플레이어를 사망 처리합니다.
 *
 * 사망한 사람에게는 **전원의 신분**을 private으로 넘겨 관전 화면(P8)을 채웁니다.
 * public에 두면 살아 있는 사람도 읽을 수 있어 게임이 무너집니다.
 */
export function killMafiaPlayer(
  game: MafiaGameState,
  uid: string,
  cause: MafiaPublicPlayer["deathCause"],
  now: number,
): void {
  const player = game.public.players[uid];
  if (!player || player.status !== "alive") return;
  player.status = "dead";
  player.deathCause = cause;
  player.diedRound = game.public.round;

  const spectatorRoles: Record<string, string> = {};
  for (const [playerUid, roleId] of Object.entries(game.server.roles)) {
    spectatorRoles[playerUid] = roleId;
  }
  game.private[uid] ??= {roleId: game.server.roles[uid]};
  game.private[uid].spectatorRoles = spectatorRoles;
  game.public.updatedAt = now;
}

// ===== 승패 판정 =====

/**
 * 승리 진영입니다. 아직 끝나지 않았으면 null입니다.
 *
 * - 살아 있는 마피아가 없으면 시민 승리
 * - 마피아가 나머지 인원과 같거나 많으면 마피아 승리
 *
 * 중립 역할의 개별 승리 조건은 아직 판정하지 않습니다.
 */
export function checkMafiaWinner(game: MafiaGameState): MafiaFactionId | null {
  const alive = alivePlayers(game.public.players);
  let mafiaCount = 0;
  let otherCount = 0;
  for (const player of alive) {
    const faction = mafiaRole(game.server.roles[player.uid])?.faction;
    if (faction === "mafia") mafiaCount += 1;
    else otherCount += 1;
  }
  if (mafiaCount === 0) return "citizen";
  if (mafiaCount >= otherCount) return "mafia";
  return null;
}

/** 게임을 끝냅니다. 끝나는 순간 전원의 신분을 공개합니다. */
export function finishMafiaGame(
  game: MafiaGameState,
  winner: MafiaFactionId | null,
  reason: NonNullable<MafiaGameState["public"]["finishReason"]>,
  now: number,
): void {
  game.public.status = "finished";
  game.public.phase = "finished";
  game.public.turnDeadlineAt = null;
  game.public.finishReason = reason;
  game.public.winner = winner;
  game.public.finishedAt = now;

  // 게임이 끝나면 전원 신분을 공개합니다(결과 화면).
  const revealed: Record<string, string> = {};
  for (const [uid, roleId] of Object.entries(game.server.roles)) {
    revealed[uid] = roleId;
  }
  game.public.revealedRoles = revealed;

  game.public.winnerUids = winner === null ? [] :
    Object.keys(game.server.roles).filter((uid) =>
      mafiaRole(game.server.roles[uid])?.faction === winner);
  touch(game, now);
}

/**
 * 승패를 확인해 끝났으면 마무리하고, 아니면 다음 단계로 넘깁니다.
 *
 * 판정 시점은 두 곳입니다: 아침 발표 직후, 처형 발표 직후.
 */
export function advanceMafiaAfterDeaths(
  game: MafiaGameState,
  next: "day" | "night",
  now: number,
): MafiaFactionId | null {
  const winner = checkMafiaWinner(game);
  if (winner) {
    finishMafiaGame(
      game,
      winner,
      winner === "mafia" ? "mafiaWin" : "citizenWin",
      now,
    );
    return winner;
  }
  if (next === "day") {
    beginMafiaDay(game, now);
  } else {
    game.public.round += 1;
    beginMafiaNight(game, now);
  }
  return null;
}
