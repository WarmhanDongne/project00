import {
  runGameCommandTransaction,
} from "../game-interruption/game-command-transaction.js";
import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {processedResult, recordCommand} from "./common/commands.js";
import {countPlayersWithCards} from "./common/next-turn.js";
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

type PassChallengeData = {roomCode?: unknown; commandId?: unknown};

/** 마지막 카드를 의심하지 않고(FOLD) 대신 자신이 벌칙 룰렛을 받습니다. */
export const game_liars_poker_pass_challenge = onCall<PassChallengeData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await runGameCommandTransaction(
      roomRef, request, "game_liars_poker_pass_challenge",
      (rawRoom, transactionNow) => {
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
        if (
          player.remainingCardCount <= 0 ||
        countPlayersWithCards(game.public.players) !== 1
        ) {
          throw new HttpsError(
            "failed-precondition",
            "잔여카드를 가진 마지막 플레이어만 FOLD를 선택할 수 있습니다.",
          );
        }

        const now = transactionNow;

        // FOLD는 상대의 마지막 카드를 인정하는 선택이므로 FOLD를 고른 현재
        // 플레이어가 벌칙 룰렛을 진행합니다.
        //
        // 이 단계는 전체 인원과 무관하게 잔여카드를 가진 생존자가 현재 플레이어
        // 한 명만 남았을 때 열립니다. 먼저 손패를 다 낸 플레이어는 빠집니다.
        game.public.phase = "penalty";
        game.public.turnUid = null;
        game.public.turnDeadlineAt = null;
        game.public.penaltyTargetUid = uid;
        delete game.public.penaltyResult;
        delete game.server.penaltyCountIncrementedBeforeRoulette;
        game.public.revision += 1;
        game.public.updatedAt = now;

        response = {
          success: true,
          type: "passPenalty",
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
      }, () => response);
    response = transaction.operationResult ?? response;

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "새 라운드를 시작하지 못했습니다.");
    }
    return response;
  },
);
