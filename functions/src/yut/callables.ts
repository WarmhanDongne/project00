/* eslint-disable require-jsdoc, valid-jsdoc, max-len */
import {getDatabase} from "firebase-admin/database";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {assertControllerSession} from "../room/controller-session.js";
import {assertStartGameSnapshot, startGameFingerprint} from "../common/start-game-transaction.js";
import {replayGameCommand, runGameCommandTransaction} from "../game-interruption/game-command-transaction.js";
import {applyClassicRoll, createYutGame, finishYutGame, moveYutPiece, normalizeYutGame, submitStrategyChoice, timeoutYutTurn} from "./game.js";
import {YutGameId, YutGameState, YutRoom} from "./types.js";

const REGION = "asia-northeast3";
const IDS = new Set<YutGameId>(["yut", "strategy_yut", "strategy_yut_edition"]);
type Data = {roomCode?: unknown; gameId?: unknown; restart?: unknown; commandId?: unknown; front?: unknown; pieceId?: unknown; poolIndex?: unknown; controllerSessionId?: unknown};

export const game_yut_start_game = onCall<Data>({region: REGION}, async (request) => {
  const uid = requireUid(request.auth?.uid);
  const roomCode = parseRoomCode(request.data?.roomCode);
  const gameId = parseGameId(request.data?.gameId);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  const replay = await replayGameCommand(ref, request, "game_yut_start_game");
  if (replay) return replay;
  const room = (await ref.get()).val() as YutRoom | null;
  if (!room) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
  const fingerprint = startGameFingerprint(room);
  assertControllerSession(room, uid, request.data?.controllerSessionId);
  if (room.selectedGame !== gameId) throw new HttpsError("failed-precondition", "선택한 게임과 일치하지 않습니다.");
  const restart = request.data?.restart === true;
  if (!restart && room.status !== "seating") throw new HttpsError("failed-precondition", "자리 배치를 먼저 완료해주세요.");
  if (restart && room.game?.public.status !== "finished") throw new HttpsError("failed-precondition", "진행 중인 게임은 다시 시작할 수 없습니다.");
  const players = Object.entries(room.players ?? {}).map(([playerUid, player]) => ({
    uid: playerUid,
    nickname: String(player.nickname ?? "Player"),
    characterId: String(player.characterId ?? ""),
    seatIndex: Number(player.seatIndex),
  })).filter((player) => Number.isInteger(player.seatIndex)).sort((a, b) => a.seatIndex - b.seatIndex);
  const game = createYutGame(gameId, players, Date.now());
  const transaction = await runGameCommandTransaction(ref, request, "game_yut_start_game", (raw) => {
    if (!raw) return raw;
    const current = raw as YutRoom;
    assertControllerSession(current, uid, request.data?.controllerSessionId);
    assertStartGameSnapshot(fingerprint, current);
    if (current.game?.public.status === "playing" && !restart) throw new HttpsError("already-exists", "이미 게임이 진행 중입니다.");
    current.game = game;
    return current;
  }, () => ({success: true, roomCode, turnUid: game.public.turnUid}));
  if (!transaction.committed) throw new HttpsError("aborted", "게임을 시작하지 못했습니다.");
  return transaction.operationResult ?? {success: true};
});

export const game_yut_roll = onCall<Data>({region: REGION}, (request) => playerMutation(request, "game_yut_roll", (game, uid, now) => {
  const roll = applyClassicRoll(game, uid, now);
  return {success: true, result: roll.name, upCount: roll.upCount};
}));

export const game_yut_submit_choice = onCall<Data>({region: REGION}, (request) => playerMutation(request, "game_yut_submit_choice", (game, uid, now) => {
  if (typeof request.data?.front !== "boolean") throw new HttpsError("invalid-argument", "앞면 또는 뒷면을 골라주세요.");
  submitStrategyChoice(game, uid, request.data.front, now);
  return {success: true, submitted: true};
}));

/** B안: pieces are placed on the shared tablet, so only the controller moves them. */
export const game_yut_move_piece = onCall<Data>({region: REGION}, (request) => controllerMutation(request, "game_yut_move_piece", (room, now) => {
  if (!Number.isInteger(request.data?.pieceId) || !Number.isInteger(request.data?.poolIndex)) {
    throw new HttpsError("invalid-argument", "말과 윷을 골라주세요.");
  }
  return moveYutPiece(requireGame(room), Number(request.data?.pieceId), Number(request.data?.poolIndex), now);
}));


export const game_yut_timeout_turn = onCall<Data>({region: REGION}, async (request) => {
  const uid = requireUid(request.auth?.uid); const roomCode = parseRoomCode(request.data?.roomCode);
  const ref = getDatabase().ref(`rooms/${roomCode}`);
  const result = await runGameCommandTransaction(ref, request, "game_yut_timeout_turn", (raw, now) => {
    if (!raw) return raw;
    const room = raw as YutRoom; assertControllerSession(room, uid, request.data?.controllerSessionId);
    timeoutYutTurn(requireGame(room), now);
    return room;
  });
  return result.operationResult ?? {success: true};
});

export const game_yut_end_game = onCall<Data>({region: REGION}, (request) => controllerMutation(request, "game_yut_end_game", (room, now) => {
  finishYutGame(requireGame(room), now, "manual"); return {success: true};
}));
import {leaveSessionRequest} from "../game-interruption/leave-request.js";
export const game_yut_leave_game = onCall({region: REGION}, leaveSessionRequest);

function playerMutation(request: CallableRequest<Data>, kind: string, action: (game: YutGameState, uid: string, now: number) => Record<string, unknown>) {
  return mutate(request, kind, (room, uid, now) => {
    if (!room.players?.[uid]) throw new HttpsError("permission-denied", "방 참가자만 조작할 수 있습니다.");
    return action(requireGame(room), uid, now);
  });
}
function controllerMutation(request: CallableRequest<Data>, kind: string, action: (room: YutRoom, now: number) => Record<string, unknown>) {
  return mutate(request, kind, (room, uid, now, data) => {
    assertControllerSession(room, uid, data.controllerSessionId); return action(room, now);
  });
}
async function mutate(request: CallableRequest<Data>, kind: string, action: (room: YutRoom, uid: string, now: number, data: Data) => Record<string, unknown>) {
  const uid = requireUid(request.auth?.uid); const roomCode = parseRoomCode(request.data?.roomCode); const ref = getDatabase().ref(`rooms/${roomCode}`);
  const replay = await replayGameCommand(ref, request, kind); if (replay) return replay;
  let response: Record<string, unknown> | null = null;
  const result = await runGameCommandTransaction(ref, request, kind, (raw, now) => {
    if (!raw) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    response = action(raw as YutRoom, uid, now, request.data ?? {}); return raw;
  }, () => response ?? {success: true});
  return result.operationResult ?? response ?? {success: true};
}
function requireGame(room: YutRoom): YutGameState {
  if (!room.game?.public) throw new HttpsError("failed-precondition", "게임이 시작되지 않았습니다."); return normalizeYutGame(room.game);
}
function parseRoomCode(value: unknown): string {
  const code = typeof value === "string" ? value.trim().toUpperCase() : ""; if (!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/.test(code)) throw new HttpsError("invalid-argument", "방 코드가 올바르지 않습니다."); return code;
}
function parseGameId(value: unknown): YutGameId {
  if (typeof value !== "string" || !IDS.has(value as YutGameId)) throw new HttpsError("invalid-argument", "윷놀이 게임을 선택해주세요."); return value as YutGameId;
}
function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다."); return uid;
}
