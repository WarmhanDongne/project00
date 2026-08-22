/* eslint-disable valid-jsdoc, max-len, require-jsdoc */

import {randomInt} from "node:crypto";

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

import {
  actsAtNight,
  actsInBlockStage,
  MAFIA_NIGHT_PHASE_ORDER,
  mafiaCompositionFor,
  mafiaRole,
} from "./roles.js";
import {
  mafiaDiscussionMs,
  MAFIA_DAY_SKIP_NOTICE_MS,
  MAFIA_NIGHT_ACTION_MS,
  MAFIA_NIGHT_BLOCK_MS,
  MAFIA_NIGHT_WAIT_MS,
  MAFIA_ROLE_REVEAL_MS,
  MAFIA_VOTE_MS,
  MafiaFactionId,
  MafiaGameState,
  MafiaNightStageId,
  MafiaPrivatePlayer,
  MafiaPublicPlayer,
  MafiaPublicState,
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
      // 로비에서 고른 동물 아이콘입니다. 사진을 올리지 않은 사람은 게임
      // 화면에서도 이 아이콘으로 보여야 합니다(라이어스 포커와 같은 규약).
      characterId: typeof value.characterId === "string" && value.characterId ?
        value.characterId : "frog",
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
/**
 * 이 인원에 쓸 역할 구성입니다. 고른 것이 없으면 추천 표를 씁니다.
 *
 * @param {number} playerCount 인원
 * @param {Record<string, number> | null} chosen 역할 배치 화면에서 고른 구성
 * @return {Record<string, number> | null} 쓸 구성(불가능하면 null)
 */
export function mafiaCompositionToUse(
  playerCount: number,
  chosen: Record<string, number> | null,
): Record<string, number> | null {
  if (chosen) {
    const total = Object.values(chosen).reduce((sum, n) => sum + n, 0);
    // 인원이 바뀌었으면(누가 나가거나 들어옴) 그 구성은 더 못 씁니다.
    if (total === playerCount) return chosen;
  }
  return mafiaCompositionFor(playerCount);
}

export function assignMafiaRoles(
  players: Record<string, MafiaPublicPlayer>,
  chosen: Record<string, number> | null = null,
): Record<string, string> {
  const uids = orderedPlayers(players).map((player) => player.uid);
  // 태블릿이 역할 배치 화면에서 고른 구성이 있으면 그것을 씁니다(확정 2026-08).
  // 없으면 인원별 추천 표를 그대로 씁니다.
  const composition = mafiaCompositionToUse(uids.length, chosen);
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

/**
 * 모든 사람의 동료 목록을 배분표에 맞춰 다시 계산합니다.
 *
 * 게임 중에 신분이 바뀌는 역할(교주의 전향, 도둑의 절도)이 있어서, 시작할 때
 * 한 번 만든 목록으로는 부족합니다. 바뀐 사람뿐 아니라 **상대편 목록에서도**
 * 사라지거나 나타나야 하므로 전원을 다시 계산합니다.
 */
function refreshMafiaAllies(game: MafiaGameState): void {
  for (const uid of Object.keys(game.server.roles)) {
    const entry = game.private[uid];
    if (!entry) continue;
    const allies = allyUidsFor(uid, game.server.roles);
    if (allies) entry.allyUids = allies;
    else delete entry.allyUids;
  }
}

/**
 * 게임 중에 신분을 바꿉니다(교주의 전향, 도둑의 절도).
 *
 * 배분표(`server.roles`)와 본인 private을 함께 고쳐야 합니다. 한쪽만 바꾸면
 * 화면에 보이는 신분과 승패 판정이 어긋납니다.
 */
function changeMafiaRole(
  game: MafiaGameState,
  uid: string,
  roleId: string,
  round: number,
): void {
  if (!mafiaRole(roleId)) return;
  if (game.server.roles[uid] === roleId) return;
  game.server.roles[uid] = roleId;
  game.private[uid] ??= {roleId};
  game.private[uid].roleId = roleId;
  game.private[uid].roleChangedRound = round;
  refreshMafiaAllies(game);
}

/**
 * 처형자에게 목표를 지정합니다(게임 시작 시 한 번).
 *
 * 목표는 **시민 진영의 살아 있는 사람** 중 무작위입니다. 마피아를 목표로 주면
 * 처형자가 사실상 시민팀 조력자가 되어 역할이 의미를 잃습니다.
 *
 * ⚠️ 목표가 처형이 아닌 이유로 죽으면 이 처형자는 이길 수 없습니다(마피아42는
 * 그 경우 광대로 바뀌지만, 그 규칙은 아직 넣지 않았습니다).
 */
function assignExecutionerTargets(
  roles: Record<string, string>,
  privateState: Record<string, MafiaPrivatePlayer>,
): Record<string, string> | undefined {
  const executioners = Object.keys(roles)
    .filter((uid) => mafiaRole(roles[uid])?.winCondition === "lynchTarget");
  if (executioners.length === 0) return undefined;

  const targets: Record<string, string> = {};
  for (const uid of executioners) {
    const candidates = Object.keys(roles).filter((other) =>
      other !== uid && mafiaRole(roles[other])?.faction === "citizen");
    if (candidates.length === 0) continue;
    const targetUid = candidates[randomInt(candidates.length)];
    targets[uid] = targetUid;
    privateState[uid].executionerTargetUid = targetUid;
  }
  return Object.keys(targets).length > 0 ? targets : undefined;
}

/** 새 게임의 초기 상태입니다. 역할 확인 단계로 시작합니다. */
export function createInitialMafiaGame(
  players: Record<string, MafiaPublicPlayer>,
  now: number,
  composition: Record<string, number> | null = null,
): MafiaGameState {
  const roles = assignMafiaRoles(players, composition);
  // 다시하기가 같은 구성으로 돌 수 있게 실제로 쓴 구성을 남깁니다.
  const usedComposition = mafiaCompositionToUse(
    Object.keys(players).length,
    composition,
  );
  const privateState: Record<string, MafiaPrivatePlayer> = {};
  for (const uid of Object.keys(roles)) {
    const allies = allyUidsFor(uid, roles);
    privateState[uid] = allies ?
      {roleId: roles[uid], allyUids: allies} :
      {roleId: roles[uid]};
    // 사용 횟수가 제한된 역할(자경단원)은 남은 횟수를 본인에게만 알려 줍니다.
    const maxUses = mafiaRole(roles[uid])?.maxUses ?? null;
    if (maxUses !== null) privateState[uid].abilityUsesLeft = maxUses;
  }
  const executionerTargets = assignExecutionerTargets(roles, privateState);

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
    server: {
      roles,
      ...(executionerTargets ? {executionerTargets} : {}),
      // 다시하기가 같은 구성으로 돌게 남겨 둡니다.
      ...(usedComposition ? {composition: usedComposition} : {}),
    },
  };
}

// ===== 단계 전환 =====

/**
 * 밤 행동 소리 신호를 올립니다([MafiaNightActionCue]).
 *
 * 확정(2026-08): 직업 효과음은 밤이 시작될 때 자동으로 울리지 않고, 그 직업이
 * **선택을 완료한 순간** 태블릿에서 울립니다.
 *
 * **첫 제출에만** 올립니다. 마감 전에 대상을 바꿔 다시 제출하는 것은 새 행동이
 * 아니라 같은 행동의 수정이라, 총성이 두 번 울리면 방이 헷갈립니다.
 *
 * 반드시 `server.nightActions[actorUid]`를 **넣기 전에** 부르세요.
 *
 * @param {MafiaGameState} game 게임 상태
 * @param {string} actorUid 제출한 사람
 * @return {void}
 */
export function bumpNightActionCue(
  game: MafiaGameState,
  actorUid: string,
): void {
  if (game.server.nightActions?.[actorUid] !== undefined) return;
  const action = mafiaRole(game.server.roles[actorUid])?.nightAction;
  if (!action || action === "none") return;
  game.public.nightActionCue = {
    id: (game.public.nightActionCue?.id ?? 0) + 1,
    action,
  };
}

// ===== 밤의 두 구간 =====
//
// 확정(2026-08): 밤은 **차단 구간 → 행동 구간 → 마무리**로 흐릅니다.
// 마담이 막은 사람의 능력은 무효라, 막는 역할의 판정이 끝나야 뒤 역할들의
// 행동이 의미를 가집니다. 앞 구간이 일찍 끝나면 남은 시간을 버리고 곧바로
// 다음 구간을 엽니다.

/**
 * 이번 밤에 행동해야 하는 사람들입니다.
 *
 * [inBlockStage]를 주면 그 구간에 움직이는 사람만 돌려줍니다.
 */
function nightActorUids(
  game: MafiaGameState,
  inBlockStage?: boolean,
): string[] {
  return alivePlayers(game.public.players)
    .filter((player) => {
      const roleId = game.server.roles[player.uid];
      if (!actsAtNight(roleId)) return false;
      if (inBlockStage === undefined) return true;
      return actsInBlockStage(roleId) === inBlockStage;
    })
    .map((player) => player.uid);
}

/** 이번 구간에 제출을 기다리는 사람들입니다. */
function nightStageActorUids(game: MafiaGameState): string[] {
  switch (game.public.nightStage) {
  case "block":
    return nightActorUids(game, true);
  case "action":
    return nightActorUids(game, false);
  default:
    return [];
  }
}

/** 구간별 제한시간입니다. */
function nightStageDurationMs(stage: MafiaNightStageId): number {
  switch (stage) {
  case "block":
    return MAFIA_NIGHT_BLOCK_MS;
  case "action":
    return MAFIA_NIGHT_ACTION_MS;
  default:
    return MAFIA_NIGHT_WAIT_MS;
  }
}

/** 이번 구간의 인원수를 다시 셉니다. */
function refreshNightStageCounts(game: MafiaGameState): void {
  const actions = game.server.nightActions ?? {};
  const stageActors = nightStageActorUids(game);
  game.public.nightStageActorCount = stageActors.length;
  game.public.nightStageSubmittedCount =
    stageActors.filter((uid) => actions[uid] !== undefined).length;
}

/** 이 사람이 지금 구간에 고를 수 있는지입니다. */
export function canActInNightStage(
  game: MafiaGameState,
  uid: string,
): boolean {
  const stage = game.public.nightStage ?? "action";
  if (stage === "wrapUp") return false;
  // 앞 구간에는 막는 역할만 움직입니다. 뒤 구간에는 아직 안 낸 사람 전부입니다
  // (앞 구간에서 넘긴 마담도 여기서 낼 수 있습니다).
  if (stage === "block") return actsInBlockStage(game.server.roles[uid]);
  return true;
}

/** 밤의 한 구간을 시작합니다. */
export function beginMafiaNightStage(
  game: MafiaGameState,
  stage: MafiaNightStageId,
  now: number,
): void {
  game.public.nightStage = stage;
  game.public.turnDeadlineAt = now + nightStageDurationMs(stage);
  refreshNightStageCounts(game);
  // 마무리 구간에 들어서면 조사·추적 결과를 최종값으로 확정합니다.
  if (stage === "wrapUp") finalizeMafiaInvestigations(game);
  touch(game, now);
}

/**
 * 지금 구간에서 기다릴 사람이 없으면 다음 구간으로 넘깁니다.
 *
 * @param {MafiaGameState} game 지금 게임 상태
 * @param {number} now 서버 시각
 * @return {boolean} 구간이 넘어갔으면 true
 */
export function advanceMafiaNightStage(
  game: MafiaGameState,
  now: number,
): boolean {
  const stage = game.public.nightStage ?? "action";
  if (stage === "wrapUp") return false;

  const actions = game.server.nightActions ?? {};
  const pending = nightStageActorUids(game)
    .filter((uid) => actions[uid] === undefined);
  if (pending.length > 0) return false;

  beginMafiaNightStage(game, stage === "block" ? "action" : "wrapUp", now);
  // 앞 구간이 비어 있으면(마담이 없는 판) 뒤 구간도 비어 있을 수 있습니다.
  advanceMafiaNightStage(game, now);
  return true;
}

/** 밤을 시작합니다. 지난 밤의 선택을 모두 지웁니다. */
export function beginMafiaNight(game: MafiaGameState, now: number): void {
  const actors = nightActorUids(game);

  game.public.phase = "night";
  game.public.nightSubmittedCount = 0;
  game.public.nightActorCount = actors.length;
  delete game.public.morningResult;
  delete game.public.voteResult;
  delete game.public.dayEndReason;
  delete game.server.nightActions;
  delete game.server.votes;

  for (const entry of Object.values(game.private)) {
    delete entry.nightTargetUid;
    delete entry.allySelections;
    delete entry.voteTargetUid;
    // 지난 낮에 쓰고 남은 안내입니다. 새 밤에는 지웁니다.
    delete entry.voteBanned;
    delete entry.roleChangedRound;
  }
  // 능력을 막는 역할부터 움직입니다. 없으면 곧바로 행동 구간이 열립니다.
  beginMafiaNightStage(game, "block", now);
  advanceMafiaNightStage(game, now);
}

/** 낮 토론을 시작합니다. 지난 낮의 조기 종료 동의를 지웁니다. */
export function beginMafiaDay(game: MafiaGameState, now: number): void {
  game.public.phase = "day";
  // 토론 시간은 지금 살아 있는 사람 수로 정합니다(확정 2026-08).
  game.public.turnDeadlineAt =
    now + mafiaDiscussionMs(alivePlayers(game.public.players).length);
  game.public.discussionSkipCount = 0;
  delete game.public.dayEndReason;
  delete game.server.discussionSkipVotes;
  for (const entry of Object.values(game.private)) {
    delete entry.discussionSkipVoted;
  }
  touch(game, now);
}

/**
 * 투표로 토론을 끝냅니다 — 안내를 보여 줄 만큼만 남기고 마감을 줄입니다.
 *
 * 확정(2026-08): 과반수가 눌린 순간 곧바로 투표로 넘기지 않고 "토론이 투표로
 * 종료되었습니다"를 보여 줍니다. 새 단계를 만들지 않고 **낮의 마감을
 * 2.5초로 줄여**, 기존 마감 처리(timeout_day)가 그대로 투표를 시작하게
 * 합니다. 다시 눌려도 마감이 밀리지 않도록 이유가 이미 적혀 있으면 넘어갑니다.
 */
export function endMafiaDayByVote(game: MafiaGameState, now: number): void {
  if (game.public.dayEndReason === "vote") return;
  game.public.dayEndReason = "vote";
  game.public.turnDeadlineAt = now + MAFIA_DAY_SKIP_NOTICE_MS;
  touch(game, now);
}

/**
 * 투표를 시작합니다.
 *
 * 마담에게 유혹당한 사람은 이번 투표에 참여하지 못합니다. 그 표는 참여 인원수
 * (`voteEligibleCount`)에서도 빼야 전원 제출로 개표가 됩니다. 본인에게는
 * private으로 알려 주고, 표식은 여기서 소모합니다(다음 낮까지 남지 않습니다).
 */
export function beginMafiaVoting(game: MafiaGameState, now: number): void {
  const bans = game.server.voteBans ?? {};
  const alive = alivePlayers(game.public.players);

  game.public.phase = "voting";
  game.public.turnDeadlineAt = now + MAFIA_VOTE_MS;
  game.public.voteSubmittedCount = 0;
  game.public.voteSubmittedUids = [];
  game.public.voteEligibleCount =
    alive.filter((player) => bans[player.uid] !== true).length;
  delete game.server.votes;
  for (const entry of Object.values(game.private)) {
    delete entry.voteTargetUid;
    delete entry.voteBanned;
  }
  for (const uid of Object.keys(bans)) {
    if (game.public.players[uid]?.status !== "alive") continue;
    game.private[uid] ??= {roleId: game.server.roles[uid]};
    game.private[uid].voteBanned = true;
  }
  delete game.server.voteBans;
  delete game.public.dayEndReason;
  touch(game, now);
}

/** 이번 낮에 투표할 수 없는 사람인지입니다(마담에게 유혹당함). */
export function isMafiaVoteBanned(
  game: MafiaGameState,
  uid: string,
): boolean {
  return game.private[uid]?.voteBanned === true;
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

/**
 * 결과 문구에 쓰는 역할 이름입니다. 모르는 id면 "알 수 없음"입니다.
 *
 * 영매("경찰")·도둑(훔친 직업) 결과가 이 값을 씁니다. 이름은 Dart에도 있지만,
 * 결과 문구는 서버가 만들어 보내는 것이 규칙이라 서버 표에도 둡니다.
 */
export function mafiaRoleDisplayName(roleId: string): string {
  return mafiaRole(roleId)?.displayName ?? "알 수 없음";
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
  case "investigate": {
    const verdict = mafiaInvestigationVerdict(
      game.server.roles[targetUid],
      false,
    );
    recordInvestigation(game, actorUid, targetUid, verdict, round);
    break;
  }
  case "investigateRole":
  case "steal": {
    // 영매·도둑은 **사망자**를 봅니다. 죽은 사람의 신분은 밤 사이에 바뀌지
    // 않으므로 이 값은 잠정값이 아니라 그대로 최종값입니다.
    const verdict = mafiaRoleDisplayName(game.server.roles[targetUid]);
    recordInvestigation(game, actorUid, targetUid, verdict, round);
    break;
  }
  case "track":
    // 추적은 **여기서 알려 줄 수 없습니다.** 대상이 나보다 늦게 고르면 그
    // 순간에는 "방문 없음"이고, 그 값을 보여 주면 거짓말이 됩니다. 행동
    // 구간이 닫힐 때 [finalizeMafiaInvestigations]가 최종값을 넣습니다.
    break;
  default:
    break;
  }
  // touch는 호출부(제출 트랜잭션)가 이미 합니다. now는 서명 일관성용입니다.
  void now;
}

/**
 * 조사·추적 결과를 **최종값으로** 확정합니다(밤의 마무리 구간 시작 시점).
 *
 * 이 시점에는 모든 제출이 끝나 있어, 대상이 누구를 찾아갔는지가 확정됩니다.
 * 그래서 사립탐정의 결과는 여기서 처음 생깁니다. 경찰의 진영 조사는 제출 즉시
 * 알려 준 값과 같지만, 같은 자리(`r{round}`)에 한 번 더 덮어써 두 경로가
 * 어긋나지 않게 합니다.
 */
export function finalizeMafiaInvestigations(game: MafiaGameState): void {
  const actions = game.server.nightActions ?? {};
  const round = game.public.round;
  for (const [actorUid, targetUid] of Object.entries(actions)) {
    if (game.public.players[actorUid]?.status !== "alive") continue;
    const role = mafiaRole(game.server.roles[actorUid]);
    if (!role) continue;
    switch (role.nightAction) {
    case "investigate":
      recordInvestigation(
        game,
        actorUid,
        targetUid,
        mafiaInvestigationVerdict(game.server.roles[targetUid], false),
        round,
      );
      break;
    case "track": {
      const visitedUid = actions[targetUid];
      const verdict = visitedUid ?
        game.public.players[visitedUid]?.nickname ?? "알 수 없음" :
        "방문 없음";
      recordInvestigation(game, actorUid, targetUid, verdict, round);
      break;
    }
    default:
      break;
    }
  }
}

/**
 * 표를 세어 최다 득표 대상을 고릅니다.
 *
 * [weightOf]를 주면 사람마다 표의 무게가 달라집니다(정치인 2표). 밤의 마피아
 * 지목은 전원 1표라 무게를 주지 않습니다.
 */
function tallyVotes(
  votes: Record<string, string>,
  weightOf?: (voterUid: string) => number,
): {
  tally: Record<string, number>;
  leaders: string[];
} {
  const tally: Record<string, number> = {};
  for (const [voterUid, targetUid] of Object.entries(votes)) {
    const weight = weightOf ? weightOf(voterUid) : 1;
    tally[targetUid] = (tally[targetUid] ?? 0) + weight;
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
 *
 * 죽음이 정해지는 순서도 중요합니다.
 *   1. 단계 순서대로 돌며 차단·보호·조사·표적을 모읍니다.
 *   2. 마피아의 지목은 다수결로 **한 명**만 고릅니다.
 *   3. 마지막에 보호와 자기 방어(군인)를 적용해 실제 사망자를 정합니다.
 *
 * 보호·방어 판정을 마지막으로 미루는 이유는, 마피아 다수결 결과가 나오기 전에
 * 는 누가 공격받는지 확정되지 않기 때문입니다.
 */
export function resolveMafiaNight(game: MafiaGameState, now: number): void {
  const actions = game.server.nightActions ?? {};
  const roles = game.server.roles;
  const round = game.public.round;

  const blockedUids = new Set<string>();
  const protectedUids = new Set<string>();
  const framedUids = new Set<string>();
  /** 공격받은 사람 → 공격한 사람들. 오발 판정에 공격자가 필요합니다. */
  const attacks = new Map<string, string[]>();
  const deadUids = new Set<string>();
  let savedCount = 0;
  /** 기자가 취재에 성공한 대상입니다. 없으면 undefined입니다. */
  let exposedUid: string | undefined;

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

  // 마피아 진영의 다수결 지목입니다. 짐승인간은 여기 들어오지 않습니다
  // (해결 단계가 independentAttack이라 혼자 공격합니다).
  const mafiaAttackVotes: Record<string, string> = {};
  /** 이 밤에 실제로 능력이 발동한 사람입니다. 사용 횟수를 셀 때 씁니다. */
  const usedAbility = new Set<string>();

  for (const entry of ordered) {
    const role = entry.role;
    // 차단된 사람의 능력은 무효입니다.
    if (blockedUids.has(entry.actorUid)) continue;
    // 대상이 아직 규칙에 맞는 상태인지 확인합니다. 살아 있는 사람을 고르는
    // 역할은 대상이 죽었으면 무효, 사망자를 고르는 역할(영매·도둑)은 그 반대
    // 입니다. 제출 시점에도 검사하지만, 그 사이에 상태가 바뀔 수 있습니다.
    const targetStatus = game.public.players[entry.targetUid]?.status;
    const wantsDead = role.nightTargetScope === "dead";
    if (wantsDead ? targetStatus !== "dead" : targetStatus !== "alive") continue;

    switch (role.nightAction) {
    case "roleblock":
      // 확정(2026-08): 무엇을 막는지는 역할이 정합니다. 마담은 밤 능력과
      // 다음 낮 투표권을 함께, 건달은 **투표권만** 막습니다.
      if (role.blocksAbility) blockedUids.add(entry.targetUid);
      if (role.blocksTargetVote) {
        game.server.voteBans ??= {};
        game.server.voteBans[entry.targetUid] = true;
      }
      usedAbility.add(entry.actorUid);
      break;
    case "protect":
      protectedUids.add(entry.targetUid);
      usedAbility.add(entry.actorUid);
      break;
    case "frame":
      framedUids.add(entry.targetUid);
      usedAbility.add(entry.actorUid);
      break;
    case "investigate": {
      const verdict = mafiaInvestigationVerdict(
        roles[entry.targetUid],
        framedUids.has(entry.targetUid),
      );
      recordInvestigation(game, entry.actorUid, entry.targetUid, verdict, round);
      usedAbility.add(entry.actorUid);
      break;
    }
    case "investigateRole": {
      // 직업까지 봅니다(영매는 사망자, 정보원은 산 사람). 진영 조사와 달리
      // 프레이머의 조작이 통하지 않습니다 — 직업 자체를 보기 때문입니다.
      const verdict = mafiaRoleDisplayName(roles[entry.targetUid]);
      recordInvestigation(game, entry.actorUid, entry.targetUid, verdict, round);
      usedAbility.add(entry.actorUid);
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
      usedAbility.add(entry.actorUid);
      break;
    }
    case "convert": {
      // 교주의 전향입니다. 마피아는 전향되지 않습니다(같은 어둠의 조직이라
      // 넘어오지 않습니다). 실패해도 **아무 표시를 남기지 않습니다** — 실패가
      // 보이면 대상의 진영이 드러납니다.
      const becomes = role.convertsTargetTo;
      const targetFaction = mafiaRole(roles[entry.targetUid])?.faction;
      if (!becomes || targetFaction === "mafia") break;
      if (roles[entry.targetUid] === becomes) break;
      changeMafiaRole(game, entry.targetUid, becomes, round);
      usedAbility.add(entry.actorUid);
      break;
    }
    case "expose":
      // 기자입니다. 경찰과 달리 **모두가** 보므로 public에 씁니다.
      game.public.revealedRoles ??= {};
      game.public.revealedRoles[entry.targetUid] = roles[entry.targetUid];
      // 아침 발표가 이 사람의 카드를 뒤집어 보여 줍니다(처형 공개와 같은
      // 연출, 죽지는 않습니다).
      exposedUid = entry.targetUid;
      usedAbility.add(entry.actorUid);
      break;
    case "steal": {
      // 도둑입니다. 사망자의 직업을 그대로 가져옵니다(진영까지 바뀝니다).
      const stolen = roles[entry.targetUid];
      if (!stolen || !mafiaRole(stolen)) break;
      changeMafiaRole(game, entry.actorUid, stolen, round);
      recordInvestigation(
        game,
        entry.actorUid,
        entry.targetUid,
        mafiaRoleDisplayName(stolen),
        round,
      );
      usedAbility.add(entry.actorUid);
      break;
    }
    case "eliminate":
      if (entry.phase === "mafiaAttack") {
        // 마피아는 다수결로 한 명만 죽입니다.
        mafiaAttackVotes[entry.actorUid] = entry.targetUid;
      } else {
        // 자경단원·연쇄살인마·짐승인간은 각자 따로 공격합니다.
        // 같은 편은 죽이지 않습니다. **막지 않고 조용히 넘깁니다** — 여기서
        // 오류를 내면 대상이 같은 편이라는 사실이 공격자에게 드러납니다.
        const sameTeam =
          mafiaRole(roles[entry.targetUid])?.faction === role.faction;
        if (sameTeam && role.faction === "mafia") break;
        addAttack(attacks, entry.targetUid, entry.actorUid);
        usedAbility.add(entry.actorUid);
      }
      break;
    default:
      // 아직 처리하지 않는 행동입니다(침묵·감시·표식).
      break;
    }
  }

  // 마피아 공격 판정 — 다수결, 동표면 무작위(확정 규칙).
  const attack = tallyVotes(mafiaAttackVotes);
  if (attack.leaders.length > 0) {
    const targetUid = attack.leaders.length === 1 ?
      attack.leaders[0] :
      attack.leaders[randomInt(attack.leaders.length)];
    addAttack(attacks, targetUid, "");
    for (const actorUid of Object.keys(mafiaAttackVotes)) {
      usedAbility.add(actorUid);
    }
  }

  // 공격 판정 — 보호가 먼저, 그다음 자기 방어(군인)입니다.
  //
  // 자기 방어는 **공격 한 번마다** 하나씩 소모합니다. 같은 밤에 마피아와
  // 짐승인간이 같은 사람을 노렸다면 군인은 한 번만 막고 두 번째에 죽습니다.
  // 반면 의사의 보호는 그 사람을 그 밤 동안 살립니다(공격 수와 무관).
  for (const [targetUid, attackerUids] of attacks) {
    if (protectedUids.has(targetUid)) {
      savedCount += 1;
      continue;
    }
    let survived = true;
    for (let index = 0; index < attackerUids.length; index += 1) {
      if (consumeMafiaDefense(game, targetUid)) continue;
      survived = false;
      break;
    }
    if (survived) {
      savedCount += 1;
      continue;
    }
    deadUids.add(targetUid);
    // 자경단원 오발 — 같은 편을 쏘면 자신도 함께 죽습니다.
    for (const attackerUid of attackerUids) {
      if (!attackerUid) continue;
      const attacker = mafiaRole(roles[attackerUid]);
      if (!attacker?.selfDestructsOnAllyKill) continue;
      if (mafiaRole(roles[targetUid])?.faction !== attacker.faction) continue;
      deadUids.add(attackerUid);
    }
  }

  countAbilityUses(game, usedAbility);

  for (const uid of deadUids) {
    killMafiaPlayer(game, uid, "nightAttack", now);
  }

  game.public.morningResult = {
    deadUids: [...deadUids],
    savedCount,
    endsGame: mafiaAnnouncementEndsGame(game),
    ...(exposedUid ? {exposedUid} : {}),
    resolvedAt: now,
  };
  game.public.phase = "morning";
  delete game.public.nightStage;
  delete game.public.nightStageActorCount;
  delete game.public.nightStageSubmittedCount;
  // 아침 발표는 태블릿 연출이 끝나면 넘어갑니다. 제한시간을 두지 않습니다.
  game.public.turnDeadlineAt = null;
  delete game.server.nightActions;
  touch(game, now);
}

/** 공격 목록에 한 건 더합니다. 공격자가 마피아 다수결이면 빈 문자열입니다. */
function addAttack(
  attacks: Map<string, string[]>,
  targetUid: string,
  attackerUid: string,
): void {
  const list = attacks.get(targetUid);
  if (list) list.push(attackerUid);
  else attacks.set(targetUid, [attackerUid]);
}

/**
 * 자기 방어를 하나 소모합니다. 막아냈으면 true입니다(군인).
 *
 * 소모 기록은 server에만 둡니다. public에 두면 군인이 누군지 드러납니다.
 */
function consumeMafiaDefense(
  game: MafiaGameState,
  uid: string,
): boolean {
  const charges = mafiaRole(game.server.roles[uid])?.defenseCharges ?? 0;
  if (charges <= 0) return false;
  const used = game.server.defenseUsed?.[uid] === true ? 1 : 0;
  if (used >= charges) return false;
  game.server.defenseUsed ??= {};
  game.server.defenseUsed[uid] = true;
  return true;
}

/**
 * 이번 밤에 실제로 발동한 능력의 사용 횟수를 셉니다.
 *
 * **차단당해 불발된 밤은 세지 않습니다.** 자경단원의 한 발이 차단으로 사라지면
 * 규칙이 억울해집니다.
 */
function countAbilityUses(
  game: MafiaGameState,
  usedAbility: Set<string>,
): void {
  for (const uid of usedAbility) {
    const maxUses = mafiaRole(game.server.roles[uid])?.maxUses ?? null;
    if (maxUses === null) continue;
    game.server.abilityUses ??= {};
    const used = (game.server.abilityUses[uid] ?? 0) + 1;
    game.server.abilityUses[uid] = used;
    game.private[uid] ??= {roleId: game.server.roles[uid]};
    game.private[uid].abilityUsesLeft = Math.max(0, maxUses - used);
  }
}

/** 남은 능력 사용 횟수입니다. 제한이 없으면 null입니다. */
export function mafiaAbilityUsesLeft(
  game: MafiaGameState,
  uid: string,
): number | null {
  const maxUses = mafiaRole(game.server.roles[uid])?.maxUses ?? null;
  if (maxUses === null) return null;
  return Math.max(0, maxUses - (game.server.abilityUses?.[uid] ?? 0));
}

// ===== 투표 해결 =====

/**
 * 표를 세어 처형자를 정합니다. **동표면 무처형**입니다(확정 규칙).
 *
 * 밤의 마피아 지목과 다릅니다. 마피아 지목은 동표면 무작위입니다.
 *
 * 정치인의 표는 2표로 셉니다. 그래서 공개되는 득표수는 사람 수가 아니라
 * **표의 무게**입니다 — 2표가 몰린 자리를 보면 정치인이 어디에 찍었는지 유추할
 * 수 있지만, 규칙상 감수하는 노출입니다.
 *
 * 광대·처형자의 단독 승리는 여기서 **예약만** 합니다. 태블릿의 개표·처형 발표
 * 연출이 끝난 뒤([advanceMafiaAfterDeaths])에 게임을 끝냅니다. 즉시 끝내면
 * 처형 장면을 보여 주지 못하고 결과 화면으로 튕깁니다.
 */
export function resolveMafiaVoting(game: MafiaGameState, now: number): void {
  const votes = game.server.votes ?? {};
  const {tally, leaders} = tallyVotes(
    votes,
    (voterUid) => mafiaRole(game.server.roles[voterUid])?.voteWeight ?? 1,
  );
  const eligibleCount = game.public.voteEligibleCount;
  const tie = leaders.length > 1;
  const executedUid = leaders.length === 1 ? leaders[0] : null;

  if (executedUid) {
    const lynchWinners = lynchWinnerUids(game, executedUid);
    killMafiaPlayer(game, executedUid, "execution", now);
    // 처형자 신분은 공개합니다(확정 규칙).
    game.public.revealedRoles ??= {};
    game.public.revealedRoles[executedUid] = game.server.roles[executedUid];
    if (lynchWinners.length > 0) {
      game.server.pendingNeutralWinUids = lynchWinners;
    }
  }

  game.public.voteResult = {
    tally,
    executedUid,
    tie,
    abstainCount: Math.max(0, eligibleCount - Object.keys(votes).length),
    endsGame: mafiaAnnouncementEndsGame(game),
    resolvedAt: now,
  };
  game.public.phase = "voteResult";
  // 개표·처형 발표는 태블릿 연출이 끝나면 넘어갑니다.
  game.public.turnDeadlineAt = null;
  delete game.server.votes;
  touch(game, now);
}

/**
 * 이 처형으로 단독 승리한 사람입니다. 없으면 빈 배열입니다.
 *
 * 두 가지가 겹칠 수 있습니다 — 처형된 사람이 광대이면서, 그 사람을 목표로 받은
 * 처형자가 살아 있는 경우입니다. 그때는 둘 다 이깁니다.
 */
function lynchWinnerUids(
  game: MafiaGameState,
  executedUid: string,
): string[] {
  const winners: string[] = [];

  // 광대 — 자신이 처형되면 승리합니다.
  if (mafiaRole(game.server.roles[executedUid])?.winCondition ===
      "lynchedSelf") {
    winners.push(executedUid);
  }

  // 처형자 — 목표가 처형되면 승리합니다. 본인이 살아 있어야 합니다.
  for (const [uid, targetUid] of
    Object.entries(game.server.executionerTargets ?? {})) {
    if (targetUid !== executedUid) continue;
    if (game.public.players[uid]?.status !== "alive") continue;
    if (mafiaRole(game.server.roles[uid])?.winCondition !== "lynchTarget") {
      // 도둑에게 직업을 빼앗기거나 전향된 뒤라면 더 이상 처형자가 아닙니다.
      continue;
    }
    winners.push(uid);
  }
  return winners;
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

/** 승패 판정 결과입니다. 진영과 **실제로 이긴 사람**을 함께 담습니다. */
export interface MafiaOutcome {
  winner: MafiaFactionId;
  /** 이긴 사람입니다. 진영 승리면 그 진영 전원(사망자 포함)입니다. */
  winnerUids: string[];
  reason: NonNullable<MafiaPublicState["finishReason"]>;
}

/** 그 역할이 교단(교주·광신도)인지입니다. */
function isCultRole(roleId: string): boolean {
  return mafiaRole(roleId)?.winCondition === "factionDominance";
}

/** 그 역할이 혼자 최후까지 남아야 이기는 역할인지입니다(연쇄살인마). */
function isLastStandingRole(roleId: string): boolean {
  return mafiaRole(roleId)?.winCondition === "lastStanding";
}

/** 그 역할을 가진 모든 사람입니다(사망자 포함). 승자 명단에 씁니다. */
function uidsWhere(
  roles: Record<string, string>,
  match: (roleId: string) => boolean,
): string[] {
  return Object.keys(roles).filter((uid) => match(roles[uid]));
}

/**
 * 승리 진영입니다. 아직 끝나지 않았으면 null입니다.
 *
 * 판정 순서가 규칙입니다. 개별 승리를 먼저 봅니다 — 살아남은 사람이 전부 교단
 * 이면 그것은 시민팀 승리가 아니라 교단 승리입니다.
 *
 *   1. 살아 있는 사람이 **모두 교단**이면 교단 승리
 *   2. 살아 있는 사람이 **연쇄살인마뿐**이면 연쇄살인마 승리
 *   3. 마피아·연쇄살인마·교단이 모두 없으면 시민 승리
 *   4. 마피아가 나머지와 같거나 많으면 마피아 승리
 *      (단, 살아 있는 연쇄살인마·교단이 없어야 합니다 — 아직 판을 뒤집을
 *       사람이 남아 있으면 마피아의 승리가 확정되지 않습니다)
 *
 * 광대·처형자는 여기서 판정하지 않습니다. 그 둘은 **처형되는 순간**
 * ([resolveMafiaVoting])에 정해집니다.
 */
export function checkMafiaWinner(game: MafiaGameState): MafiaOutcome | null {
  const roles = game.server.roles;
  const alive = alivePlayers(game.public.players);

  let mafiaCount = 0;
  let cultCount = 0;
  let killerCount = 0;
  for (const player of alive) {
    const roleId = roles[player.uid];
    if (mafiaRole(roleId)?.faction === "mafia") mafiaCount += 1;
    else if (isCultRole(roleId)) cultCount += 1;
    else if (isLastStandingRole(roleId)) killerCount += 1;
  }
  const otherCount = alive.length - mafiaCount;

  if (cultCount > 0 && cultCount === alive.length) {
    return {
      winner: "neutral",
      winnerUids: uidsWhere(roles, isCultRole),
      reason: "neutralWin",
    };
  }
  if (killerCount > 0 && killerCount === alive.length) {
    return {
      winner: "neutral",
      winnerUids: alive.map((player) => player.uid),
      reason: "neutralWin",
    };
  }
  // 아직 판을 뒤집을 사람이 남아 있으면 진영 승리는 확정되지 않습니다.
  if (cultCount > 0 || killerCount > 0) return null;

  if (mafiaCount === 0) {
    return {
      winner: "citizen",
      winnerUids: uidsWhere(roles, (id) => mafiaRole(id)?.faction === "citizen"),
      reason: "citizenWin",
    };
  }
  if (mafiaCount >= otherCount) {
    return {
      winner: "mafia",
      winnerUids: uidsWhere(roles, (id) => mafiaRole(id)?.faction === "mafia"),
      reason: "mafiaWin",
    };
  }
  return null;
}

/**
 * 게임을 끝냅니다. 끝나는 순간 전원의 신분을 공개합니다.
 *
 * [winnerUids]를 주면 그 목록을 그대로 씁니다. 주지 않으면 승리 진영 전원입니다.
 * 중립의 개별 승리는 "그 진영 전원"이 성립하지 않아(죽은 광대까지 승자가 됩니다)
 * 반드시 목록을 넘겨야 합니다.
 */
export function finishMafiaGame(
  game: MafiaGameState,
  winner: MafiaFactionId | null,
  reason: NonNullable<MafiaPublicState["finishReason"]>,
  now: number,
  winnerUids?: string[],
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

  if (winnerUids) {
    game.public.winnerUids = [...winnerUids];
  } else {
    game.public.winnerUids = winner === null ? [] :
      Object.keys(game.server.roles).filter((uid) =>
        mafiaRole(game.server.roles[uid])?.faction === winner);
  }
  delete game.server.pendingNeutralWinUids;
  touch(game, now);
}

/**
 * 지금 발표가 끝나면 게임이 끝나는지입니다.
 *
 * 사망·처형을 이미 반영한 상태에서 판정하므로, 발표가 끝날 때
 * [advanceMafiaAfterDeaths]가 내리는 결론과 같습니다. **판정을 앞당기는 것이
 * 아니라**, 태블릿이 다음 단계 안내('밤이 되었습니다' 등)를 띄우지 않도록
 * 미리 알려 주는 힌트입니다.
 * @param {MafiaGameState} game 지금 게임 상태
 * @return {boolean} 이 발표가 마지막이면 true
 */
export function mafiaAnnouncementEndsGame(game: MafiaGameState): boolean {
  const pending = game.server.pendingNeutralWinUids;
  if (pending && pending.length > 0) return true;
  return checkMafiaWinner(game) !== null;
}

/**
 * 승패를 확인해 끝났으면 마무리하고, 아니면 다음 단계로 넘깁니다.
 *
 * 판정 시점은 두 곳입니다: 아침 발표 직후, 처형 발표 직후.
 *
 * 처형으로 정해진 단독 승리(광대·처형자)를 **가장 먼저** 봅니다. 광대가
 * 처형되면 그 판은 광대의 것이고, 같은 처형으로 마피아가 전멸했더라도 시민팀
 * 승리로 덮어써서는 안 됩니다.
 */
export function advanceMafiaAfterDeaths(
  game: MafiaGameState,
  next: "day" | "night",
  now: number,
): MafiaFactionId | null {
  const pending = game.server.pendingNeutralWinUids;
  if (pending && pending.length > 0) {
    finishMafiaGame(game, "neutral", "neutralWin", now, pending);
    return "neutral";
  }

  const outcome = checkMafiaWinner(game);
  if (outcome) {
    finishMafiaGame(
      game,
      outcome.winner,
      outcome.reason,
      now,
      outcome.winnerUids,
    );
    return outcome.winner;
  }
  if (next === "day") {
    beginMafiaDay(game, now);
  } else {
    game.public.round += 1;
    beginMafiaNight(game, now);
  }
  return null;
}
