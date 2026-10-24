/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

import {HttpsError} from "firebase-functions/v2/https";
import {gameRandomInt} from "../common/transaction-random.js";
import {
  YutGameId, YutGameState, YutPiece, YutPlayer, YutPoolEntry, YutPrivatePlayer,
  YutPublicState, YutResultName, YutRoll, YutTeam,
} from "./types.js";

/** Time for one throw, one hidden choice round or one tablet move. */
export const YUT_TURN_MS = 30000;
/** Board node 0 is the start corner; a piece that leaves it goes home. */
export const YUT_START_NODE = 0;
export const YUT_CENTER_NODE = 22;
export const YUT_HOME = 29;

/** 이만큼 말이 나면(집에 들어오면) 승리합니다. 말은 그대로 4개씩 씁니다. */
export const YUT_WIN_PIECES = 2;
const STRATEGY_TEAMS = ["blue", "white"] as const;
const CLASSIC_TEAMS = ["east", "south", "west", "north"] as const;

export interface YutStartPlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
}

/** Classic Yut supports 2–4 players; the two strategy products require four. */
export function createYutGame(gameId: YutGameId, players: YutStartPlayer[], now: number): YutGameState {
  assertStartPlayers(gameId, players);
  const strategy = gameId !== "yut";
  const publicPlayers = Object.fromEntries(players.map((player) => [player.uid, {
    ...player,
    team: strategy ? STRATEGY_TEAMS[player.seatIndex % 2] : CLASSIC_TEAMS[player.seatIndex],
    status: "alive" as const,
  } satisfies YutPlayer]));
  const first = [...players].sort((a, b) => a.seatIndex - b.seatIndex)[0];
  const pieces: YutPublicState["pieces"] = {};
  if (strategy) {
    for (const team of STRATEGY_TEAMS) pieces[team] = Array.from({length: 4}, (_, id) => readyPiece(id));
  } else {
    for (const player of players) pieces[player.uid] = Array.from({length: 4}, (_, id) => readyPiece(id));
  }
  const privateState: Record<string, YutPrivatePlayer> = Object.fromEntries(
    players.map(({uid}) => [uid, {choiceSubmitted: false}]),
  );
  return {
    public: {
      gameType: gameId,
      status: "playing",
      phase: strategy ? "selecting" : "rolling",
      round: 1,
      revision: 0,
      turnUid: first.uid,
      turnTeam: strategy ? publicPlayers[first.uid].team : null,
      turnDeadlineAt: now + YUT_TURN_MS,
      choiceCount: 0,
      players: publicPlayers,
      pieces,
      pool: [],
      lastRoll: null,
      lastMove: null,
      history: [],
      winnerUid: null,
      winningTeam: null,
      startedAt: now,
      updatedAt: now,
    },
    private: privateState,
    server: {},
  };
}

/**
 * RTDB drops empty arrays, so a state read back from the database may miss
 * `pool`, `history` or a ready piece's `path`. Every mutation calls this first.
 */
export function normalizeYutGame(game: YutGameState): YutGameState {
  const pub = game.public;
  pub.pool = Array.isArray(pub.pool) ? pub.pool.filter(Boolean) : [];
  pub.history = Array.isArray(pub.history) ? pub.history.filter(Boolean) : [];
  pub.lastMove = pub.lastMove ?? null;
  pub.lastRoll = pub.lastRoll ?? null;
  pub.pieces = pub.pieces ?? {};
  for (const [owner, pieces] of Object.entries(pub.pieces)) {
    const list: YutPiece[] = Array.isArray(pieces) ? pieces : Object.values(pieces ?? {}) as YutPiece[];
    pub.pieces[owner] = list
      .filter(Boolean)
      .map((piece) => ({...piece, path: Array.isArray(piece.path) ? [...piece.path] : []}));
  }
  game.private = game.private ?? {};
  game.server = game.server ?? {};
  return game;
}

export function makeClassicRoll(actorUid: string, now: number): YutRoll {
  const stickUps = Array.from({length: 4}, () => gameRandomInt(2) === 1);
  return makeRoll(stickUps, now, actorUid, false);
}

export function makeStrategyRoll(
  choices: Record<string, boolean>,
  now: number,
): YutRoll {
  const stickUps = Object.keys(choices).sort().map((uid) => choices[uid]);
  return makeRoll(stickUps, now, null, true, choices);
}

