import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {RealtimeRoom, TURN_DURATION_MS} from "./common/types.js";
import {
  assertGameStatus,
  assertPlayerAlive,
  assertPlayerExists,
  assertPlayerTurn,
  assertRoomExists,
  parseCommandId,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type ReadyTurnData = {roomCode?: unknown; commandId?: unknown};

/** 사용자가 카드를 펼쳐 애니메이션을 끝냈을 때 최초 턴 타이머를 30초로 시작합니다. */
export const readyLiarsPokerTurn = onCall<ReadyTurnData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      const game = requireGame(room);
      const previousResult = processedResult(game, commandId);
      if (previousResult) {
        response = previousResult;
        return room;
      }

      assertGameStatus(game.public.status, "playing");
      if (game.public.phase !== "playing") {
        throw new HttpsError(
          "failed-precondition",
          "현재 게임 진행 단계가 아닙니다.",
        );
      }

      const player = game.public.players[uid];
      assertPlayerExists(player);
      assertPlayerAlive(player.status);
      assertPlayerTurn(game.public.turnUid ?? "", uid);

      // 이미 누군가 첫 턴 레디를 마쳤다면 더 이상 갱신하지 않습니다.
      if (game.public.isFirstTurnReady === true) {
        response = {success: true, ignored: true};
        return room;
      }

      const now = Date.now();
      game.public.isFirstTurnReady = true;
      game.public.turnDeadlineAt = now + TURN_DURATION_MS;
      game.public.revision += 1;
      game.public.updatedAt = now;

      response = {
        success: true,
        type: "turnReady",
        commandId,
        turnDeadlineAt: game.public.turnDeadlineAt,
        revision: game.public.revision,
      };

      recordCommand(game, commandId, {
        uid,
        type: "turnReady",
        createdAt: now,
        result: response,
      });

      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "턴을 시작하지 못했습니다.");
    }
    return response;
  },
);
