import assert from "node:assert/strict";
import test from "node:test";

import {createDeck} from "../lib/liars-poker/common/deck.js";
import {dealCards} from "../lib/liars-poker/common/deal-card.js";
import {
  findNextAlivePlayer,
} from "../lib/liars-poker/common/next-turn.js";
import {finishGame} from "../lib/liars-poker/finish-game.js";
import {restartRound} from "../lib/liars-poker/restart-round.js";

function players(count) {
  return Object.fromEntries(
    Array.from({length: count}, (_, index) => {
      const uid = `uid${index + 1}`;
      return [uid, {
        uid,
        nickname: uid,
        seatIndex: index,
        status: "alive",
        penaltyCount: 0,
        remainingCardCount: 5,
      }];
    }),
  );
}

function gameState(count = 3) {
  return {
    public: {
      status: "playing",
      phase: "penalty",
      round: 1,
      revision: 1,
      table: "A",
      turnUid: null,
      turnDeadlineAt: null,
      lastPlay: null,
      penaltyTargetUid: "uid1",
      winnerUid: null,
      players: players(count),
      startedAt: 1,
      updatedAt: 1,
    },
    private: {},
    server: {
      lastPlayCards: null,
      processedCommands: {},
      roundStarterUid: "uid1",
    },
  };
}

test("2~6인 덱은 1인당 5장을 분배할 만큼 크고 카드 ID가 고유하다", () => {
  for (let count = 2; count <= 6; count += 1) {
    const deck = createDeck(count);
    assert.ok(deck.length >= count * 5);
    assert.equal(new Set(deck.map((card) => card.id)).size, deck.length);
  }
});

test("카드는 좌석의 모든 생존 플레이어에게 5장씩 분배된다", () => {
  const gamePlayers = players(3);
  const hands = dealCards(createDeck(3), gamePlayers, 5);
  assert.deepEqual(Object.keys(hands).sort(), ["uid1", "uid2", "uid3"]);
  for (const hand of Object.values(hands)) {
    assert.equal(Object.keys(hand).length, 5);
  }
});

test("다음 턴은 탈락자를 건너뛴다", () => {
  const gamePlayers = players(3);
  gamePlayers.uid2.status = "eliminated";
  assert.equal(findNextAlivePlayer(gamePlayers, "uid1"), "uid3");
});

test("새 라운드는 생존자에게만 손패를 재분배한다", () => {
  const game = gameState();
  game.public.players.uid2.status = "eliminated";
  restartRound(game, "uid3", 100);

  assert.equal(game.public.round, 2);
  assert.equal(game.public.phase, "playing");
  assert.equal(game.public.turnUid, "uid3");
  assert.equal(Object.keys(game.private.uid1.hand).length, 5);
  assert.equal(Object.keys(game.private.uid3.hand).length, 5);
  assert.equal(game.private.uid2, undefined);
});

test("게임 종료 시 승자와 종료 상태가 기록된다", () => {
  const game = gameState(2);
  finishGame(game, "uid2", 200);
  assert.equal(game.public.status, "finished");
  assert.equal(game.public.phase, "finished");
  assert.equal(game.public.winnerUid, "uid2");
  assert.equal(game.public.finishedAt, 200);
});
