import assert from "node:assert/strict";
import test from "node:test";

import {
  removeFinalTurnPendingPlayer,
  resolveFinalCallRound,
} from "../lib/final-call/game.js";

function card(id, color, value) {
  return {id, color, value};
}

function finalCallGame({automaticCall = false} = {}) {
  const uid1Hand = {
    red10: card("red10", "red", 10),
    blue10: card("blue10", "blue", 10),
    green2: card("green2", "green", 2),
    yellow4: card("yellow4", "yellow", 4),
  };
  const uid2Hand = {
    red6: card("red6", "red", 6),
    red5: card("red5", "red", 5),
    blue3: card("blue3", "blue", 3),
    green1: card("green1", "green", 1),
  };
  return {
    public: {
      status: "playing",
      phase: automaticCall ? "playing" : "finalSubmit",
      round: 1,
      revision: 1,
      turnUid: "uid2",
      turnDeadlineAt: 100,
      callerUid: automaticCall ? null : "uid1",
      deckRemainingCount: 3,
      discardCard: card("discard", "yellow", 1),
      pendingDrawUid: null,
      pendingDrawSource: null,
      finalTurnPendingUids: automaticCall ? [] : ["uid2"],
      winnerUid: null,
      players: {
        uid1: {uid: "uid1", nickname: "A", seatIndex: 0, status: "alive", lives: 3},
        uid2: {uid: "uid2", nickname: "B", seatIndex: 1, status: "alive", lives: 3},
      },
      startedAt: 1,
      updatedAt: 1,
    },
    private: {
      uid1: {hand: uid1Hand},
      uid2: {hand: uid2Hand},
    },
    server: {
      deck: [],
      pendingHands: {},
      finalSubmissions: automaticCall ? {} : {
        uid1: [uid1Hand.red10, uid1Hand.blue10],
        uid2: [uid2Hand.red6, uid2Hand.red5],
      },
      roundStarterUid: "uid1",
      processedCommands: {},
    },
  };
}

test("Final Call 결과에는 각 플레이어가 제출한 카드만 공개된다", () => {
  const game = finalCallGame();

  resolveFinalCallRound(game, 200, false);

  assert.deepEqual(
    game.public.roundResult.revealedHands.uid1.map((value) => value.id),
    ["red10", "blue10"],
  );
  assert.deepEqual(
    game.public.roundResult.revealedHands.uid2.map((value) => value.id),
    ["red6", "red5"],
  );
  assert.equal(game.public.roundResult.revealedHands.uid1.length, 2);
  assert.equal(game.public.roundResult.revealedHands.uid2.length, 2);
});

test("덱 소진 자동 CALL도 전체 손패 대신 최고 조합만 공개한다", () => {
  const game = finalCallGame({automaticCall: true});

  resolveFinalCallRound(game, 200, true);

  assert.deepEqual(
    game.public.roundResult.revealedHands.uid1.map((value) => value.id),
    ["red10", "blue10"],
  );
  assert.deepEqual(
    game.public.roundResult.revealedHands.uid2.map((value) => value.id),
    ["red6", "red5"],
  );
});

test("RTDB에서 빈 최종 턴 목록이 생략되어도 플레이어 퇴장을 처리한다", () => {
  assert.deepEqual(removeFinalTurnPendingPlayer(undefined, "uid1"), []);
  assert.deepEqual(
    removeFinalTurnPendingPlayer(["uid1", "uid2"], "uid1"),
    ["uid2"],
  );
});
