/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {createDeck} from "./common/deck.js";
import {dealCards} from "./common/deal-card.js";
import {createTable} from "./common/table.js";
import {
  LiarsPokerGameState,
  PublicGamePlayer,
  RealtimeRoom,
} from "./common/types.js";
import {
  assertController,
  assertRoomExists,
  parseRoomCode,
  REGION,
  requireUid,
} from "./common/validator.js";
import {CARDS_PER_PLAYER} from "./restart-round.js";

type StartGameData = {
  roomCode?: unknown;
  restart?: unknown;
  controllerSessionId?: unknown;
};

/**
 * 아이패드 컨트롤러가 새로운 Liar's Poker 게임을 시작합니다.
 */
export const game_liars_poker_start_game =
  onCall<StartGameData>(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const restart = request.data?.restart === true;

      const roomCode = parseRoomCode(
        request.data?.roomCode,
      );

      const roomRef = getDatabase().ref(
        `rooms/${roomCode}`,
      );

      /*
       * 방 전체에 바로 트랜잭션을 걸면 첫 콜백에서
       * null이 전달될 수 있으므로 먼저 서버 데이터를 읽습니다.
       */
      const roomSnapshot = await roomRef.get();
      const rawRoom = roomSnapshot.val();

      assertRoomExists(rawRoom);

      const room = rawRoom as RealtimeRoom;

      // 방을 만든 아이패드인지 확인합니다.
      assertController(room, uid, request.data?.controllerSessionId);

      if (room.selectedGame !== "liars_poker") {
        throw new HttpsError(
          "failed-precondition",
          "Liar's Poker 게임이 선택되지 않았습니다.",
        );
      }

      const players = await createPublicPlayers(
        room.players,
      );

      const playerCount =
        Object.keys(players).length;

      if (playerCount < 2 || playerCount > 6) {
        throw new HttpsError(
          "failed-precondition",
          "플레이어는 2~6명이어야 합니다.",
        );
      }

      assertValidSeats(players);

      const now = Date.now();

      const deck = createDeck(playerCount);

      const hands = dealCards(
        deck,
        players,
        CARDS_PER_PLAYER,
      );

      const orderedPlayers =
        Object.values(players).sort(
          (left, right) =>
            left.seatIndex - right.seatIndex,
        );

      const firstPlayer =
        orderedPlayers[
          randomInt(orderedPlayers.length)
        ];

      const privateStates:
        LiarsPokerGameState["private"] = {};

      for (const player of orderedPlayers) {
        privateStates[player.uid] = {
          hand: hands[player.uid],
        };
      }

      const initialGame: LiarsPokerGameState = {
        public: {
          status: "playing",
          // 태블릿의 실제 배분 애니메이션이 끝날 때까지 플레이를 막습니다.
          phase: "dealing",
          round: 1,
          revision: 1,
          table: createTable(),
          turnUid: firstPlayer.uid,
          turnDeadlineAt: null,
          lastPlay: null,
          roundPlays: {},
          penaltyTargetUid: null,
          winnerUid: null,
          players,
          startedAt: now,
          updatedAt: now,
        },
        // 실제 손패는 태블릿 배분 연출이 끝난 뒤 private 경로로 이동합니다.
        private: {},
        server: {
          lastPlayCards: null,
          processedCommands: {},
          roundStarterUid: firstPlayer.uid,
          pendingHands: privateStates,
        },
      };

      /*
       * 방 전체가 아닌 game 노드에만 트랜잭션을 적용합니다.
       *
       * 트랜잭션 첫 실행에서 currentGame이 null이어도 정상입니다.
       * 서버에 기존 게임이 있다면 최신 값으로 다시 실행됩니다.
       */
      const gameRef = roomRef.child("game");

      const transaction =
        await gameRef.transaction(
          (currentGame) => {
            const existingGame =
              currentGame as
                Partial<LiarsPokerGameState> |
                null;

            if (
              existingGame?.public?.status ===
              "playing" &&
              !restart
            ) {
              // undefined를 반환하면 트랜잭션이 중단됩니다.
              return;
            }

            return initialGame;
          },
        );

      if (!transaction.committed) {
        throw new HttpsError(
          "already-exists",
          "이미 게임이 진행 중입니다.",
        );
      }

      return {
        success: true,
        roomCode,
        turnUid: firstPlayer.uid,
        revision: 1,
        restarted: restart,
      };
    },
  );

/**
 * 로비 참가자 데이터를 게임 공개 플레이어 데이터로 변환합니다.
 */
async function createPublicPlayers(
  roomPlayers: RealtimeRoom["players"],
): Promise<Record<string, PublicGamePlayer>> {
  if (!roomPlayers) {
    throw new HttpsError(
      "failed-precondition",
      "참가 플레이어가 없습니다.",
    );
  }

  const players:
    Record<string, PublicGamePlayer> = {};

  for (
    const [uid, value] of
    Object.entries(roomPlayers)
  ) {
    if (
      value.role !== "player" ||
      value.status !== "active"
    ) {
      continue;
    }

    const seatIndex = value.seatIndex;

    if (!Number.isInteger(seatIndex)) {
      throw new HttpsError(
        "failed-precondition",
        "모든 플레이어의 자리를 먼저 지정해주세요.",
      );
    }

    players[uid] = {
      uid,
      nickname:
        typeof value.nickname === "string" ?
          value.nickname :
          "Player",
      characterId: typeof value.characterId === "string" ?
        value.characterId : "frog",
      seatIndex: seatIndex as number,
      status: "alive",
      penaltyCount: 0,
      remainingCardCount: CARDS_PER_PLAYER,
    };
  }

  return players;
}

/**
 * 좌석이 0부터 플레이어 수까지 중복 없이 배정됐는지 확인합니다.
 */
function assertValidSeats(
  players: Record<string, PublicGamePlayer>,
): void {
  const seats = Object.values(players).map(
    (player) => player.seatIndex,
  );

  const valid =
    new Set(seats).size === seats.length &&
    seats.every(
      (seat) =>
        seat >= 0 &&
        seat < seats.length,
    );

  if (!valid) {
    throw new HttpsError(
      "failed-precondition",
      "플레이어 자리는 중복 없이 지정해야 합니다.",
    );
  }
}
