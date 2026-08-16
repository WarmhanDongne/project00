import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {RealtimeRoom} from "./common/types.js";
import {
  assertController,
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type EndGameData = {
  roomCode?: unknown;
};

/** 방은 유지하고 현재 Liar's Poker 게임만 종료합니다. */
export const endLiarsPokerGame = onCall<EndGameData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid);
      const game = requireGame(room, {allowInterruption: true});

      if (game.public.status === "finished") {
        // 결과 화면에서 '나가기'를 누른 경우 휴대폰도 결과 다이얼로그를
        // 닫을 수 있도록 수동 종료 사유로 한 번 갱신합니다.
        if (game.public.finishReason !== "manual") {
          const now = Date.now();
          game.public.finishReason = "manual";
          game.public.winnerUid = null;
          game.public.revision += 1;
          game.public.updatedAt = now;
          game.private = {};
          delete game.server.pendingHands;
          delete game.server.interruption;
          delete game.public.interruption;
        }
        response = {
          success: true,
          type: "gameEnded",
          revision: game.public.revision,
        };
        return room;
      }

      const now = Date.now();
      game.public.status = "finished";
      game.public.finishReason = "manual";
      game.public.phase = "finished";
      game.public.turnUid = null;
      game.public.turnDeadlineAt = null;
      game.public.penaltyTargetUid = null;
      game.public.winnerUid = null;
      game.public.revision += 1;
      game.public.updatedAt = now;
      game.public.finishedAt = now;
      game.private = {};
      game.server.lastPlayCards = null;
      delete game.server.pendingHands;
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
