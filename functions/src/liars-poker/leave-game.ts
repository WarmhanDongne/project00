/* eslint-disable valid-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {findNextAlivePlayer} from "./common/next-turn.js";
import {RealtimeRoom, TURN_DURATION_MS} from "./common/types.js";
import {
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireGame,
  requireUid,
} from "./common/validator.js";
import {restartRound} from "./restart-round.js";

const MIN_PLAYERS = 2;

type LeaveGameData = {
  roomCode?: unknown;
};

/**
 * 휴대폰 플레이어를 방에서 퇴장시키고 진행 가능한 다음 게임 상태를 만듭니다.
 * 방 자체는 어떤 경우에도 삭제하지 않습니다.
 */
export const leaveLiarsPokerGame = onCall<LeaveGameData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((rawRoom) => {
      // RTDB 트랜잭션 첫 실행에서 로컬 캐시가 비어 있으면 null이 전달될 수 있습니다.
      if (rawRoom === null) return rawRoom;

      assertRoomExists(rawRoom);
      const room = rawRoom as RealtimeRoom;
      const game = requireGame(room);
      const roomPlayer = room.players?.[uid];
      const gamePlayer = game.public.players[uid];

      if (!roomPlayer && !gamePlayer) {
        response = {success: true, type: "alreadyLeft", gameEnded: false};
        return room;
      }

      if (room.players) delete room.players[uid];

      // 이미 끝난 게임에서는 방 참가 정보만 정리합니다.
      if (!gamePlayer || game.public.status === "finished") {
        response = {
          success: true,
          type: "playerLeft",
          gameEnded: game.public.status === "finished",
          remainingPlayerCount: Object.keys(room.players ?? {}).length,
        };
        return room;
      }

      const now = Date.now();
      gamePlayer.status = "eliminated";
      gamePlayer.remainingCardCount = 0;
      delete game.private[uid];
      if (game.server.pendingHands) {
        delete game.server.pendingHands[uid];
      }

      const alivePlayers = Object.values(game.public.players).filter(
        (player) => player.status === "alive",
      );

      if (alivePlayers.length < MIN_PLAYERS) {
        // 제출된 공개 카드 더미는 태블릿의 종료 연출을 위해 그대로 둡니다.
        game.public.status = "finished";
        game.public.finishReason = "insufficientPlayers";
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

        response = {
          success: true,
          type: "insufficientPlayers",
          gameEnded: true,
          remainingPlayerCount: alivePlayers.length,
          revision: game.public.revision,
        };
        return room;
      }

      const nextAliveUid = findNextAlivePlayer(game.public.players, uid);
      const penaltyTargetLeft =
        game.public.phase === "penalty" &&
        game.public.penaltyTargetUid === uid;
      const lastPlayOwnerLeft =
        game.public.phase === "lastCardChallenge" &&
        game.public.lastPlay?.playerUid === uid;

      if (penaltyTargetLeft || lastPlayOwnerLeft) {
        // 퇴장한 플레이어를 대상으로 벌칙/도전을 계속할 수 없으므로
        // 다음 생존자를 시작 플레이어로 새 라운드를 배분합니다.
        restartRound(game, nextAliveUid, now);
      } else {
        if (game.public.turnUid === uid) {
          game.public.turnUid = nextAliveUid;
          const timerHasStarted = game.public.isFirstTurnReady === true;
          game.public.turnDeadlineAt =
            game.public.phase === "dealing" || !timerHasStarted ?
              null : now + TURN_DURATION_MS;
        }
        if (game.server.roundStarterUid === uid) {
          game.server.roundStarterUid = nextAliveUid;
        }
        game.public.revision += 1;
        game.public.updatedAt = now;
      }

      response = {
        success: true,
        type: "playerLeft",
        gameEnded: false,
        remainingPlayerCount: alivePlayers.length,
        turnUid: game.public.turnUid,
        revision: game.public.revision,
      };
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임에서 퇴장하지 못했습니다.");
    }
    return response;
  },
);
