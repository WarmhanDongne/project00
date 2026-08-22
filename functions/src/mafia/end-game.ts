/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {beginGameInterruption} from "../game-interruption/state.js";
import {finishMafiaGame} from "./game.js";
import {MAFIA_MIN_PLAYERS} from "./roles.js";
import {MafiaRoom} from "./types.js";
import {
  assertMafiaController,
  MAFIA_REGION,
  mafiaRoomCode,
  mafiaUid,
  requireMafiaGame,
} from "./validation.js";

type EndData = {roomCode?: unknown; controllerSessionId?: unknown};

/** 방과 참가자는 유지하고 현재 마피아 게임만 수동 종료합니다. */
export const game_mafia_end_game = onCall<EndData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      assertMafiaController(room, uid, request.data?.controllerSessionId);
      const game = requireMafiaGame(room, {allowInterruption: true});
      const now = Date.now();

      // 수동 종료는 승자가 없습니다.
      finishMafiaGame(game, null, "manual", now);
      game.public.nightSubmittedCount = 0;
      game.public.nightActorCount = 0;
      delete game.public.nightActionCue;
      game.public.voteSubmittedCount = 0;
      game.public.voteEligibleCount = 0;
      delete game.public.morningResult;
      delete game.public.voteResult;
      delete game.server.nightActions;
      delete game.server.votes;
      delete game.server.interruption;
      delete game.public.interruption;

      response = {
        success: true,
        type: "gameEnded",
        revision: game.public.revision,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임을 종료하지 못했습니다.");
    }
    return response;
  },
);

type LeaveData = {roomCode?: unknown};

/**
 * 방에서는 즉시 나가되, 진행 가능한 게임은 남은 플레이어 투표 뒤 제외합니다.
 *
 * **사망자는 이미 게임 진행에 영향을 주지 않으므로 바로 내보냅니다.** 관전 중인
 * 사람이 나갔다고 남은 사람들에게 투표를 시키면 게임이 불필요하게 멈춥니다.
 */
export const game_mafia_leave_game = onCall<LeaveData>(
  {region: MAFIA_REGION},
  async (request) => {
    const uid = mafiaUid(request);
    const roomCode = mafiaRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      const roomPlayer = room.players?.[uid];
      if (!roomPlayer && !room.game?.public.players[uid]) {
        response = {success: true, alreadyLeft: true};
        return room;
      }
      if (!room.game || room.game.public.gameType !== "mafia") {
        delete room.players?.[uid];
        response = {success: true};
        return room;
      }

      const game = requireMafiaGame(room, {allowInterruption: true});
      const leaving = game.public.players[uid];
      // 사망자·관전자·이미 끝난 게임은 그대로 내보냅니다.
      if (!leaving || leaving.status !== "alive" ||
          game.public.status === "finished") {
        delete room.players?.[uid];
        response = {success: true};
        return room;
      }

      const now = Date.now();
      // 실제 제외가 확정되기 전에는 프로필과 seatIndex를 유지합니다.
      if (room.players?.[uid]) room.players[uid].isConnected = false;
      beginGameInterruption(room, uid, "left", now, {
        minimumPlayerCount: MAFIA_MIN_PLAYERS,
      });
      response = {
        success: true,
        status: game.public.status,
        interruptionId: game.public.interruption?.id ?? null,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임 퇴장을 처리하지 못했습니다.");
    }
    return response;
  },
);
