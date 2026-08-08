import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {RealtimeRoom} from "./common/types.js";
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
import {restartRound} from "./restart-round.js";

type PassChallengeData = {roomCode?: unknown; commandId?: unknown};

/** 마지막 카드를 낸 플레이어를 의심하지 않고 새 라운드로 진행합니다. */
export const passLiarsPokerChallenge = onCall<PassChallengeData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // 원격 데이터가 있어도 트랜잭션 첫 호출에는 null이 올 수 있습니다.
      // null을 그대로 반환하면 서버 값과 동기화된 뒤 다시 호출됩니다.
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
      if (game.public.phase !== "lastCardChallenge") {
        throw new HttpsError(
          "failed-precondition",
          "마지막 제출에 대한 선택 단계가 아닙니다.",
        );
      }
      const player = game.public.players[uid];
      assertPlayerExists(player);
      assertPlayerAlive(player.status);
      assertPlayerTurn(game.public.turnUid ?? "", uid);

      const now = Date.now();
      restartRound(game, uid, now);
      response = {
        success: true,
        type: "challengePassed",
        commandId,
        round: game.public.round,
        turnUid: uid,
        revision: game.public.revision,
      };
      recordCommand(game, commandId, {
        uid,
        type: "challengePassed",
        createdAt: now,
        result: response,
      });
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "새 라운드를 시작하지 못했습니다.");
    }
    return response;
  },
);
