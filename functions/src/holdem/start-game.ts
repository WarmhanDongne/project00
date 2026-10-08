/* eslint-disable max-len, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {assertStartGameSnapshot, startGameFingerprint} from "../common/start-game-transaction.js";
import {runPrimedTransaction} from "../room/room-transaction.js";
import {createHoldemGame, HoldemStartPlayer} from "./game.js";
import {HoldemRoom} from "./types.js";
import {
  assertHoldemController,
  assertHoldemRoom,
  HOLDEM_REGION,
  holdemHttpsError,
  parseHoldemRoomCode,
  requireHoldemUid,
} from "./validation.js";

type Data = {roomCode?: unknown; restart?: unknown; controllerSessionId?: unknown; warmup?: unknown};

/** 태블릿 진행자가 홀덤 토너먼트를 시작합니다. */
export const game_holdem_start_game = onCall<Data>({region: HOLDEM_REGION}, async (request) => {
  if (request.data?.warmup === true) {
    return {success: true, type: "warmup"};
  }
  const uid = requireHoldemUid(request);
  const roomCode = parseHoldemRoomCode(request.data?.roomCode);
  const restart = request.data?.restart === true;
  const roomRef = getDatabase().ref(`rooms/${roomCode}`);
  const snapshot = await roomRef.get();
  const rawRoom = snapshot.val();
  assertHoldemRoom(rawRoom);
  const room = rawRoom as HoldemRoom;
  assertHoldemController(room, uid, request.data?.controllerSessionId);
  if (room.selectedGame !== "holdem") throw new HttpsError("failed-precondition", "홀덤 게임이 선택되지 않았습니다.");
  if (!restart && room.status !== "seating") throw new HttpsError("failed-precondition", "자리 배치를 시작한 뒤 게임을 시작해주세요.");
  const fingerprint = startGameFingerprint(room);
  const players = createPlayers(room.players);
  const initialGame = createHoldemGame(players, Date.now());
  try {
    const transaction = await runPrimedTransaction(roomRef, (value) => {
      assertHoldemRoom(value);
      const current = value as HoldemRoom;
      assertHoldemController(current, uid, request.data?.controllerSessionId);
      assertStartGameSnapshot(fingerprint, current);
      if (current.game?.public?.status === "playing" && !restart) return;
      current.game = initialGame;
      current.status = "playing";
      return current;
    });
    if (!transaction.committed) throw new HttpsError("already-exists", "이미 게임이 진행 중입니다.");
  } catch (error) {
    throw holdemHttpsError(error);
  }
  return {success: true, roomCode, handNumber: 1, revision: initialGame.public.revision, restarted: restart};
});

function createPlayers(values: HoldemRoom["players"]): HoldemStartPlayer[] {
  const players: HoldemStartPlayer[] = [];
  for (const [uid, value] of Object.entries(values ?? {})) {
    if (value.role !== "player" || value.status !== "active") continue;
    if (!Number.isInteger(value.seatIndex)) throw new HttpsError("failed-precondition", "모든 플레이어의 자리를 먼저 지정해주세요.");
    players.push({
      uid,
      nickname: typeof value.nickname === "string" ? value.nickname : "Player",
      characterId: typeof value.characterId === "string" ? value.characterId : "frog",
      seatIndex: value.seatIndex as number,
    });
  }
  return players;
}