function makeRoll(
  stickUps: boolean[], now: number, actorUid: string | null,
  strategy: boolean, choices?: Record<string, boolean>,
): YutRoll {
  // stickUps[i] === true → 둥근 앞면(× 세 개)이 위, false → 평평한 뒷면(배)이 위.
  // 전통 규칙대로 결과는 위로 나온 '평평한 뒷면' 개수로 셉니다.
  //   배 1 = 도, 2 = 개, 3 = 걸, 4 = 윷, 0(둥근 앞면 4개) = 모
  const upCount = stickUps.filter(Boolean).length;
  const flatCount = stickUps.length - upCount;
  // 빽도: 배가 하나만 나왔고, 일반판은 그게 로고가 찍힌 첫 번째 윷일 때입니다.
  const backDo = flatCount === 1 && (strategy || stickUps[0] === false);
  const name: YutResultName = backDo ? "backDo" : resultForFlatCount(flatCount);
  return {
    name,
    steps: stepsFor(name),
    upCount,
    stickUps,
    backDo,
    createdAt: now,
    actorUid,
    ...(choices ? {revealedChoices: choices} : {}),
  };
}

function stepsFor(name: YutResultName): number {
  return name === "backDo" ? -1 : name === "mo" ? 5 : name === "yut" ? 4 :
    name === "geol" ? 3 : name === "gae" ? 2 : 1;
}

function resultForFlatCount(count: number): YutResultName {
  return count === 0 ? "mo" : count === 1 ? "do" : count === 2 ? "gae" :
    count === 3 ? "geol" : "yut";
}

/** Classic: the current player throws all four sticks. */
export function applyClassicRoll(game: YutGameState, uid: string, now: number): YutRoll {
  const pub = game.public;
  if (pub.gameType !== "yut" || pub.status !== "playing" || pub.phase !== "rolling" || pub.turnUid !== uid) {
    throw new HttpsError("failed-precondition", "현재 윷을 던질 차례가 아닙니다.");
  }
  const roll = makeClassicRoll(uid, now);
  addRoll(game, roll, now);
  return roll;
}

/** Strategy: records one hidden side and reveals when everyone has chosen. */
export function submitStrategyChoice(game: YutGameState, uid: string, front: boolean, now: number): void {
  const pub = game.public;
  if (pub.gameType === "yut" || pub.status !== "playing" || pub.phase !== "selecting") {
    throw new HttpsError("failed-precondition", "앞면 또는 뒷면을 선택할 수 없습니다.");
  }
  const entry = game.private[uid];
  if (!entry) throw new HttpsError("permission-denied", "이번 차례 참가자가 아닙니다.");
  if (entry.choiceSubmitted) throw new HttpsError("already-exists", "이번 차례 선택을 이미 제출했습니다.");
  entry.choice = front;
  entry.choiceSubmitted = true;
  pub.choiceCount = Object.values(game.private).filter((player) => player.choiceSubmitted).length;
  if (pub.choiceCount >= Object.keys(game.private).length) resolveStrategyChoices(game, now);
  else touch(game, now);
}

/** Reveals all submitted sides only after every connected player has chosen. */
export function resolveStrategyChoices(game: YutGameState, now: number): void {
  const alive = alivePlayers(game);
  const choices: Record<string, boolean> = {};
  for (const player of alive) {
    const choice = game.private[player.uid]?.choice;
    if (typeof choice !== "boolean") return;
    choices[player.uid] = choice;
  }
  game.public.choiceCount = alive.length;
  addRoll(game, makeStrategyRoll(choices, now), now);
}

/**
 * Adds a throw to this turn's pool. Yut and mo throw again before moving;
 * everything else hands the pool to the tablet.
 */
function addRoll(game: YutGameState, roll: YutRoll, now: number): void {
  const pub = game.public;
  pub.lastRoll = roll;
  pub.history = [roll, ...pub.history].slice(0, 8);
  pub.pool = [...pub.pool, {name: roll.name, steps: roll.steps}];
  if (roll.name === "yut" || roll.name === "mo") {
    beginThrow(game, now);
  } else {
    enterMoving(game, now);
  }
  touch(game, now);
}

