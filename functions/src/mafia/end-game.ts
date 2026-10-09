import {
  runGameCommandTransaction,
} from "../game-interruption/game-command-transaction.js";
/* eslint-disable max-len */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {leaveSessionRequest} from "../game-interruption/leave-request.js";
import {finishMafiaGame} from "./game.js";

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

    const transaction = await runGameCommandTransaction(roomRef, request, "game_mafia_end_game", (raw, transactionNow) => {
      if (raw === null) return raw;
      const room = raw as MafiaRoom;
      assertMafiaController(room, uid, request.data?.controllerSessionId);
      const game = requireMafiaGame(room, {allowInterruption: true});
      const now = transactionNow;

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
    }, () => response);
    response = transaction.operationResult ?? response;

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임을 종료하지 못했습니다.");
    }
    return response;
  },
);


export const game_mafia_leave_game = onCall({region: MAFIA_REGION}, leaveSessionRequest);
