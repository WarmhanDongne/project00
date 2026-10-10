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

type CallLiarData = {
  roomCode?: unknown;
  commandId?: unknown;
  warmup?: unknown;
};

/** 현재 플레이어가 직전 제출에 대해 라이어를 선언합니다. */
export const game_liars_poker_call_liar = onCall<CallLiarData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    if (request.data?.warmup === true) {
      return {success: true, type: "warmup"};
    }
    const roomCode = parseRoomCode(request.data?.roomCode);
    const commandId = parseCommandId(request.data?.commandId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await runGameCommandTransaction(
      roomRef, request, "game_liars_poker_call_liar",
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
        if (
          game.public.phase !== "playing" &&
        game.public.phase !== "lastCardChallenge"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "현재 라이어를 선언할 수 있는 단계가 아닙니다.",
          );
        }
        const challenger = game.public.players[uid];
        assertPlayerExists(challenger);
        assertPlayerAlive(challenger.status);
        assertPlayerTurn(game.public.turnUid ?? "", uid);
        if (
          game.public.phase === "lastCardChallenge" &&
        (challenger.remainingCardCount <= 0 ||
          countPlayersWithCards(game.public.players) !== 1)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "잔여카드를 가진 마지막 플레이어만 이 선택을 할 수 있습니다.",
          );
        }

        const lastPlay = game.public.lastPlay;
        const actualCards = game.server.lastPlayCards;
        if (!lastPlay || !actualCards || actualCards.length === 0) {
          throw new HttpsError(
            "failed-precondition",
            "라이어를 선언할 직전 제출이 없습니다.",
          );
        }

        const truthful = actualCards.every(
          (card) => card.rank === game.public.table || card.rank === "JOKER",
        );
        const penaltyTargetUid = truthful ? uid : lastPlay.playerUid;
        // 잔여카드 보유자가 혼자인 마지막 카드 도전에서만 LIAR 실패 시
        // 이번 룰렛을 한 단계 올립니다. 생존자가 둘이라는 이유로 올리지 않습니다.
        const shouldIncreasePenaltyBeforeRoulette =
          game.public.phase === "lastCardChallenge" && truthful;
        const now = transactionNow;
        const actualRanks = actualCards.map((card) => card.rank);

        // 마지막 카드 도전에서 LIAR 판정에 실패하면 이번 룰렛부터 한 단계 높아진
        // 탈락 확률을 적용합니다. 생존 시 다음 벌칙 단계 상승은 별도로 적용합니다.
        if (shouldIncreasePenaltyBeforeRoulette) {
          challenger.penaltyCount += 1;
          game.server.penaltyCountIncrementedBeforeRoulette = true;
        } else {
          delete game.server.penaltyCountIncrementedBeforeRoulette;
        }

        game.public.phase = "penalty";
        game.public.turnUid = null;
        game.public.turnDeadlineAt = null;
        game.public.penaltyTargetUid = penaltyTargetUid;
        delete game.public.penaltyResult;
        const revealedLastPlay = {
          ...lastPlay,
          revealed: true,
          actualRanks,
        };
        game.public.lastPlay = revealedLastPlay;
        game.public.roundPlays ??= {};
        game.public.roundPlays[lastPlay.playId] = revealedLastPlay;
        game.public.revision += 1;
        game.public.updatedAt = now;

        response = {
          success: true,
          type: "liarCalled",
          commandId,
          truthful,
          challengerUid: uid,
          challengedUid: lastPlay.playerUid,
          penaltyTargetUid,
          actualRanks,
          revision: game.public.revision,
        };
        recordCommand(game, commandId, {
          uid,
          type: "liarCalled",
          createdAt: now,
          result: response,
        });
        return room;
      }, () => response);
    response = transaction.operationResult ?? response;

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "라이어 판정을 처리하지 못했습니다.");
    }
    return response;
  },
);