/** Starts another throw for the same side, keeping the unused pool. */
function beginThrow(game: YutGameState, now: number): void {
  const pub = game.public;
  pub.phase = pub.gameType === "yut" ? "rolling" : "selecting";
  pub.choiceCount = 0;
  pub.turnDeadlineAt = now + YUT_TURN_MS;
  if (pub.gameType !== "yut") resetChoices(game);
}

/** Drops results no piece can use; an empty pool ends the turn. */
function enterMoving(game: YutGameState, now: number): void {
  const pub = game.public;
  const owner = turnOwnerKey(pub);
  pub.pool = pub.pool.filter((entry) => isPoolEntryUsable(pub.pieces[owner] ?? [], entry));
  if (pub.pool.length === 0) {
    endTurn(game, now);
    return;
  }
  pub.phase = "moving";
  pub.choiceCount = 0;
  pub.turnDeadlineAt = now + YUT_TURN_MS;
}

export function isPoolEntryUsable(pieces: YutPiece[], entry: YutPoolEntry): boolean {
  return pieces.some((piece) => canPieceUse(piece, entry));
}

export function canPieceUse(piece: YutPiece, entry: YutPoolEntry): boolean {
  if (piece.status === "finished") return false;
  return entry.steps >= 0 || piece.status === "onBoard";
}

/** Applies one pooled result to one piece (and every piece stacked with it). */
export function moveYutPiece(
  game: YutGameState,
  pieceId: number,
  poolIndex: number,
  now: number,
): Record<string, unknown> {
  const pub = game.public;
  if (pub.status !== "playing" || pub.phase !== "moving") {
    throw new HttpsError("failed-precondition", "지금은 말을 옮길 수 없습니다.");
  }
  const entry = pub.pool[poolIndex];
  if (!entry) throw new HttpsError("invalid-argument", "사용할 윷을 골라주세요.");
  const ownerKey = turnOwnerKey(pub);
  const ownPieces = pub.pieces[ownerKey] ?? [];
  const selected = ownPieces.find((piece) => piece.id === pieceId);
  if (!selected || !canPieceUse(selected, entry)) {
    throw new HttpsError("invalid-argument", entry.steps < 0 ?
      "백도는 판 위의 말만 움직일 수 있습니다." : "움직일 말을 골라주세요.");
  }

  const carried = selected.status === "onBoard" ?
    ownPieces.filter((piece) => piece.status === "onBoard" && piece.position === selected.position) :
    [selected];
  const origin = selected.status === "onBoard" ? selected.position : -1;
  const before = selected.path.length;
  const movedPath = advancePath(selected.path, entry.steps);
  const destination = movedPath[movedPath.length - 1] ?? -1;
  for (const piece of carried) {
    piece.path = [...movedPath];
    piece.position = destination === YUT_HOME ? YUT_HOME : destination;
    piece.status = destination === YUT_HOME ? "finished" : destination < 0 ? "ready" : "onBoard";
  }
  const visited = entry.steps < 0 ?
    [origin, destination] :
    [origin, ...movedPath.slice(Math.max(0, before))];

  const captured: {owner: string; pieceIds: number[]}[] = [];
  if (destination >= 0 && destination < YUT_HOME) {
    for (const [owner, pieces] of Object.entries(pub.pieces)) {
      if (owner === ownerKey) continue;
      const hits = pieces.filter((piece) => piece.status === "onBoard" && piece.position === destination);
      if (hits.length === 0) continue;
      for (const piece of hits) {
        piece.position = -1;
        piece.path = [];
        piece.status = "ready";
      }
      captured.push({owner, pieceIds: hits.map((piece) => piece.id)});
    }
  }

  pub.pool.splice(poolIndex, 1);
  const extraThrow = captured.length > 0;
  pub.lastMove = {
    owner: ownerKey,
    pieceIds: carried.map((piece) => piece.id),
    path: visited,
    result: entry.name,
    captured,
    extraThrow,
    createdAt: now,
  };
  touch(game, now);

  if (ownPieces.filter((piece) => piece.status === "finished").length >= YUT_WIN_PIECES) {
    const strategy = pub.gameType !== "yut";
    const winnerUid = strategy ? null : ownerKey;
    const team = strategy ? ownerKey as YutTeam : pub.players[ownerKey]?.team ?? null;
    finishYutGame(game, now, "winner", winnerUid, team);
    return {success: true, type: "winner", winnerUid, winningTeam: team, revision: pub.revision};
  }

  if (extraThrow) beginThrow(game, now);
  else enterMoving(game, now);
  return {
    success: true,
    type: "pieceMoved",
    from: origin,
    to: destination,
    movedPieceIds: carried.map((piece) => piece.id),
    captured,
    extraThrow,
    revision: pub.revision,
  };
}

