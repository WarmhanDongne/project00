import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {RealtimeRoom} from "./common/types.js";
import {
  assertController,
  assertGameStatus,
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";

type CompleteDealingData = {
  roomCode?: unknown;
};

/** 태블릿 카드 배분 연출이 끝난 뒤 휴대폰의 첫 턴을 엽니다. */
export const completeLiarsPokerDealing = onCall<CompleteDealingData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // 트랜잭션 로컬 캐시가 비어 있으면 서버 값과 동기화하도록 유지합니다.
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      assertController(room, uid);

      const game = requireGame(room);
      assertGameStatus(game.public.status, "playing");

      // 네트워크 재시도로 같은 완료 요청이 들어와도 성공으로 처리합니다.
      if (game.public.phase === "playing") {
        response = {
          success: true,
          type: "dealingAlreadyCompleted",
          revision: game.public.revision,
          turnUid: game.public.turnUid,
        };
        return room;
      }

      if (game.public.phase !== "dealing") {
        throw new HttpsError(
          "failed-precondition",
          "카드 배분을 완료할 수 있는 단계가 아닙니다.",
        );
      }

      const pendingHands = game.server.pendingHands;
      if (!pendingHands || Object.keys(pendingHands).length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "배분할 플레이어 손패가 없습니다.",
        );
      }

      const now = Date.now();
      // 손패 공개와 플레이 시작 상태를 같은 트랜잭션에서 반영합니다.
      game.private = pendingHands;
      delete game.server.pendingHands;
      game.public.phase = "playing";
      game.public.revision += 1;
      game.public.updatedAt = now;

      response = {
        success: true,
        type: "dealingCompleted",
        revision: game.public.revision,
        turnUid: game.public.turnUid,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "카드 배분을 완료하지 못했습니다.");
    }
    return response;
  },
);
