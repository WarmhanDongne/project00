/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {createInitialMafiaGame, createMafiaPlayers} from "./game.js";
import {MAFIA_MAX_PLAYERS, MAFIA_MIN_PLAYERS} from "./roles.js";
import {MafiaRoom} from "./types.js";
import {
  assertMafiaController,
  MAFIA_REGION,
  mafiaRoomCode,
  mafiaUid,
} from "./validation.js";

type StartData = {
  roomCode?: unknown;
  restart?: unknown;
  controllerSessionId?: unknown;
  /** 콜드스타트를 미리 없애기 위한 예열 호출입니다. */
  warmup?: unknown;
};

export const game_mafia_start_game = onCall<StartData>(
  {region: MAFIA_REGION},
  async (request) => {
    // 예열 호출은 아무것도 하지 않고 즉시 돌아갑니다. 첫 조작이 느려지지 않게
    // 게임 진입 시 미리 한 번 부릅니다.
    if (request.data?.warmup === true) return {success: true, warmup: true};

    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const restart = request.data?.restart === true;
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const room = (await roomRef.get()).val() as MafiaRoom | null;
    if (!room) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    assertMafiaController(room, uid, request.data?.controllerSessionId);
    if (room.selectedGame !== "mafia") {
      throw new HttpsError("failed-precondition", "마피아가 선택되지 않았습니다.");
    }
    if (!restart && room.status !== "seating") {
      throw new HttpsError(
        "failed-precondition",
        "자리 배치를 시작한 뒤 게임을 시작해주세요.",
      );
    }

    const players = await createMafiaPlayers(room.players);
    const count = Object.keys(players).length;
    if (count < MAFIA_MIN_PLAYERS || count > MAFIA_MAX_PLAYERS) {
      throw new HttpsError(
        "failed-precondition",
        `마피아는 ${MAFIA_MIN_PLAYERS}~${MAFIA_MAX_PLAYERS}명으로 진행합니다.`,
      );
    }

    // 역할 배분은 여기서 한 번만 합니다. 트랜잭션 콜백은 여러 번 실행될 수 있어
    // 안에서 배분하면 매번 다른 결과가 나옵니다.
    const game = createInitialMafiaGame(players, Date.now());
    const transaction = await roomRef.child("game").transaction((current) => {
      if (current?.public?.status === "playing" && !restart) return;
      return game;
    });
    if (!transaction.committed) {
      throw new HttpsError("already-exists", "이미 게임이 진행 중입니다.");
    }
    return {success: true, roomCode, playerCount: count};
  },
);