/** The tablet's timeout move: the first usable result on the leading piece. */
export function autoMoveYut(game: YutGameState, now: number): void {
  const pub = game.public;
  const pieces = pub.pieces[turnOwnerKey(pub)] ?? [];
  const ordered = [...pieces].sort((a, b) =>
    (b.status === "onBoard" ? 1 : 0) - (a.status === "onBoard" ? 1 : 0) || b.path.length - a.path.length);
  for (let index = 0; index < pub.pool.length; index += 1) {
    const piece = ordered.find((candidate) => canPieceUse(candidate, pub.pool[index]));
    if (piece) {
      moveYutPiece(game, piece.id, index, now);
      return;
    }
  }
  pub.pool = [];
  endTurn(game, now);
  touch(game, now);
}

/** Hands the turn to the other team or the next classic player. */
function endTurn(game: YutGameState, now: number): void {
  const pub = game.public;
  pub.pool = [];
  pub.round += 1;
  if (pub.gameType === "yut") {
    pub.turnUid = nextClassicPlayer(pub, pub.turnUid ?? "");
    pub.phase = "rolling";
    pub.choiceCount = 0;
    pub.turnDeadlineAt = now + YUT_TURN_MS;
    return;
  }
  const nextTeam: YutTeam = pub.turnTeam === "blue" ? "white" : "blue";
  const nextUid = nextTeamPlayer(pub, nextTeam);
  if (!nextUid) {
    finishYutGame(game, now, "insufficientPlayers");
    return;
  }
  pub.turnTeam = nextTeam;
  pub.turnUid = nextUid;
  beginThrow(game, now);
}

export function finishYutGame(
  game: YutGameState,
  now: number,
  reason: "winner" | "manual" | "insufficientPlayers",
  winnerUid: string | null = null,
  winningTeam: YutTeam | null = null,
): void {
  const pub = game.public;
  pub.status = "finished";
  pub.phase = "finished";
  pub.finishReason = reason;
  pub.turnUid = null;
  pub.turnTeam = null;
  pub.turnDeadlineAt = null;
  pub.pool = [];
  pub.winnerUid = winnerUid;
  pub.winningTeam = winningTeam;
  pub.revision += 1;
  pub.updatedAt = now;
  game.private = {};
}

/**
 * The 29-node board. Node 0 is the start corner (bottom right), the outer
 * ring runs 1–19 counter-clockwise with corners 5, 10 and 15, and the two
 * diagonals are 5→20→21→22→23→24→15 and 10→25→26→22→27→28→0.
 *
 * A piece that starts its move on corner 5 or 10 takes the diagonal, and
 * one that starts on the centre heads straight for home. Any step past node
 * 0 takes the piece home. Back-do retraces the last step.
 */
export function advancePath(path: number[], steps: number): number[] {
  const next = [...path];
  if (steps < 0) {
    if (next.length > 1) next.pop();
    else if (next[0] === YUT_START_NODE) next[0] = 19;
    else if (next.length === 1) next[0] = YUT_START_NODE;
    return next;
  }
  const startNode = next[next.length - 1];
  for (let step = 0; step < steps; step += 1) {
    const position = next[next.length - 1];
    if (position === undefined) {
      next.push(1);
      continue;
    }
    if (position === YUT_HOME) break;
    const isFirst = step === 0 && position === startNode;
    next.push(nextYutNode(position, next[next.length - 2], isFirst));
    if (next[next.length - 1] === YUT_HOME) break;
  }
  return next;
}

export function nextYutNode(position: number, previous: number | undefined, startsHere: boolean): number {
  switch (position) {
  case 0: return YUT_HOME;
  case 5: return startsHere ? 20 : 6;
  case 10: return startsHere ? 25 : 11;
  case 19: return 0;
  case 20: return 21;
  case 21: return 22;
  case 22: return startsHere || previous !== 21 ? 27 : 23;
  case 23: return 24;
  case 24: return 15;
  case 25: return 26;
  case 26: return 22;
  case 27: return 28;
  case 28: return 0;
  default: return position + 1;
  }
}

export function markPlayerEliminated(game: YutGameState, uid: string, now: number): void {
  normalizeYutGame(game);
  const pub = game.public;
  const player = pub.players[uid];
  if (!player || player.status !== "alive") return;
  player.status = "eliminated";
  delete game.private[uid];
  const alive = alivePlayers(game);
  const teams = new Set(alive.map((entry) => entry.team));
  if (alive.length < 2 || (pub.gameType !== "yut" && teams.size < 2)) {
    finishYutGame(game, now, "insufficientPlayers");
    return;
  }
  if (pub.phase === "selecting") {
    pub.choiceCount = alive.filter((entry) => game.private[entry.uid]?.choiceSubmitted).length;
    resolveStrategyChoices(game, now);
  } else if (pub.turnUid === uid) {
    if (pub.gameType === "yut") {
      pub.pool = [];
      pub.turnUid = nextClassicPlayer(pub, uid);
      pub.phase = "rolling";
    } else {
      const teammate = alive.find((entry) => entry.team === pub.turnTeam);
      if (!teammate) finishYutGame(game, now, "insufficientPlayers");
      else pub.turnUid = teammate.uid;
    }
  }
  pub.revision += 1;
  pub.updatedAt = now;
  pub.turnDeadlineAt = pub.status === "playing" ? now + YUT_TURN_MS : null;
}

export function finishForInsufficientPlayers(game: YutGameState, now: number): void {
  if (game.public.status === "playing") finishYutGame(game, now, "insufficientPlayers");
}

/** Server-side timeout: random hidden choices, an automatic throw or move. */
export function timeoutYutTurn(game: YutGameState, now: number): void {
  const pub = game.public;
  if (pub.status !== "playing" || !pub.turnDeadlineAt || now < pub.turnDeadlineAt) return;
  if (pub.phase === "selecting") {
    for (const entry of Object.values(game.private)) {
      if (entry.choiceSubmitted) continue;
      entry.choice = gameRandomInt(2) === 1;
      entry.choiceSubmitted = true;
    }
    resolveStrategyChoices(game, now);
  } else if (pub.phase === "rolling" && pub.turnUid) {
    applyClassicRoll(game, pub.turnUid, now);
  } else if (pub.phase === "moving") {
    autoMoveYut(game, now);
  }
}

export function turnOwnerKey(pub: YutPublicState): string {
  return pub.gameType === "yut" ? String(pub.turnUid) : String(pub.turnTeam);
}

function resetChoices(game: YutGameState): void {
  game.private = Object.fromEntries(alivePlayers(game).map(({uid}) =>
    [uid, {choiceSubmitted: false}],
  ));
}

function nextClassicPlayer(pub: YutPublicState, uid: string): string {
  const players = alivePlayers({public: pub} as YutGameState);
  const index = players.findIndex((player) => player.uid === uid);
  return players[(index + 1 + players.length) % players.length]?.uid ?? uid;
}

/** Teammates take turns choosing pieces; the last mover of the team is skipped. */
function nextTeamPlayer(pub: YutPublicState, team: YutTeam): string | undefined {
  const players = alivePlayers({public: pub} as YutGameState).filter((player) => player.team === team);
  if (players.length === 0) return undefined;
  const turns = (pub.round - 1) >> 1;
  return players[turns % players.length].uid;
}

function alivePlayers(game: Pick<YutGameState, "public">): YutPlayer[] {
  return Object.values(game.public.players).filter((player) => player.status === "alive")
    .sort((a, b) => a.seatIndex - b.seatIndex);
}

function readyPiece(id: number): YutPiece {
  return {id, position: -1, path: [], status: "ready"};
}

function touch(game: YutGameState, now: number): void {
  game.public.revision += 1;
  game.public.updatedAt = now;
}

function assertStartPlayers(gameId: YutGameId, players: YutStartPlayer[]): void {
  const seats = players.map((player) => player.seatIndex).sort((a, b) => a - b);
  const strategy = gameId !== "yut";
  const validCount = strategy ? players.length === 4 : players.length >= 2 && players.length <= 4;
  if (!validCount || seats.some((seat, index) => seat !== index)) {
    const message = strategy ? "전략 윷놀이는 네 명의 자리를 먼저 정해주세요." : "윷놀이는 두 명에서 네 명까지 자리를 정해주세요.";
    throw new HttpsError("failed-precondition", message);
  }
}
